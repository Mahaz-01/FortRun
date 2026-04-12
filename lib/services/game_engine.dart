import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/zone_model.dart';
import '../utils/constants.dart';
import 'database_service.dart';

/// ============================================================
/// GameEngine — Core points / territory / sabotage / streak logic.
///
/// Rules:
///   +10 points per km running in YOUR territory (defend).
///   -5  points to territory OWNER when opponent runs in their zone.
///   -50 to -100 SABOTAGE deduction via restaurant check-in.
///   +25% of sabotage damage awarded to attacker as bonus.
///   Streak multiplier: 2-day = 1.5x, 7-day = 2x.
/// ============================================================

class GameEngine {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Process Run Points ────────────────────────────────────

  Future<Map<String, dynamic>> processRunPoints({
    required String runnerId,
    required String sector,
    required double distKm,
    required DatabaseService dbService,
  }) async {
    if (sector == 'Unknown' || distKm <= 0) {
      return {'pointsEarned': 0, 'streak': 0, 'multiplier': 1.0};
    }

    try {
      // Update streak first to get multiplier
      final streakResult = await dbService.updateStreak(runnerId);
      final double multiplier = (streakResult['multiplier'] as num?)?.toDouble() ?? 1.0;
      final int streak = (streakResult['streak'] as num?)?.toInt() ?? 0;

      // Fetch zone data
      final zoneRow = await _client
          .from('zones')
          .select()
          .eq('id', sector)
          .maybeSingle();

      int pointsEarned = 0;

      if (zoneRow == null) {
        // Zone unclaimed — create it and assign to runner
        pointsEarned = (distKm * AppConstants.pointsPerKmOwn * multiplier).round();

        await _client.from('zones').insert({
          'id': sector,
          'name': sector,
          'owner_id': runnerId,
          'owner_type': 'user',
          'control_percentage': 100.0,
          'total_points': pointsEarned,
        });

        await _client.from('zone_history').insert({
          'zone_id': sector,
          'user_id': runnerId,
          'points_delta': pointsEarned,
          'action': 'run_claim',
        });

        // Log activity
        await dbService.logActivity(
          actorId: runnerId,
          action: 'zone_captured',
          targetName: sector,
          detail: 'Claimed unclaimed territory',
        );
      } else {
        final zone = ZoneModel.fromMap(zoneRow);

        if (zone.ownerId == runnerId) {
          // Running in own fortress — defend bonus
          pointsEarned = (distKm * AppConstants.pointsPerKmOwn * multiplier).round();

          await _client.from('zones').update({
            'total_points': zone.totalPoints + pointsEarned,
          }).eq('id', sector);

          await _client.from('zone_history').insert({
            'zone_id': sector,
            'user_id': runnerId,
            'points_delta': pointsEarned,
            'action': 'run_defend',
          });
        } else {
          // Running in enemy territory — invade
          pointsEarned = (distKm * AppConstants.pointsPerKmOwn * multiplier).round();
          int ownerDeduction =
              (distKm * AppConstants.pointsDeductOpponent).round();

          if (zone.ownerId != null) {
            await _client.rpc('decrement_user_points', params: {
              'uid': zone.ownerId,
              'amount': ownerDeduction,
            });
          }

          await _client.from('zones').update({
            'total_points': zone.totalPoints + pointsEarned,
          }).eq('id', sector);

          await _client.from('zone_history').insert({
            'zone_id': sector,
            'user_id': runnerId,
            'points_delta': pointsEarned,
            'action': 'run_invade',
          });

          await _checkOwnershipChange(sector, dbService, runnerId);
        }
      }

      // Update runner's personal stats
      await _client.rpc('increment_user_stats', params: {
        'uid': runnerId,
        'pts': pointsEarned,
        'km': distKm,
      });

      // Log run activity
      await dbService.logActivity(
        actorId: runnerId,
        action: 'run_complete',
        targetName: sector,
        detail: '+$pointsEarned pts, ${distKm.toStringAsFixed(2)} km',
      );

      // Log streak milestone
      if (streak > 0 && streakResult['new_streak'] == true) {
        if (streak == 3 || streak == 7 || streak == 14 || streak == 30) {
          await dbService.logActivity(
            actorId: runnerId,
            action: 'streak',
            detail: '$streak-day streak!',
          );
        }
      }

      return {
        'pointsEarned': pointsEarned,
        'streak': streak,
        'multiplier': multiplier,
      };
    } catch (e) {
      return {'pointsEarned': 0, 'streak': 0, 'multiplier': 1.0};
    }
  }

