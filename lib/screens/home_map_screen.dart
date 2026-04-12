import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/game_engine.dart';
import '../services/database_service.dart';
import '../models/run_model.dart';
import '../models/zone_model.dart';
import '../models/wall_model.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import 'sabotage_screen.dart';
import 'run_summary_screen.dart';
import 'activity_feed_screen.dart';

/// ============================================================
/// HomeMapScreen — Interactive Google Map with territory polygons,
/// run tracking HUD, sabotage trigger, and activity feed access.
/// ============================================================

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Polygon> _polygons = {};
  final Set<Polyline> _polylines = {};
  List<ZoneModel> _zones = [];
  StreamSubscription? _zoneSubscription;

  List<WallModel> _walls = [];
  StreamSubscription? _wallSubscription;

  static const String _darkMapStyle = '''
  [
    {"elementType":"geometry","stylers":[{"color":"#212121"}]},
    {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
    {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
    {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#181818"}]},
    {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
    {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
    {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _initLocation();
    _listenToZones();
  }

  void _initLocation() async {
    final locService = context.read<LocationService>();
    await locService.getCurrentPosition();
    if (locService.permissionError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locService.permissionError!),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'RETRY',
            textColor: FortRunTheme.primaryGreen,
            onPressed: _initLocation,
          ),
        ),
      );
    }
  }

  void _listenToZones() {
    final dbService = context.read<DatabaseService>();
    final locService = context.read<LocationService>();
    _zoneSubscription = dbService.streamAllZones().listen((zones) {
      locService.updateActiveZones(zones);
      if (mounted) {
        setState(() {
          _zones = zones;
          _buildPolygons();
        });
      }
    });

    _wallSubscription = dbService.streamAllWalls().listen((walls) {
      if (mounted) {
        setState(() {
          _walls = walls;
          _buildPolygons();
        });
      }
    });
  }

  void _buildPolygons() {
    _polygons.clear();
    final authService = context.read<AuthService>();
    final currentUid = authService.currentUser?.id;

    // 1. Draw Macro Sectors
    for (var zone in _zones) {
      String sectorId = zone.id;
      if (zone.polygonCoords.isEmpty) continue;

      List<LatLng> points = zone.polygonCoords
          .map((e) => LatLng(e['lat']!, e['lng']!))
          .toList();

      Color fillColor;
      Color strokeColor;

      if (zone.ownerId == null) {
        fillColor = Colors.cyanAccent.withAlpha(8);
        strokeColor = Colors.white.withAlpha(89);
      } else if (zone.ownerId == currentUid) {
        fillColor = FortRunTheme.primaryGreen.withAlpha(38);
        strokeColor = FortRunTheme.primaryGreen.withAlpha(153);
      } else {
        fillColor = FortRunTheme.enemyRed.withAlpha(30);
        strokeColor = FortRunTheme.enemyRed.withAlpha(153);
      }

      _polygons.add(Polygon(
        polygonId: PolygonId(sectorId),
        points: points,
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidth: 2,
        consumeTapEvents: true,
        onTap: () => _showZoneInfo(sectorId, zone),
      ));
    }

    // 2. Draw Micro Walls
    for (var wall in _walls) {
      if (wall.polygonCoords.isEmpty || wall.strength <= 0) continue;

      List<LatLng> points = wall.polygonCoords
          .map((e) => LatLng(e['lat']!, e['lng']!))
          .toList();

      Color fillColor;
      Color strokeColor;
      int alpha = ((wall.strength / 100) * 204).clamp(25, 204).round();

      if (wall.ownerId == currentUid) {
        fillColor = FortRunTheme.primaryGreen.withAlpha(alpha);
        strokeColor = FortRunTheme.primaryGreen;
      } else {
        fillColor = FortRunTheme.enemyRed.withAlpha(alpha);
        strokeColor = FortRunTheme.enemyRed;
      }

      _polygons.add(Polygon(
        polygonId: PolygonId(wall.id),
        points: points,
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidth: 1,
        consumeTapEvents: true,
        onTap: () => _showWallInfo(wall),
      ));
    }
  }

  void _showWallInfo(WallModel wall) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FortRunTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Active Grid Wall',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _zoneInfoRow(
                  Icons.health_and_safety, 'Wall Strength', '${wall.strength}%'),
              _zoneInfoRow(
                  Icons.person, 'Owner ID', wall.ownerId ?? 'Unknown'),
              _zoneInfoRow(Icons.map, 'Inside Sector', wall.sectorId),
            ],
          ),
        );
      },
    );
  }

  void _showZoneInfo(String sectorId, ZoneModel? zone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FortRunTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final ownerName = zone?.ownerId ?? 'Unclaimed';
        final pct = zone?.controlPercentage.toStringAsFixed(1) ?? '0.0';
        final pts = zone?.totalPoints ?? 0;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FortRunTheme.primaryGreen.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.flag,
                        color: FortRunTheme.primaryGreen),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Sector $sectorId',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _zoneInfoRow(Icons.person, 'Owner', ownerName),
              _zoneInfoRow(Icons.pie_chart, 'Control', '$pct%'),
              _zoneInfoRow(Icons.star, 'Total Points', pts.toString()),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _zoneInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: FortRunTheme.textMuted),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: FortRunTheme.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _startRun() async {
    final locService = context.read<LocationService>();
    final dbService = context.read<DatabaseService>();
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.id;

    if (uid != null) {
      final userProfile = await dbService.getUser(uid);
      final cid = userProfile?.clanId;

      await locService.startTracking(
        dbService: dbService,
        uid: uid,
        cid: cid,
      );

      if (locService.permissionError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(locService.permissionError!)),
        );
      }
    }
  }

  Future<void> _stopRun() async {
    final locService = context.read<LocationService>();
    final authService = context.read<AuthService>();
    final gameEngine = context.read<GameEngine>();
    final dbService = context.read<DatabaseService>();
    final uid = authService.currentUser?.id;
    if (uid == null) return;

    final routeSnapshot = List<LatLng>.from(locService.routePoints);
    final result = await locService.stopTracking();

    // Save run to Supabase
    final run = RunModel(
      id: '',
      userId: uid,
      timestamp: DateTime.now(),
      distanceKm: result['distanceKm'],
      durationSeconds: result['durationSeconds'],
      primarySector: result['primarySector'],
      pointsEarned: 0,
      polylineCoords: List<Map<String, double>>.from(
        (result['polylineCoords'] as List)
            .map((e) => Map<String, double>.from(e)),
      ),
    );

    try {
      await dbService.saveRun(run);
    } catch (_) {}

    // Process points with streak
    final gameResult = await gameEngine.processRunPoints(
      runnerId: uid,
      sector: result['primarySector'],
      distKm: result['distanceKm'],
      dbService: dbService,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RunSummaryScreen(
            distanceKm: result['distanceKm'],
            durationSeconds: result['durationSeconds'],
            sector: result['primarySector'],
            pointsEarned: gameResult['pointsEarned'] ?? 0,
            streak: gameResult['streak'] ?? 0,
            multiplier: (gameResult['multiplier'] as num?)?.toDouble() ?? 1.0,
            routePoints: routeSnapshot,
          ),
        ),
      );
    }
  }

  // ── Sabotage ──────────────────────────────────────────────

  void _triggerSabotage() {
    final locService = context.read<LocationService>();
    final currentZone = locService.currentZone;
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.id;

    if (currentZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You are not inside any recognized territory!')),
      );
      return;
    }

    ZoneModel? zone;
    try {
      zone = _zones.firstWhere((z) => z.id == currentZone);
    } catch (_) {}

    if (zone == null || zone.ownerId == null || zone.ownerId == uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You can only sabotage enemy territories!')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SabotageScreen(sector: currentZone),
      ),
    );
  }

  void _locateMe() async {
    final locService = context.read<LocationService>();
    final pos = await locService.getCurrentPosition();
    if (pos != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pos.latitude, pos.longitude),
          15.5,
        ),
      );
    }
  }

  @override
  void dispose() {
    _zoneSubscription?.cancel();
    _wallSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locService = context.watch<LocationService>();
    final pos = locService.currentPosition;

    if (locService.isTracking && locService.routePoints.isNotEmpty) {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId('active_run'),
        points: locService.routePoints,
        color: FortRunTheme.primaryGreen,
        width: 5,
      ));
    } else {
      _polylines.clear();
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ─────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: pos != null
                  ? LatLng(pos.latitude, pos.longitude)
                  : AppConstants.islamabadCenter,
              zoom: AppConstants.defaultZoom,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              controller.setMapStyle(_darkMapStyle);
            },
            polygons: _polygons,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Top Bar ──────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: FortRunTheme.cardDark.withAlpha(234),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: FortRunTheme.primaryGreen.withAlpha(77),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on,
                      color: FortRunTheme.primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locService.currentZone != null
                          ? 'You are in Sector ${locService.currentZone}'
                          : 'Run in any Islamabad sector to start claiming your fortress!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (locService.isTracking) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: FortRunTheme.enemyRed.withAlpha(51),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: FortRunTheme.enemyRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text('LIVE',
                              style: TextStyle(
                                  color: FortRunTheme.enemyRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Activity feed bell
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ActivityFeedScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: FortRunTheme.primaryGreen.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            color: FortRunTheme.primaryGreen, size: 20),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Locate Me FAB ──────────────────────────────
          Positioned(
            right: 16,
            bottom: locService.isTracking ? 200 : 100,
            child: FloatingActionButton.small(
              heroTag: 'locate_me',
              onPressed: _locateMe,
              backgroundColor: FortRunTheme.cardDark,
              child: const Icon(Icons.my_location,
                  color: FortRunTheme.primaryGreen, size: 20),
            ),
          ),

          // ── Run Tracking HUD ──────────────────────────
          if (locService.isTracking)
            Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: FortRunTheme.cardGradient,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: FortRunTheme.primaryGreen.withAlpha(77),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(102),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statColumn(
                      locService.totalDistanceKm.toStringAsFixed(2),
                      'KM',
                      Icons.straighten,
                    ),
                    Container(width: 1, height: 40, color: Colors.white12),
                    _statColumn(
                      locService.formattedTime,
                      'TIME',
                      Icons.timer_outlined,
                    ),
                    Container(width: 1, height: 40, color: Colors.white12),
                    _statColumn(
                      locService.formattedPace,
                      'PACE',
                      Icons.speed,
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom Action Buttons ─────────────────────
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Sabotage button
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: FortRunTheme.sabotageGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _triggerSabotage,
                        borderRadius: BorderRadius.circular(14),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_fire_department,
                                  color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'SABOTAGE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Run Start/Stop button
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        locService.isTracking ? _stopRun : _startRun,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: locService.isTracking
                          ? FortRunTheme.enemyRed
                          : FortRunTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          locService.isTracking
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 24,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          locService.isTracking ? 'STOP RUN' : 'START RUN',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String value, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: FortRunTheme.primaryGreen, size: 18),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
              color: FortRunTheme.textMuted,
              fontSize: 11,
              letterSpacing: 1.2,
            )),
      ],
    );
  }
}
