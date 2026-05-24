import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// ============================================================
/// RestaurantService — Fetches real restaurants from
/// OpenStreetMap Overpass API (free, no API key needed).
/// Caches results for 24 hours in SharedPreferences.
/// Falls back to hardcoded list on error.
/// ============================================================

class RestaurantService {
  static const String _cacheKey = 'osm_restaurants_cache';
  static const String _cacheTimeKey = 'osm_restaurants_cache_time';
  static const Duration _cacheDuration = Duration(hours: 24);

  /// Fetch restaurants near [lat]/[lng] within [radiusMeters].
  /// Queries all amenity types: restaurant, cafe, fast_food, food_court.
  Future<List<SabotageSpot>> getNearbyRestaurants({
    required double lat,
    required double lng,
    double radiusMeters = 1500,
    required String currentSector,
  }) async {
    try {
      final cached = await _loadCache(lat, lng);
      if (cached != null) return cached;

      final spots = await _fetchFromOverpass(lat, lng, radiusMeters, currentSector);
      if (spots.isNotEmpty) {
        await _saveCache(lat, lng, spots);
        return spots;
      }
    } catch (_) {}

    // Fall back to hardcoded spots filtered by sector
    return AppConstants.fallbackSabotageSpots
        .where((s) => s.sector == currentSector)
        .toList();
  }

  Future<List<SabotageSpot>> _fetchFromOverpass(
    double lat,
    double lng,
    double radiusMeters,
    String sector,
  ) async {
    final query = '''
[out:json][timeout:15];
(
  node["amenity"~"restaurant|cafe|fast_food|food_court"]["name"](around:$radiusMeters,$lat,$lng);
);
out body 40;
''';

    final uri = Uri.parse('https://overpass-api.de/api/interpreter');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'data=${Uri.encodeComponent(query)}',
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) return [];

    final data = json.decode(response.body) as Map<String, dynamic>;
    final elements = (data['elements'] as List?) ?? [];

    return elements
        .where((e) =>
            e['type'] == 'node' &&
            e['lat'] != null &&
            e['lon'] != null &&
            e['tags']?['name'] != null)
        .map((e) {
          final tags = e['tags'] as Map<String, dynamic>;
          final amenity = (tags['amenity'] as String?) ?? 'restaurant';
          final cuisine = tags['cuisine'] as String?;
          return SabotageSpot(
            name: tags['name'] as String,
            sector: sector,
            lat: (e['lat'] as num).toDouble(),
            lng: (e['lon'] as num).toDouble(),
            cuisine: cuisine ?? amenity,
            isDynamic: true,
          );
        })
        .take(30)
        .toList();
  }

  // ── Cache helpers ─────────────────────────────────────────

  String _cacheId(double lat, double lng) =>
      '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';

  Future<List<SabotageSpot>?> _loadCache(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final id = _cacheId(lat, lng);
    final timeKey = '${_cacheTimeKey}_$id';
    final dataKey = '${_cacheKey}_$id';

    final savedTime = prefs.getInt(timeKey);
    if (savedTime == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - savedTime;
    if (age > _cacheDuration.inMilliseconds) return null;

    final raw = prefs.getString(dataKey);
    if (raw == null) return null;

    try {
      final list = json.decode(raw) as List;
      return list.map((item) => SabotageSpot(
        name: item['name'] as String,
        sector: item['sector'] as String,
        lat: (item['lat'] as num).toDouble(),
        lng: (item['lng'] as num).toDouble(),
        cuisine: item['cuisine'] as String?,
        isDynamic: true,
      )).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(
      double lat, double lng, List<SabotageSpot> spots) async {
    final prefs = await SharedPreferences.getInstance();
    final id = _cacheId(lat, lng);
    final timeKey = '${_cacheTimeKey}_$id';
    final dataKey = '${_cacheKey}_$id';

    await prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(
      dataKey,
      json.encode(spots
          .map((s) => {
                'name': s.name,
                'sector': s.sector,
                'lat': s.lat,
                'lng': s.lng,
                'cuisine': s.cuisine,
              })
          .toList()),
    );
  }
}
