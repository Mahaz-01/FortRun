import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import '../models/zone_model.dart';
import '../models/clan_model.dart';
import '../models/wall_model.dart';

/// ============================================================
/// DatabaseService — All Supabase PostgreSQL CRUD operations.
/// ============================================================

class DatabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Users ─────────────────────────────────────────────────

  Future<void> createUser(UserModel user) async {
    try {
      await _client.from('users').insert(user.toInsertMap());
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _client.from('users').update(data).eq('id', uid);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Stream<UserModel?> streamUser(String uid) {
    final controller = StreamController<UserModel?>.broadcast();

    getUser(uid).then((user) {
      if (!controller.isClosed) controller.add(user);
    });

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
    try {
      final response = await _client
          .from('runs')
          .insert(run.toInsertMap())
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      throw Exception('Failed to save run: $e');
    }
  }

  Future<List<RunModel>> getUserRuns(String uid, {int limit = 50}) async {
    try {
      final response = await _client
          .from('runs')
          .select()
          .eq('user_id', uid)
          .order('timestamp', ascending: false)
          .limit(limit);

      return (response as List)
          .map((row) => RunModel.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<RunModel>> getAllRecentRuns({int limit = 200}) async {
    try {
      final response = await _client
          .from('runs')
          .select()
          .order('timestamp', ascending: false)
          .limit(limit);
      return (response as List)
          .map((row) => RunModel.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Global recent-runs feed. Seeds once, then appends each new run from
  /// the realtime payload — instead of re-downloading the whole table (with
  /// full GPS polylines) on every insert. This is the key scalability fix:
  /// traffic no longer grows with (active users × dataset size) per event.
  Stream<List<RunModel>> streamAllRecentRuns({int limit = 200}) {
    final controller = StreamController<List<RunModel>>.broadcast();
    final List<RunModel> cache = [];

    void emit() {
      if (!controller.isClosed) controller.add(List.unmodifiable(cache));
    }

    getAllRecentRuns(limit: limit).then((runs) {
      cache
        ..clear()
        ..addAll(runs);
      emit();
    });

    final channel = _client
        .channel('all_runs_global')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'runs',
          callback: (payload) {
            try {
              cache.insert(0, RunModel.fromMap(payload.newRecord));
              if (cache.length > limit) {
                cache.removeRange(limit, cache.length);
              }
              emit();
            } catch (_) {
              // Fallback to a full refetch only if the delta can't be parsed.
              getAllRecentRuns(limit: limit).then((runs) {
                cache
                  ..clear()
                  ..addAll(runs);
                emit();
              });
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
    };

    return controller.stream;
  }

  Stream<List<RunModel>> streamUserRuns(String uid, {int limit = 50}) {
    final controller = StreamController<List<RunModel>>.broadcast();

    getUserRuns(uid, limit: limit).then((runs) {
      if (!controller.isClosed) controller.add(runs);
    });

    final channel = _client
        .channel('runs_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'runs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            getUserRuns(uid, limit: limit).then((runs) {
              if (!controller.isClosed) controller.add(runs);
            });
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
    };

    return controller.stream;
  }

  // ── Zones ─────────────────────────────────────────────────

  Future<ZoneModel?> getZone(String sectorId) async {
    try {
      final response = await _client
          .from('zones')
          .select()
          .eq('id', sectorId)
          .maybeSingle();

      if (response == null) return null;
      return ZoneModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Live zones. Seeds once into a keyed cache, then applies each
  /// insert/update/delete from the realtime payload instead of re-pulling
  /// every zone on every change.
  Stream<List<ZoneModel>> streamAllZones() {
    final controller = StreamController<List<ZoneModel>>.broadcast();
    final Map<String, ZoneModel> cache = {};

    void emit() {
      if (!controller.isClosed) controller.add(cache.values.toList());
    }

    _fetchAllZones().then((zones) {
      for (final z in zones) {
        cache[z.id] = z;
      }
      emit();
    });

    final channel = _client
        .channel('zones_all')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'zones',
          callback: (payload) {
            try {
              if (payload.eventType == PostgresChangeEvent.delete) {
                final id = payload.oldRecord['id'];
                if (id != null) cache.remove(id.toString());
              } else if (payload.newRecord.isNotEmpty) {
                final z = ZoneModel.fromMap(payload.newRecord);
                cache[z.id] = z;
              }
              emit();
            } catch (_) {
              _fetchAllZones().then((zones) {
                cache.clear();
                for (final z in zones) {
                  cache[z.id] = z;
                }
                emit();
              });
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<List<ZoneModel>> _fetchAllZones() async {
    try {
      final response = await _client.from('zones').select();
      return (response as List)
          .map((row) => ZoneModel.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> upsertZone(ZoneModel zone) async {
    try {
      await _client.from('zones').upsert(zone.toMap());
    } catch (e) {
      throw Exception('Failed to upsert zone: $e');
    }
  }

  Future<void> updateZone(String sectorId, Map<String, dynamic> data) async {
    try {
      await _client.from('zones').update(data).eq('id', sectorId);
    } catch (e) {
      throw Exception('Failed to update zone: $e');
    }
  }

  // ── Zone History ──────────────────────────────────────────

  Future<void> addZoneHistory(ZoneHistoryEntry entry) async {
    try {
      await _client.from('zone_history').insert(entry.toInsertMap());
    } catch (e) {
      // Non-critical, don't throw
    }
  }

  Future<List<ZoneHistoryEntry>> getZoneHistory(String sectorId,
      {int limit = 50}) async {
    try {
      final response = await _client
          .from('zone_history')
          .select()
          .eq('zone_id', sectorId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((row) => ZoneHistoryEntry.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── Clans ─────────────────────────────────────────────────

  Future<String> createClan(ClanModel clan) async {
    try {
      final response = await _client
          .from('clans')
          .insert(clan.toInsertMap())
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      throw Exception('Failed to create clan: $e');
    }
  }

  Future<ClanModel?> getClan(String clanId) async {
    try {
      final response = await _client
          .from('clans')
          .select()
          .eq('id', clanId)
          .maybeSingle();

      if (response == null) return null;
      return ClanModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> joinClan(String clanId, String userId) async {
    try {
      await _client
          .from('users')
          .update({'clan_id': clanId})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to join clan: $e');
    }
  }

  Future<void> leaveClan(String userId) async {
    try {
      await _client
          .from('users')
          .update({'clan_id': null})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to leave clan: $e');
    }
  }

  Future<List<UserModel>> getClanMembers(String clanId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('clan_id', clanId)
          .order('points', ascending: false);

      return (response as List)
          .map((row) => UserModel.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ClanModel>> getAllClans() async {
    try {
      final response = await _client
          .from('clans')
          .select()
          .order('total_points', ascending: false);

      return (response as List)
          .map((row) => ClanModel.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<int> getClanMemberCount(String clanId) async {
    try {
      final response = await _client
          .from('users')
          .select('id')
          .eq('clan_id', clanId);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // ── Walls (Micro-Level Hybrid) ────────────────────────────

  /// Live walls. Same keyed-cache delta strategy as zones — critical because
  /// walls update every few seconds per active runner.
  Stream<List<WallModel>> streamAllWalls() {
    final controller = StreamController<List<WallModel>>.broadcast();
    final Map<String, WallModel> cache = {};

    void emit() {
      if (!controller.isClosed) controller.add(cache.values.toList());
    }

    _fetchAllWalls().then((walls) {
      for (final w in walls) {
        cache[w.id] = w;
      }
      emit();
    });

    final channel = _client
        .channel('walls_all')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'walls',
          callback: (payload) {
            try {
              if (payload.eventType == PostgresChangeEvent.delete) {
                final id = payload.oldRecord['id'];
                if (id != null) cache.remove(id.toString());
              } else if (payload.newRecord.isNotEmpty) {
                final w = WallModel.fromMap(payload.newRecord);
                cache[w.id] = w;
              }
              emit();
            } catch (_) {
              _fetchAllWalls().then((walls) {
                cache.clear();
                for (final w in walls) {
                  cache[w.id] = w;
                }
                emit();
              });
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<List<WallModel>> _fetchAllWalls() async {
    try {
      final response = await _client.from('walls').select();
      return (response as List)
          .map((row) => WallModel.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Wall tick. The server derives the actor from auth.uid() and looks up
  /// the user's clan itself — the client no longer passes (and cannot spoof)
  /// the owner or clan.
  Future<void> processWallTick({
    required String wallId,
    required String sectorId,
    required List<Map<String, dynamic>> polygonCoords,
    required int tickAmount,
  }) async {
    try {
      await _client.rpc('process_wall_tick', params: {
        'target_wall_id': wallId,
        'target_sector_id': sectorId,
        'poly': polygonCoords,
        'tick_amount': tickAmount,
      });
    } catch (_) {
      // Non-critical tick, don't crash the run
    }
  }

  Future<void> sabotageSector(String sectorId) async {
    try {
      await _client.rpc('sabotage_sector', params: {
        'target_sector': sectorId,
      });
    } catch (e) {
      throw Exception('Sabotage failed: $e');
    }
  }

  // Streaks are now handled entirely server-side inside the process_run RPC
  // (see security_hardening.sql). The client never advances streaks directly.

  // ── Activity Feed ─────────────────────────────────────────

  Future<void> logActivity({
    required String actorId,
    required String action,
    String? targetName,
    String? detail,
  }) async {
    try {
      await _client.rpc('log_activity', params: {
        'p_actor_id': actorId,
        'p_action': action,
        'p_target_name': targetName,
        'p_detail': detail,
      });
    } catch (e) {
      // Non-critical
    }
  }

  Stream<List<Map<String, dynamic>>> streamActivityFeed({int limit = 50}) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final List<Map<String, dynamic>> cache = [];

    void seed(List<Map<String, dynamic>> items) {
      cache
        ..clear()
        ..addAll(items);
      if (!controller.isClosed) controller.add(List.unmodifiable(cache));
    }

    _fetchActivityFeed(limit: limit).then(seed);

    final channel = _client
        .channel('activity_feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activity_feed',
          callback: (payload) {
            try {
              if (payload.newRecord.isNotEmpty) {
                cache.insert(0, Map<String, dynamic>.from(payload.newRecord));
                if (cache.length > limit) {
                  cache.removeRange(limit, cache.length);
                }
                if (!controller.isClosed) {
                  controller.add(List.unmodifiable(cache));
                }
              }
            } catch (_) {
              _fetchActivityFeed(limit: limit).then(seed);
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<List<Map<String, dynamic>>> _fetchActivityFeed({int limit = 50}) async {
    try {
      final response = await _client
          .from('activity_feed')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // ── Sabotage Cooldown ─────────────────────────────────────

  Future<bool> checkSabotageCooldown(String uid, String sectorId) async {
    try {
      final result = await _client.rpc('check_sabotage_cooldown', params: {
        'uid': uid,
        'target_sector': sectorId,
      });
      return result as bool;
    } catch (e) {
      return true; // Allow sabotage if check fails
    }
  }

  // ── Leaderboard (with owner names) ────────────────────────

  Future<List<Map<String, dynamic>>> getTopRunners({int limit = 20}) async {
    try {
      final response = await _client
          .from('users')
          .select('id, name, points, total_km, photo_url, streak_count')
          .order('points', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopZones({int limit = 15}) async {
    try {
      final response = await _client
          .from('zones_with_owner')
          .select('id, name, owner_id, owner_name, owner_type, total_points, control_percentage')
          .order('total_points', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Fallback to raw zones table if view doesn't exist
      try {
        final fallback = await _client
            .from('zones')
            .select('id, name, owner_id, total_points, control_percentage')
            .order('total_points', ascending: false)
            .limit(limit);
        return List<Map<String, dynamic>>.from(fallback);
      } catch (_) {
        return [];
      }
    }
  }
}
