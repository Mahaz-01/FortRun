import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/zone_model.dart';
import '../utils/constants.dart';

/// ============================================================
/// GameEngine — Core points / territory / sabotage logic.
///
/// Rules:
///   +10 points per km running in YOUR territory (defend).
///   -5  points to territory OWNER when opponent runs in their zone (invade).
///   -50 to -100 SABOTAGE deduction via restaurant check-in.
///   +25% of sabotage damage awarded to attacker as bonus.
///
/// Supabase implementation notes:
///   • All writes use individual PostgREST calls. For true atomicity
///     at scale, wrap multi-step operations in PostgreSQL RPC functions.
///   • Zone ownership is recalculated based on aggregate km per user
///     in a zone, making it resistant to single-run manipulation.
/// ============================================================

class GameEngine {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Process Run Points ────────────────────────────────────

  /// Called when a run is completed.
  /// [runnerId] – the user who just ran.
  /// [sector]   – primary sector detected for the run.
  /// [distKm]   – total distance in km.
  ///
  /// Returns total points earned by the runner for this run.
  Future<int> processRunPoints({
    required String runnerId,
    required String sector,
    required double distKm,
  }) async {
    if (sector == 'Unknown' || distKm <= 0) return 0;

    // Fetch zone data
    final zoneRow = await _client
        .from('zones')
        .select()
        .eq('id', sector)
        .maybeSingle();

    int pointsEarned = 0;

    if (zoneRow == null) {
      // ── Zone unclaimed — create it and assign to runner ──
      pointsEarned = (distKm * AppConstants.pointsPerKmOwn).round();

      await _client.from('zones').insert({
        'id': sector,
        'name': sector,
        'owner_id': runnerId,
        'owner_type': 'user',
        'control_percentage': 100.0,
        'total_points': pointsEarned,
      });

      // Record history
      await _client.from('zone_history').insert({
        'zone_id': sector,
        'user_id': runnerId,
        'points_delta': pointsEarned,
        'action': 'run_claim',
      });
    } else {
      final zone = ZoneModel.fromMap(zoneRow);

      if (zone.ownerId == runnerId) {
        // ── Running in own fortress → defend bonus ──
        pointsEarned = (distKm * AppConstants.pointsPerKmOwn).round();

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
        // ── Running in enemy territory → invade ──
        pointsEarned = (distKm * AppConstants.pointsPerKmOwn).round();
        int ownerDeduction =
            (distKm * AppConstants.pointsDeductOpponent).round();

        // Deduct from current zone owner
        if (zone.ownerId != null) {
          await _client.rpc('decrement_user_points', params: {
            'uid': zone.ownerId,
            'amount': ownerDeduction,
          });
        }

        // Update zone total
        await _client.from('zones').update({
          'total_points': zone.totalPoints + pointsEarned,
        }).eq('id', sector);

        await _client.from('zone_history').insert({
          'zone_id': sector,
          'user_id': runnerId,
          'points_delta': pointsEarned,
          'action': 'run_invade',
        });

        // Re-evaluate zone ownership
        await _checkOwnershipChange(sector);
      }
    }

    // Update runner's personal stats
    await _client.rpc('increment_user_stats', params: {
      'uid': runnerId,
      'pts': pointsEarned,
      'km': distKm,
    });

    return pointsEarned;
  }

  // ── Sabotage ──────────────────────────────────────────────

  /// Process a sabotage: runner eats at a restaurant in an enemy sector,
  /// deducting 50–100 points from the zone owner.
  Future<int> processSabotage({
    required String runnerId,
    required String sector,
    required String restaurantName,
  }) async {
    final zoneRow = await _client
        .from('zones')
        .select()
        .eq('id', sector)
        .maybeSingle();

    if (zoneRow == null) return 0;

    final zone = ZoneModel.fromMap(zoneRow);

    // Can't sabotage your own territory
    if (zone.ownerId == null || zone.ownerId == runnerId) return 0;

    // Random sabotage damage between 50–100
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

    // Blast all 200m walls inside the sector!
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
    await _checkOwnershipChange(sector);

    return sabotagePoints;
  }

  // ── Ownership Recalculation ───────────────────────────────

  /// Determine who should own a zone based on aggregated run distance.
  /// The user with the most total km in the zone becomes the owner.
  Future<void> _checkOwnershipChange(String sector) async {
    // Aggregate distance per user in this sector
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

    // Find top contributor
    final topEntry = contributions.entries
        .reduce((a, b) => a.value >= b.value ? a : b);

    final totalKm = contributions.values.fold(0.0, (sum, v) => sum + v);
    final controlPct = (topEntry.value / totalKm) * 100;

    // Update zone ownership
    await _client.from('zones').update({
      'owner_id': topEntry.key,
      'owner_type': 'user',
      'control_percentage': controlPct,
    }).eq('id', sector);

    // Update user's fortress designation
    await _client.from('users').update({
      'current_fortress_sector': sector,
    }).eq('id', topEntry.key);
  }

  // ── Leaderboard Queries ───────────────────────────────────

  Future<List<Map<String, dynamic>>> getTopRunners({int limit = 20}) async {
    final response = await _client
        .from('users')
        .select('id, name, points, total_km, photo_url')
        .order('points', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getTopZones({int limit = 15}) async {
    final response = await _client
        .from('zones')
        .select('id, name, owner_id, total_points, control_percentage')
        .order('total_points', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }
}
