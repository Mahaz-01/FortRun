import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import '../models/zone_model.dart';
import '../models/clan_model.dart';
import '../models/wall_model.dart';

/// ============================================================
/// DatabaseService — All Supabase PostgreSQL CRUD operations.
///
/// Uses PostgREST (Supabase's auto-generated REST API) for
/// standard queries, and Supabase Realtime for live streaming.
///
/// Production notes:
///   • All tables have Row-Level Security (RLS) enabled.
///   • Indexes are defined in the SQL schema for query performance.
///   • Realtime is enabled per-table in Supabase Dashboard.
/// ============================================================

class DatabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Users ─────────────────────────────────────────────────

  Future<void> createUser(UserModel user) async {
    await _client.from('users').insert(user.toInsertMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (response == null) return null;
    return UserModel.fromMap(response);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _client.from('users').update(data).eq('id', uid);
  }

  /// Stream a single user's data via Supabase Realtime.
  /// Returns a broadcast stream that emits on every change.
  Stream<UserModel?> streamUser(String uid) {
    // Use Supabase Realtime channel for postgres_changes
    final controller = StreamController<UserModel?>.broadcast();

    // Initial fetch
    getUser(uid).then((user) {
      if (!controller.isClosed) controller.add(user);
    });

    // Listen for realtime changes
    final channel = _client
        .channel('user_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: uid,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              controller.add(UserModel.fromMap(payload.newRecord));
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
    };

    return controller.stream;
  }

  // ── Runs ──────────────────────────────────────────────────

  Future<String> saveRun(RunModel run) async {
    final response = await _client
        .from('runs')
        .insert(run.toInsertMap())
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<List<RunModel>> getUserRuns(String uid, {int limit = 50}) async {
    final response = await _client
        .from('runs')
        .select()
        .eq('user_id', uid)
        .order('timestamp', ascending: false)
        .limit(limit);

    return (response as List)
        .map((row) => RunModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ── Zones ─────────────────────────────────────────────────

  Future<ZoneModel?> getZone(String sectorId) async {
    final response = await _client
        .from('zones')
        .select()
        .eq('id', sectorId)
        .maybeSingle();

    if (response == null) return null;
    return ZoneModel.fromMap(response);
  }

  /// Stream all zones via Supabase Realtime.
  Stream<List<ZoneModel>> streamAllZones() {
    final controller = StreamController<List<ZoneModel>>.broadcast();

    // Initial fetch
    _fetchAllZones().then((zones) {
      if (!controller.isClosed) controller.add(zones);
    });

    // Listen for realtime changes to the zones table
    final channel = _client
        .channel('zones_all')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'zones',
          callback: (payload) {
            // Re-fetch all zones on any change for consistency
            _fetchAllZones().then((zones) {
              if (!controller.isClosed) controller.add(zones);
            });
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<List<ZoneModel>> _fetchAllZones() async {
    final response = await _client.from('zones').select();
    return (response as List)
        .map((row) => ZoneModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertZone(ZoneModel zone) async {
    await _client.from('zones').upsert(zone.toMap());
  }

  Future<void> updateZone(String sectorId, Map<String, dynamic> data) async {
    await _client.from('zones').update(data).eq('id', sectorId);
  }

  // ── Zone History (relational replacement for Firestore array) ──

  Future<void> addZoneHistory(ZoneHistoryEntry entry) async {
    await _client.from('zone_history').insert(entry.toInsertMap());
  }

  Future<List<ZoneHistoryEntry>> getZoneHistory(String sectorId,
      {int limit = 50}) async {
    final response = await _client
        .from('zone_history')
        .select()
        .eq('zone_id', sectorId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((row) => ZoneHistoryEntry.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ── Clans ─────────────────────────────────────────────────

  Future<String> createClan(ClanModel clan) async {
    final response = await _client
        .from('clans')
        .insert(clan.toInsertMap())
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<ClanModel?> getClan(String clanId) async {
    final response = await _client
        .from('clans')
        .select()
        .eq('id', clanId)
        .maybeSingle();

    if (response == null) return null;
    return ClanModel.fromMap(response);
  }

  /// Join clan: update user's clan_id (relational, no array manipulation).
  Future<void> joinClan(String clanId, String userId) async {
    await _client
        .from('users')
        .update({'clan_id': clanId})
        .eq('id', userId);
  }

  /// Leave clan: set user's clan_id to null.
  Future<void> leaveClan(String userId) async {
    await _client
        .from('users')
        .update({'clan_id': null})
        .eq('id', userId);
  }

  /// Get clan members via relational query (no array needed).
  Future<List<UserModel>> getClanMembers(String clanId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('clan_id', clanId)
        .order('points', ascending: false);

    return (response as List)
        .map((row) => UserModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<ClanModel>> getAllClans() async {
    final response = await _client
        .from('clans')
        .select()
        .order('total_points', ascending: false);

    return (response as List)
        .map((row) => ClanModel.fromMap(row as Map<String, dynamic>))
        .toList();
  // ── Walls (Micro-Level Hybrid) ────────────────────────────

  /// Stream all active walls dynamically.
  Stream<List<WallModel>> streamAllWalls() {
    final controller = StreamController<List<WallModel>>.broadcast();

    _fetchAllWalls().then((walls) {
      if (!controller.isClosed) controller.add(walls);
    });

    final channel = _client
        .channel('walls_all')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'walls',
          callback: (payload) {
            _fetchAllWalls().then((walls) {
              if (!controller.isClosed) controller.add(walls);
            });
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<List<WallModel>> _fetchAllWalls() async {
    final response = await _client.from('walls').select();
    return (response as List)
        .map((row) => WallModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Fire the backend DB logic to handle 1 accumulated point of time over a wall tile.
  Future<void> processWallTick({
    required String wallId,
    required String sectorId,
    required String userId,
    String? clanId,
    required Map<String, dynamic> polygonJson,
    required int tickAmount,
  }) async {
    await _client.rpc('process_wall_tick', params: {
      'target_wall_id': wallId,
      'target_sector_id': sectorId,
      'uid': userId,
      'cid': clanId,
      'poly': polygonJson,
      'tick_amount': tickAmount,
    });
  }

  /// Sabotage specific sector, dealing AoE damage to all walls.
  Future<void> sabotageSector(String sectorId) async {
    await _client.rpc('sabotage_sector', params: {
      'target_sector': sectorId,
    });
  }
}
