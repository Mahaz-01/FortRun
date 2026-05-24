import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../models/zone_model.dart';
import '../services/database_service.dart';

/// ============================================================
/// LocationService — GPS tracking, polyline recording,
/// zone detection (ray-cast), wall tick processing.
/// Uses latlong2.LatLng (no Google Maps dependency).
/// ============================================================

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isTracking = false;
  final List<ll.LatLng> _routePoints = [];
  double _totalDistanceKm = 0.0;
  int _elapsedSeconds = 0;
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  List<ZoneModel> _activeZones = [];
  String? _permissionError;

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  List<ll.LatLng> get routePoints => List.unmodifiable(_routePoints);
  double get totalDistanceKm => _totalDistanceKm;
  int get elapsedSeconds => _elapsedSeconds;
  String? get permissionError => _permissionError;

  String get formattedPace {
    if (_totalDistanceKm <= 0) return '--:--';
    double minutesPerKm = (_elapsedSeconds / 60) / _totalDistanceKm;
    int mins = minutesPerKm.floor();
    int secs = ((minutesPerKm - mins) * 60).round();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String get formattedTime {
    int hrs = _elapsedSeconds ~/ 3600;
    int mins = (_elapsedSeconds % 3600) ~/ 60;
    int secs = _elapsedSeconds % 60;
    if (hrs > 0) {
      return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // ── Permissions ───────────────────────────────────────────

  Future<bool> requestPermission() async {
    _permissionError = null;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _permissionError = 'Location services are disabled. Please enable GPS.';
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _permissionError = 'Location permission denied. FortRun needs GPS to track runs.';
        notifyListeners();
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _permissionError = 'Location permission permanently denied. Please enable in Settings.';
      notifyListeners();
      return false;
    }
    return true;
  }

  void updateActiveZones(List<ZoneModel> zones) {
    _activeZones = zones;
    notifyListeners();
  }

  Future<Position?> getCurrentPosition() async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return null;

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      _permissionError = 'Failed to get location: $e';
      notifyListeners();
      return null;
    }
  }

  // ── Start/Stop Run Tracking ───────────────────────────────

  Future<void> startTracking({
    required DatabaseService dbService,
    required String uid,
    String? cid,
  }) async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return;

    _isTracking = true;
    _routePoints.clear();
    _totalDistanceKm = 0.0;
    _elapsedSeconds = 0;
    notifyListeners();

    // Wall tick every 5 seconds — works anywhere, no pre-drawn zones needed
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;

      if (_elapsedSeconds % 5 == 0 && _currentPosition != null) {
        final lat = _currentPosition!.latitude;
        final lng = _currentPosition!.longitude;
        final wallId = getWallId(lat, lng);
        final sectorId = getGridSector(lat, lng);
        final poly = getWallPolygon(lat, lng);

        dbService.processWallTick(
          wallId: wallId,
          sectorId: sectorId,
          userId: uid,
          clanId: cid,
          polygonCoords: poly,
          tickAmount: 5,
        );
      }

      notifyListeners();
    });

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _currentPosition = position;
      ll.LatLng newPoint = ll.LatLng(position.latitude, position.longitude);

      if (_routePoints.isNotEmpty) {
        ll.LatLng lastPoint = _routePoints.last;
        double dist = _calculateDistance(
          lastPoint.latitude, lastPoint.longitude,
          newPoint.latitude, newPoint.longitude,
        );
        _totalDistanceKm += dist;
      }

      _routePoints.add(newPoint);
      notifyListeners();
    });
  }

  Future<Map<String, dynamic>> stopTracking() async {
    _isTracking = false;
    _timer?.cancel();
    _timer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    notifyListeners();

    String primarySector = detectPrimarySector();

    return {
      'distanceKm': _totalDistanceKm,
      'durationSeconds': _elapsedSeconds,
      'primarySector': primarySector,
      'polylineCoords': _routePoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
    };
  }

  // ── Zone Detection ────────────────────────────────────────

  String? detectZone(double lat, double lng) {
    if (_activeZones.isEmpty) return null;
    for (var zone in _activeZones) {
      if (zone.polygonCoords.isEmpty) continue;
      List<ll.LatLng> polygon = zone.polygonCoords
          .map((e) => ll.LatLng(e['lat']!, e['lng']!))
          .toList();
      if (_isPointInPolygon(ll.LatLng(lat, lng), polygon)) {
        return zone.id;
      }
    }
    return null;
  }

  // ── Wall Grid (200m × 200m tiles) ─────────────────────────

  String getWallId(double lat, double lng) {
    const double gridSize = 0.0018;
    int latIndex = (lat / gridSize).floor();
    int lngIndex = (lng / gridSize).floor();
    return 'grid_${latIndex}_$lngIndex';
  }

  /// Returns polygon as a List (matches DB JSONB array format).
  List<Map<String, dynamic>> getWallPolygon(double lat, double lng) {
    const double gridSize = 0.0018;
    double baseLat = (lat / gridSize).floor() * gridSize;
    double baseLng = (lng / gridSize).floor() * gridSize;

    return [
      {'lat': baseLat + gridSize, 'lng': baseLng},
      {'lat': baseLat + gridSize, 'lng': baseLng + gridSize},
      {'lat': baseLat, 'lng': baseLng + gridSize},
      {'lat': baseLat, 'lng': baseLng},
    ];
  }

  // Returns a human-readable grid sector name for any GPS coordinate
  String getGridSector(double lat, double lng) {
    const double sectorSize = 0.009; // ~1 km grid sector
    int latIndex = (lat / sectorSize).floor();
    int lngIndex = (lng / sectorSize).floor();
    return 'sector_${latIndex}_$lngIndex';
  }

  String detectPrimarySector() {
    if (_routePoints.isEmpty) return 'Unknown';
    // Count grid sectors across all route points and return the most visited
    Map<String, int> sectorCounts = {};
    for (var point in _routePoints) {
      final s = getGridSector(point.latitude, point.longitude);
      sectorCounts[s] = (sectorCounts[s] ?? 0) + 1;
    }
    return sectorCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  String? get currentZone {
    if (_currentPosition == null) return null;
    // Try pre-drawn zones first for named display, fall back to grid sector
    final named = detectZone(_currentPosition!.latitude, _currentPosition!.longitude);
    return named ?? getGridSector(_currentPosition!.latitude, _currentPosition!.longitude);
  }

  // ── Distance Utilities ────────────────────────────────────

  double distanceToPointMeters(double lat1, double lng1, double lat2, double lng2) {
    return _calculateDistance(lat1, lng1, lat2, lng2) * 1000;
  }

  // ── Ray Casting Point-in-Polygon ──────────────────────────

  bool _isPointInPolygon(ll.LatLng point, List<ll.LatLng> polygon) {
    int n = polygon.length;
    bool inside = false;
    double px = point.latitude;
    double py = point.longitude;

    for (int i = 0, j = n - 1; i < n; j = i++) {
      double xi = polygon[i].latitude;
      double yi = polygon[i].longitude;
      double xj = polygon[j].latitude;
      double yj = polygon[j].longitude;

      bool intersect = ((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  // ── Haversine Distance (km) ───────────────────────────────

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
