/// ============================================================
/// ClanModel — Supabase PostgreSQL serialization
///
/// Table: `clans`
/// Primary key: `id` (UUID, auto-generated)
/// Members are NOT stored as an array — they are resolved via
/// a relational join: SELECT * FROM users WHERE clan_id = ?
/// This is the proper PostgreSQL/scalable pattern.
/// ============================================================

class ClanModel {
  final String? id;
  final String name;
  final int totalPoints;
  final DateTime createdAt;

  const ClanModel({
    this.id,
    required this.name,
    this.totalPoints = 0,
    required this.createdAt,
  });

  /// Deserialize from Supabase row.
  factory ClanModel.fromMap(Map<String, dynamic> data) {
    return ClanModel(
      id: data['id'] as String?,
      name: (data['name'] as String?) ?? '',
      totalPoints: (data['total_points'] ?? 0) as int,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// Serialize for INSERT. id and created_at are auto-generated.
  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'total_points': totalPoints,
    };
  }
}
