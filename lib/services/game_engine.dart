import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';

/// ============================================================
/// GameEngine — thin client over server-authoritative scoring.
///
/// All points / territory / sabotage / streak math now runs in
/// Postgres via SECURITY DEFINER RPCs keyed off auth.uid()
/// (see security_hardening.sql). The client can no longer
/// fabricate scores, claim zones, or drain rivals directly.
/// ============================================================

class GameEngine {
  final SupabaseClient _client = Supabase.instance.client;

  /// Score a completed run. The run row must already be inserted
  /// (DatabaseService.saveRun) — pass its id. The server derives
  /// points/streak/ownership and returns the summary.
  Future<Map<String, dynamic>> processRun({
    required String runId,
    required DatabaseService dbService,
  }) async {
    try {
      final result = await _client.rpc('process_run', params: {
        'p_run_id': runId,
      });
      if (result is Map) {
        final m = Map<String, dynamic>.from(result);
        return {
          'pointsEarned': (m['pointsEarned'] as num?)?.toInt() ?? 0,
          'streak': (m['streak'] as num?)?.toInt() ?? 0,
          'multiplier': (m['multiplier'] as num?)?.toDouble() ?? 1.0,
        };
      }
    } catch (_) {}
    return {'pointsEarned': 0, 'streak': 0, 'multiplier': 1.0};
  }

  /// Sabotage an enemy sector via a restaurant check-in.
  ///
  /// [runnerId] is accepted for call-site compatibility but ignored —
  /// the server uses auth.uid() as the actor. Returns damage dealt
  /// (0 if on cooldown or the target is invalid).
  Future<int> processSabotage({
    required String runnerId,
    required String sector,
    required String restaurantName,
    required DatabaseService dbService,
  }) async {
    try {
      final result = await _client.rpc('process_sabotage', params: {
        'target_sector': sector,
        'restaurant_name': restaurantName,
      });
      if (result is Map && result['damage'] != null) {
        return (result['damage'] as num).toInt();
      }
      if (result is num) return result.toInt();
    } catch (_) {}
    return 0;
  }
}
