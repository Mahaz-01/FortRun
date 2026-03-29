/// ============================================================
/// WallModel — Micro-Level Tile System for Hybrid Territories
///
/// Table: `walls`
/// Each wall is a 200m x 200m mathematical grid tile inside a sector.
/// ============================================================

class WallModel {
  final String id;
  final String sectorId;
  final String? ownerId;
  final String? clanId;
  final int strength;
  final List<Map<String, double>> polygonCoords;

  const WallModel({
    required this.id,
    required this.sectorId,
    this.ownerId,
    this.clanId,
    this.strength = 0,
    required this.polygonCoords,
  });

  /// Deserialize from Supabase Realtime row.
  factory WallModel.fromMap(Map<String, dynamic> data) {
    List<Map<String, double>> poly = [];
    if (data['polygon_coords'] != null) {
      final raw = data['polygon_coords'] as List<dynamic>;
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

    return WallModel(
      id: data['id'] as String,
      sectorId: (data['sector_id'] as String?) ?? '',
      ownerId: data['owner_id'] as String?,
      clanId: data['clan_id'] as String?,
      strength: (data['strength'] ?? 0) as int,
      polygonCoords: poly,
    );
  }
}
