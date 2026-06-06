/// ============================================================
/// ZoneModel — Supabase PostgreSQL serialization
///
/// Table: `zones`
/// Primary key: `id` (TEXT, e.g. "F-7" — user-defined sector names)
/// History is stored in a separate `zone_history` table for
/// proper relational design and scalability.
/// ============================================================

import 'dart:convert';

class ZoneModel {
  final String id;
  final String name;
  final String? ownerId;
  final String? ownerType;
  final double controlPercentage;
  final int totalPoints;
  final List<Map<String, double>> polygonCoords;

  const ZoneModel({
    required this.id,
    required this.name,
    this.ownerId,
    this.ownerType,
    this.controlPercentage = 0.0,
    this.totalPoints = 0,
    this.polygonCoords = const [],
  });

  /// Deserialize from Supabase row.
  factory ZoneModel.fromMap(Map<String, dynamic> data) {
    List<Map<String, double>> poly = [];
    if (data['polygon_coords'] != null) {
      final field = data['polygon_coords'];
      final raw = (field is String ? json.decode(field) : field) as List<dynamic>;
      poly = raw.map((e) {
        if (e is Map) {
          return {
            'lat': ((e['lat'] ?? 0) as num).toDouble(),
            'lng': ((e['lng'] ?? 0) as num).toDouble(),
          };
        }
        return {'lat': 0.0, 'lng': 0.0};
      }).toList();
    }

    return ZoneModel(
      id: data['id'] as String,
      name: (data['name'] as String?) ?? '',
      ownerId: data['owner_id'] as String?,
      ownerType: data['owner_type'] as String?,
      controlPercentage: ((data['control_percentage'] ?? 0) as num).toDouble(),
      totalPoints: (data['total_points'] ?? 0) as int,
      polygonCoords: poly,
    );
  }

  /// Serialize for UPSERT (insert or update).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'owner_type': ownerType,
      'control_percentage': controlPercentage,
      'total_points': totalPoints,
      'polygon_coords': polygonCoords,
    };
  }
}

/// ============================================================
/// ZoneHistoryEntry — Separate table for scalable audit trail.
///
/// Table: `zone_history`
/// Records every run_claim, run_defend, run_invade, and sabotage
/// action with immutable timestamps. This is the relational
/// replacement for the Firestore `history` array.
/// ============================================================

class ZoneHistoryEntry {
  final String? id;
  final String zoneId;
  final String userId;
  final int pointsDelta;
  final String action; // 'run_claim', 'run_defend', 'run_invade', 'sabotage'
  final String? restaurantName;
  final DateTime createdAt;

  const ZoneHistoryEntry({
    this.id,
    required this.zoneId,
    required this.userId,
    required this.pointsDelta,
    required this.action,
    this.restaurantName,
    required this.createdAt,
  });

  factory ZoneHistoryEntry.fromMap(Map<String, dynamic> data) {
    return ZoneHistoryEntry(
      id: data['id'] as String?,
      zoneId: data['zone_id'] as String,
      userId: data['user_id'] as String,
      pointsDelta: data['points_delta'] as int,
      action: data['action'] as String,
      restaurantName: data['restaurant_name'] as String?,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'zone_id': zoneId,
      'user_id': userId,
      'points_delta': pointsDelta,
      'action': action,
      'restaurant_name': restaurantName,
    };
  }
}