  // ── Sabotage ──────────────────────────────────────────────

  Future<int> processSabotage({
    required String runnerId,
    required String sector,
    required String restaurantName,
    required DatabaseService dbService,
  }) async {
    try {
      final zoneRow = await _client
          .from('zones')
          .select()
          .eq('id', sector)
          .maybeSingle();

      if (zoneRow == null) return 0;

      final zone = ZoneModel.fromMap(zoneRow);

      if (zone.ownerId == null || zone.ownerId == runnerId) return 0;

      // Random sabotage damage between 50-100
      final random = Random();
      int sabotagePoints = AppConstants.sabotagePointsMin +
          random.nextInt(
              AppConstants.sabotagePointsMax - AppConstants.sabotagePointsMin + 1);

      // Deduct from zone owner's points
      await _client.rpc('decrement_user_points', params: {
        'uid': zone.ownerId,
        'amount': sabotagePoints,
      });

      // Update zone total points
      await _client.from('zones').update({
        'total_points': (zone.totalPoints - sabotagePoints).clamp(0, 999999999),
      }).eq('id', sector);

      // Blast all walls inside the sector
      await _client.rpc('sabotage_sector', params: {
        'target_sector': sector,
      });

      // Record sabotage in history
      await _client.from('zone_history').insert({
        'zone_id': sector,
        'user_id': runnerId,
        'points_delta': -sabotagePoints,
        'action': 'sabotage',
        'restaurant_name': restaurantName,
      });

      // Award 25% bonus to the saboteur
      int saboteurBonus = (sabotagePoints * 0.25).round();
      await _client.rpc('increment_user_stats', params: {
        'uid': runnerId,
        'pts': saboteurBonus,
        'km': 0.0,
      });

      // Re-check ownership
      await _checkOwnershipChange(sector, dbService, runnerId);

      // Log activity
      await dbService.logActivity(
        actorId: runnerId,
        action: 'sabotage',
        targetName: sector,
        detail: '-$sabotagePoints pts at $restaurantName',
      );

      return sabotagePoints;
    } catch (e) {
      return 0;
    }
  }

  // ── Ownership Recalculation ───────────────────────────────

  Future<void> _checkOwnershipChange(
    String sector,
    DatabaseService dbService,
    String runnerId,
  ) async {
    try {
      final runsResponse = await _client
          .from('runs')
          .select('user_id, distance_km')
          .eq('primary_sector', sector);

      final rows = runsResponse as List;
      if (rows.isEmpty) return;

      Map<String, double> contributions = {};
      for (var row in rows) {
        final uid = row['user_id'] as String;
        final dist = ((row['distance_km'] ?? 0) as num).toDouble();
        contributions[uid] = (contributions[uid] ?? 0.0) + dist;
      }

      if (contributions.isEmpty) return;

      final topEntry = contributions.entries
          .reduce((a, b) => a.value >= b.value ? a : b);

      final totalKm = contributions.values.fold(0.0, (sum, v) => sum + v);
      final controlPct = (topEntry.value / totalKm) * 100;

      // Check if ownership changed
      final currentZone = await _client
          .from('zones')
          .select('owner_id')
          .eq('id', sector)
          .maybeSingle();

      final previousOwner = currentZone?['owner_id'];

      await _client.from('zones').update({
        'owner_id': topEntry.key,
        'owner_type': 'user',
        'control_percentage': controlPct,
      }).eq('id', sector);

      await _client.from('users').update({
        'current_fortress_sector': sector,
      }).eq('id', topEntry.key);

      // Log ownership change
      if (previousOwner != topEntry.key) {
        await dbService.logActivity(
          actorId: topEntry.key,
          action: 'zone_captured',
          targetName: sector,
          detail: 'Took control with ${controlPct.toStringAsFixed(0)}%',
        );
      }
    } catch (e) {
      // Non-critical
    }
  }
}
