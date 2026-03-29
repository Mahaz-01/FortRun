import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/zone_model.dart';
import '../services/database_service.dart';

/// ============================================================
/// LocationService — GPS tracking, polyline recording,
/// and zone detection via point-in-polygon algorithm.
/// ============================================================

class LocationService extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────
  Position? _currentPosition;
  bool _isTracking = false;
  final List<LatLng> _routePoints = [];
  double _totalDistanceKm = 0.0;
  int _elapsedSeconds = 0;
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  List<ZoneModel> _activeZones = [];

  // ── Public Getters ────────────────────────────────────────
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  double get totalDistanceKm => _totalDistanceKm;
  int get elapsedSeconds => _elapsedSeconds;

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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  // ── Sync Active Zones ─────────────────────────────────────
  
  void updateActiveZones(List<ZoneModel> zones) {
    _activeZones = zones;
    notifyListeners();
  }

  // ── Get Current Position ──────────────────────────────────

  Future<Position?> getCurrentPosition() async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return null;

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    notifyListeners();
    return _currentPosition;
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

    // Start stopwatch timer & wall tick processor (every 5 seconds)
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      
      // Ping database every 5 seconds to process wall damage/building!
      if (_elapsedSeconds % 5 == 0 && _currentPosition != null) {
        String? activeSector = detectZone(_currentPosition!.latitude, _currentPosition!.longitude);
        if (activeSector != null) {
          String wallId = getWallId(_currentPosition!.latitude, _currentPosition!.longitude);
          Map<String, dynamic> poly = getWallPolygonJson(_currentPosition!.latitude, _currentPosition!.longitude);
          
          dbService.processWallTick(
            wallId: wallId,
            sectorId: activeSector,
            userId: uid,
            clanId: cid,
            polygonJson: poly,
            tickAmount: 5, // 5 seconds of active effort
          );
        }
      }

      notifyListeners();
    });

    // Subscribe to position stream
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _currentPosition = position;
      LatLng newPoint = LatLng(position.latitude, position.longitude);

      if (_routePoints.isNotEmpty) {
        LatLng lastPoint = _routePoints.last;
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

    // Determine primary sector of the run
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

  /// Determines which Islamabad sector a single point is in based on dynamic DB boundaries.
  /// Returns null if outside all known zones.
  String? detectZone(double lat, double lng) {
    if (_activeZones.isEmpty) return null;

    for (var zone in _activeZones) {
      if (zone.polygonCoords.isEmpty) continue;
      
      List<LatLng> polygon = zone.polygonCoords
          .map((e) => LatLng(e['lat']!, e['lng']!))
          .toList();

      if (_isPointInPolygon(LatLng(lat, lng), polygon)) {
        return zone.id;
      }
    }
    return null;
  }

  // ── Mathematical Grid Micro-Tiles (200m x 200m) ─────────────
  
  // 0.0018 degrees is roughly 200 meters.
  // We floor the coordinates to step them into a massive mathematical grid covering the planet.
  
  /// Gets the unique wall hash string based on mathematical coordinates.
  String getWallId(double lat, double lng) {
    double gridSize = 0.0018;
    int latIndex = (lat / gridSize).floor();
    int lngIndex = (lng / gridSize).floor();
    return 'grid_${latIndex}_$lngIndex';
  }

  /// Calculates the 4 exact DB-storable points of the mathematical box based on user coords.
  Map<String, dynamic> getWallPolygonJson(double lat, double lng) {
    double gridSize = 0.0018;
    double baseLat = (lat / gridSize).floor() * gridSize;
    double baseLng = (lng / gridSize).floor() * gridSize;

    return {
      "points": [
        {"lat": baseLat + gridSize, "lng": baseLng},            // NW
        {"lat": baseLat + gridSize, "lng": baseLng + gridSize}, // NE
        {"lat": baseLat, "lng": baseLng + gridSize},            // SE
        {"lat": baseLat, "lng": baseLng}                        // SW
      ]
    };
  }

  /// Determines the primary sector of the entire run
  /// by counting which zone has the most route points.
  String detectPrimarySector() {
    Map<String, int> zoneCounts = {};
    for (var point in _routePoints) {
      String? zone = detectZone(point.latitude, point.longitude);
      if (zone != null) {
        zoneCounts[zone] = (zoneCounts[zone] ?? 0) + 1;
      }
    }
    if (zoneCounts.isEmpty) return 'Unknown';

    return zoneCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// Returns the sector the user is currently standing in.
  String? get currentZone {
    if (_currentPosition == null) return null;
    return detectZone(_currentPosition!.latitude, _currentPosition!.longitude);
  }

  // ── Point-in-Polygon (Ray Casting Algorithm) ──────────────

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
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

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth radius in km
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  // ── Cleanup ───────────────────────────────────────────────

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
