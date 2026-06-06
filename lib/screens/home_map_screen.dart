import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/game_engine.dart';
import '../services/database_service.dart';
import '../models/run_model.dart';
import '../models/zone_model.dart';
import '../models/wall_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../utils/tappable.dart';
import 'sabotage_screen.dart';
import 'run_summary_screen.dart';
import 'activity_feed_screen.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  List<ZoneModel> _zones = [];
  List<WallModel> _walls = [];
  List<RunModel> _allRuns = [];
  UserModel? _currentUser;
  StreamSubscription? _zoneSub;
  StreamSubscription? _wallSub;
  StreamSubscription? _userSub;
  StreamSubscription? _allRunsSub;

  final Map<String, String> _ownerNames = {};

  // Pulse ring for GPS dot
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  // GO button glow
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  // Panel slide animation
  late final AnimationController _panelCtrl;
  late final Animation<double> _panelAnim;

  bool _wasTracking = false;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: false);
    _pulseScale = Tween<double>(begin: 1.0, end: 2.8).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _panelAnim = CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic);

    _initLocation();
    _listenToData();
  }

  void _initLocation() async {
    final locService = context.read<LocationService>();
    await locService.getCurrentPosition();
    if (locService.permissionError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locService.permissionError!),
          action: SnackBarAction(
            label: 'RETRY',
            textColor: FortRunTheme.primaryGreen,
            onPressed: _initLocation,
          ),
        ),
      );
    }
  }

  void _listenToData() {
    final dbService = context.read<DatabaseService>();
    final authService = context.read<AuthService>();
    final locService = context.read<LocationService>();

    _zoneSub = dbService.streamAllZones().listen((zones) {
      locService.updateActiveZones(zones);
      if (mounted) {
        setState(() => _zones = zones);
        _prefetchOwnerNames(zones);
      }
    });

    _wallSub = dbService.streamAllWalls().listen((walls) {
      if (mounted) setState(() => _walls = walls);
    });

    _allRunsSub = dbService.streamAllRecentRuns().listen((runs) {
      if (mounted) setState(() => _allRuns = runs);
    });

    final uid = authService.currentUser?.id;
    if (uid != null) {
      _userSub = dbService.streamUser(uid).listen((user) {
        if (mounted) setState(() => _currentUser = user);
      });
    }
  }

  Future<void> _prefetchOwnerNames(List<ZoneModel> zones) async {
    final dbService = context.read<DatabaseService>();
    final ids = zones
        .where((z) => z.ownerId != null && !_ownerNames.containsKey(z.ownerId))
        .map((z) => z.ownerId!)
        .toSet();
    for (final uid in ids) {
      final user = await dbService.getUser(uid);
      if (user != null && mounted) {
        setState(() => _ownerNames[uid] = user.name);
      }
    }
  }

  // ── Map layers ────────────────────────────────────────────────

  List<Polygon> _buildZonePolygons() {
    final authService = context.read<AuthService>();
    final myUid = authService.currentUser?.id;
    final polygons = <Polygon>[];
    for (final zone in _zones) {
      if (zone.polygonCoords.isEmpty) continue;
      final pts = zone.polygonCoords.map((e) => ll.LatLng(e['lat']!, e['lng']!)).toList();
      Color fill, border;
      if (zone.ownerId == null) {
        fill = Colors.cyanAccent.withOpacity(0.04);
        border = Colors.white.withOpacity(0.18);
      } else if (zone.ownerId == myUid) {
        fill = FortRunTheme.primaryGreen.withOpacity(0.14);
        border = FortRunTheme.primaryGreen.withOpacity(0.65);
      } else {
        fill = FortRunTheme.enemyRed.withOpacity(0.13);
        border = FortRunTheme.enemyRed.withOpacity(0.6);
      }
      polygons.add(Polygon(
        points: pts,
        color: fill,
        borderColor: border,
        borderStrokeWidth: 1.5,
        label: zone.name.isNotEmpty ? zone.name : zone.id,
        labelStyle: GoogleFonts.outfit(
          color: Colors.white.withOpacity(0.55),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ));
    }
    return polygons;
  }

  List<Polygon> _buildWallPolygons() {
    final authService = context.read<AuthService>();
    final myUid = authService.currentUser?.id;
    final polygons = <Polygon>[];
    for (final wall in _walls) {
      if (wall.polygonCoords.isEmpty || wall.strength <= 0) continue;
      final pts = wall.polygonCoords.map((e) => ll.LatLng(e['lat']!, e['lng']!)).toList();
      final alpha = ((wall.strength / 100) * 0.7).clamp(0.08, 0.7);
      final isOwn = wall.ownerId == myUid;
      polygons.add(Polygon(
        points: pts,
        color: isOwn
            ? FortRunTheme.primaryGreen.withOpacity(alpha)
            : FortRunTheme.enemyRed.withOpacity(alpha),
        borderColor: isOwn ? FortRunTheme.primaryGreen : FortRunTheme.enemyRed,
        borderStrokeWidth: 0.4,
      ));
    }
    return polygons;
  }

  List<Polyline> _buildHistoricalTracks() {
    final myUid = context.read<AuthService>().currentUser?.id;
    final polylines = <Polyline>[];
    for (final run in _allRuns) {
      if (run.polylineCoords.length < 2) continue;
      final pts = run.polylineCoords
          .map((e) => ll.LatLng(e['lat']!, e['lng']!))
          .toList();
      final isOwn = run.userId == myUid;
      polylines.add(Polyline(
        points: pts,
        color: isOwn
            ? FortRunTheme.primaryGreen.withOpacity(0.7)
            : FortRunTheme.enemyRed.withOpacity(0.55),
        strokeWidth: isOwn ? 5.0 : 4.0,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ));
    }
    return polylines;
  }

  List<Polyline> _buildRoute(LocationService loc) {
    if (!loc.isTracking || loc.routePoints.isEmpty) return [];
    return [
      Polyline(
        points: loc.routePoints,
        color: FortRunTheme.primaryGreen,
        strokeWidth: 5,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
        gradientColors: [FortRunTheme.primaryGreen, FortRunTheme.primaryGreenDeep],
      ),
    ];
  }

  // ── Tap detection ─────────────────────────────────────────────

  void _onMapTap(ll.LatLng pt) {
    final myUid = context.read<AuthService>().currentUser?.id;
    for (final wall in _walls) {
      if (wall.polygonCoords.isEmpty) continue;
      final pts = wall.polygonCoords.map((e) => ll.LatLng(e['lat']!, e['lng']!)).toList();
      if (_pointInPolygon(pt, pts)) { _showWallSheet(wall, myUid); return; }
    }
    for (final zone in _zones) {
      if (zone.polygonCoords.isEmpty) continue;
      final pts = zone.polygonCoords.map((e) => ll.LatLng(e['lat']!, e['lng']!)).toList();
      if (_pointInPolygon(pt, pts)) { _showZoneSheet(zone, myUid); return; }
    }
  }

  bool _pointInPolygon(ll.LatLng p, List<ll.LatLng> poly) {
    int n = poly.length;
    bool inside = false;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      if (((poly[i].longitude > p.longitude) != (poly[j].longitude > p.longitude)) &&
          (p.latitude < (poly[j].latitude - poly[i].latitude) *
                  (p.longitude - poly[i].longitude) /
                  (poly[j].longitude - poly[i].longitude) +
              poly[i].latitude)) {
        inside = !inside;
      }
    }
    return inside;
  }

  // ── Bottom sheets ─────────────────────────────────────────────

  void _showZoneSheet(ZoneModel zone, String? myUid) {
    final ownerName = zone.ownerId == null
        ? 'Unclaimed'
        : zone.ownerId == myUid
            ? 'You'
            : (_ownerNames[zone.ownerId] ?? '...');
    final isEnemy = zone.ownerId != null && zone.ownerId != myUid;
    final color = isEnemy ? FortRunTheme.enemyRed : FortRunTheme.primaryGreen;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _GlassSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(isEnemy ? Icons.shield_rounded : Icons.shield_outlined,
                      color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name.isNotEmpty ? zone.name : 'Sector ${zone.id}',
                        style: GoogleFonts.outfit(
                          fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        isEnemy ? 'Enemy Territory' : zone.ownerId == null ? 'Neutral Zone' : 'Your Territory',
                        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Control bar
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: zone.controlPercentage / 100,
                minHeight: 8,
                backgroundColor: FortRunTheme.cardDarkBorder,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Controlled: ${zone.controlPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(color: FortRunTheme.textMuted, fontSize: 12)),
                Text('${zone.totalPoints} pts',
                    style: GoogleFonts.outfit(
                      color: FortRunTheme.starGold, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            _SheetRow(Icons.person_outline_rounded, 'Controlled by', ownerName),
            if (isEnemy) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FortRunTheme.enemyRed.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FortRunTheme.enemyRed.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: FortRunTheme.enemyRed, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Run here to invade and claim territory!',
                        style: const TextStyle(color: FortRunTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showWallSheet(WallModel wall, String? myUid) {
    final isOwn = wall.ownerId == myUid;
    final color = isOwn ? FortRunTheme.primaryGreen : FortRunTheme.enemyRed;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GlassSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.grid_view_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Territory Wall', style: GoogleFonts.outfit(
                      fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text(isOwn ? 'Your wall' : 'Enemy wall',
                      style: TextStyle(color: color, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Strength', style: TextStyle(color: FortRunTheme.textMuted, fontSize: 13)),
                Text('${wall.strength}%',
                    style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: wall.strength / 100,
                minHeight: 10,
                backgroundColor: FortRunTheme.cardDarkBorder,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 14),
            _SheetRow(Icons.person_outline_rounded, 'Owner',
                isOwn ? 'You' : (_ownerNames[wall.ownerId] ?? 'Enemy')),
            _SheetRow(Icons.location_on_outlined, 'Sector', wall.sectorId),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Run controls ──────────────────────────────────────────────

  Future<void> _startRun() async {
    final locService = context.read<LocationService>();
    final dbService = context.read<DatabaseService>();
    final uid = context.read<AuthService>().currentUser?.id;
    if (uid == null) return;
    final userProfile = await dbService.getUser(uid);
    await locService.startTracking(
      dbService: dbService,
      uid: uid,
      cid: userProfile?.clanId,
    );
    if (locService.permissionError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(locService.permissionError!)));
    }
  }

  Future<void> _stopRun() async {
    final locService = context.read<LocationService>();
    final authService = context.read<AuthService>();
    final gameEngine = context.read<GameEngine>();
    final dbService = context.read<DatabaseService>();
    final uid = authService.currentUser?.id;
    if (uid == null) return;

    final routeSnapshot = List<ll.LatLng>.from(locService.routePoints);
    final result = await locService.stopTracking();

    final run = RunModel(
      id: '',
      userId: uid,
      timestamp: DateTime.now(),
      distanceKm: result['distanceKm'],
      durationSeconds: result['durationSeconds'],
      primarySector: result['primarySector'],
      pointsEarned: 0,
      polylineCoords: List<Map<String, double>>.from(
          (result['polylineCoords'] as List).map((e) => Map<String, double>.from(e))),
    );
    String? runId;
    try { runId = await dbService.saveRun(run); } catch (_) {}

    final Map<String, dynamic> gameResult = runId == null
        ? <String, dynamic>{'pointsEarned': 0, 'streak': 0, 'multiplier': 1.0}
        : await gameEngine.processRun(
            runId: runId,
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

  void _triggerSabotage() {
    final locService = context.read<LocationService>();
    final uid = context.read<AuthService>().currentUser?.id;
    final currentZone = locService.currentZone;

    if (currentZone == null) {
      _snack('You\'re not inside any territory!');
      return;
    }
    ZoneModel? zone;
    try { zone = _zones.firstWhere((z) => z.id == currentZone); } catch (_) {}
    if (zone == null || zone.ownerId == null || zone.ownerId == uid) {
      _snack('You can only sabotage enemy territories!');
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => SabotageScreen(sector: currentZone)));
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  void _locateMe() async {
    final locService = context.read<LocationService>();
    final pos = await locService.getCurrentPosition();
    if (pos != null && mounted) {
      _mapController.move(ll.LatLng(pos.latitude, pos.longitude), 15.5);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _panelCtrl.dispose();
    _zoneSub?.cancel();
    _wallSub?.cancel();
    _userSub?.cancel();
    _allRunsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locService = context.watch<LocationService>();
    final pos = locService.currentPosition;

    // Animate panel when tracking changes
    if (locService.isTracking != _wasTracking) {
      _wasTracking = locService.isTracking;
      if (locService.isTracking) {
        _panelCtrl.forward();
      } else {
        _panelCtrl.reverse();
      }
    }

    final safePad = MediaQuery.of(context).padding;

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: pos != null
                  ? ll.LatLng(pos.latitude, pos.longitude)
                  : const ll.LatLng(AppConstants.islamabadLat, AppConstants.islamabadLng),
              initialZoom: AppConstants.defaultZoom,
              onTap: (_, point) => _onMapTap(point),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.fortrun.app',
                tileProvider: NetworkTileProvider(),
              ),
              PolygonLayer(polygons: _buildZonePolygons()),
              PolygonLayer(polygons: _buildWallPolygons()),
              PolylineLayer(polylines: _buildHistoricalTracks()),
              PolylineLayer(polylines: _buildRoute(locService)),
              if (pos != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: ll.LatLng(pos.latitude, pos.longitude),
                      width: 60,
                      height: 60,
                      child: _PulseDot(
                        pulseScale: _pulseScale,
                        pulseOpacity: _pulseOpacity,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── Top floating bar ─────────────────────────────────
          Positioned(
            top: safePad.top + 12,
            left: 16,
            right: 16,
            child: _TopBar(
              locService: locService,
              user: _currentUser,
              onFeed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ActivityFeedScreen())),
            ),
          ),

          // ── Right FABs ────────────────────────────────────────
          Positioned(
            right: 14,
            bottom: locService.isTracking ? 240 : 180,
            child: _MapFab(
              icon: Icons.my_location_rounded,
              onTap: _locateMe,
            ),
          ),

          // ── Bottom panel ─────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomPanel(
              locService: locService,
              panelAnim: _panelAnim,
              glowAnim: _glowAnim,
              onRunToggle: locService.isTracking ? _stopRun : _startRun,
              onSabotage: _triggerSabotage,
              safePad: safePad,
            ),
          ),
        ],
      ),
    );
  }
}

// ── GPS pulse dot ─────────────────────────────────────────────

class _PulseDot extends StatelessWidget {
  final Animation<double> pulseScale;
  final Animation<double> pulseOpacity;

  const _PulseDot({required this.pulseScale, required this.pulseOpacity});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulseScale, pulseOpacity]),
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer expanding ring
          Transform.scale(
            scale: pulseScale.value,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FortRunTheme.primaryGreen.withOpacity(pulseOpacity.value),
              ),
            ),
          ),
          // Inner solid dot
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FortRunTheme.primaryGreen,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: FortRunTheme.primaryGreen.withOpacity(0.7),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final LocationService locService;
  final UserModel? user;
  final VoidCallback onFeed;

  const _TopBar({
    required this.locService,
    required this.user,
    required this.onFeed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: FortRunTheme.cardDark.withOpacity(0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: locService.isTracking
                      ? FortRunTheme.primaryGreen
                      : FortRunTheme.textMuted,
                  boxShadow: locService.isTracking
                      ? [BoxShadow(
                          color: FortRunTheme.primaryGreen.withOpacity(0.6),
                          blurRadius: 6, spreadRadius: 1)]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  locService.isTracking
                      ? locService.currentZone != null
                          ? 'Tracking · Sector ${locService.currentZone}'
                          : 'Tracking run...'
                      : locService.currentZone != null
                          ? 'Sector ${locService.currentZone}'
                          : 'Run outside to claim territory',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Points badge
              if (user != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: FortRunTheme.starGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: FortRunTheme.starGold.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded,
                          color: FortRunTheme.starGold, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${user!.points}',
                        style: GoogleFonts.outfit(
                          color: FortRunTheme.starGold,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Feed button
              Tappable(
                onTap: onFeed,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: FortRunTheme.starGold, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Map FAB ───────────────────────────────────────────────────

class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapFab({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: FortRunTheme.cardDark.withOpacity(0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon, color: FortRunTheme.primaryGreen, size: 20),
          ),
        ),
      ),
    );
  }
}

// ── Bottom panel ──────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final LocationService locService;
  final Animation<double> panelAnim;
  final Animation<double> glowAnim;
  final VoidCallback onRunToggle;
  final VoidCallback onSabotage;
  final EdgeInsets safePad;

  const _BottomPanel({
    required this.locService,
    required this.panelAnim,
    required this.glowAnim,
    required this.onRunToggle,
    required this.onSabotage,
    required this.safePad,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: FortRunTheme.cardDark.withOpacity(0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
          ),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 350),
            crossFadeState: locService.isTracking
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: _IdlePanel(
              glowAnim: glowAnim,
              onGo: onRunToggle,
              onSabotage: onSabotage,
              safePad: safePad,
            ),
            secondChild: _RunPanel(
              locService: locService,
              onStop: onRunToggle,
              safePad: safePad,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Idle panel ────────────────────────────────────────────────

class _IdlePanel extends StatelessWidget {
  final Animation<double> glowAnim;
  final VoidCallback onGo;
  final VoidCallback onSabotage;
  final EdgeInsets safePad;

  const _IdlePanel({
    required this.glowAnim,
    required this.onGo,
    required this.onSabotage,
    required this.safePad,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, safePad.bottom + 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // SABOTAGE button
          Tappable(
            onTap: onSabotage,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: FortRunTheme.enemyRed.withOpacity(0.1),
                border: Border.all(color: FortRunTheme.enemyRed.withOpacity(0.35), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: FortRunTheme.enemyRed, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    'SABOTAGE',
                    style: GoogleFonts.outfit(
                      color: FortRunTheme.enemyRed,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Central GO button
          Tappable(
            onTap: onGo,
            child: AnimatedBuilder(
              animation: glowAnim,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring (subtle — accent, not neon)
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: FortRunTheme.primaryGreen
                              .withOpacity(glowAnim.value * 0.20),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  // Middle ring
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: FortRunTheme.primaryGreen.withOpacity(0.08),
                      border: Border.all(
                        color: FortRunTheme.primaryGreen
                            .withOpacity(glowAnim.value * 0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Core button
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: FortRunTheme.primaryGradient,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 32),
                        Text(
                          'GO',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 2,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right side — territory counter
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: FortRunTheme.primaryGreen.withOpacity(0.07),
              border: Border.all(
                  color: FortRunTheme.primaryGreen.withOpacity(0.2), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.castle_rounded,
                    color: FortRunTheme.primaryGreen, size: 26),
                const SizedBox(height: 4),
                Text(
                  'TERRITORY',
                  style: GoogleFonts.outfit(
                    color: FortRunTheme.primaryGreen,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Tap map',
                  style: GoogleFonts.outfit(
                    color: FortRunTheme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Active run panel ──────────────────────────────────────────

class _RunPanel extends StatelessWidget {
  final LocationService locService;
  final VoidCallback onStop;
  final EdgeInsets safePad;

  const _RunPanel({
    required this.locService,
    required this.onStop,
    required this.safePad,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, safePad.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: FortRunTheme.enemyRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'RUN IN PROGRESS',
                style: GoogleFonts.outfit(
                  color: FortRunTheme.enemyRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BigStat(
                value: locService.totalDistanceKm.toStringAsFixed(2),
                label: 'KM',
                color: FortRunTheme.primaryGreen,
              ),
              _StatDivider(),
              _BigStat(
                value: locService.formattedTime,
                label: 'TIME',
                color: Colors.white,
              ),
              _StatDivider(),
              _BigStat(
                value: locService.formattedPace,
                label: '/KM',
                color: FortRunTheme.safeBlue,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // STOP button
          Tappable(
            onTap: onStop,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [FortRunTheme.enemyRed, Color(0xFF8B0000)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: FortRunTheme.enemyRed.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stop_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'FINISH RUN',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _BigStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: FortRunTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: FortRunTheme.cardDarkBorder,
    );
  }
}

// ── Sheet helpers ─────────────────────────────────────────────

class _GlassSheet extends StatelessWidget {
  final Widget child;
  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: FortRunTheme.cardDark.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
          color: FortRunTheme.cardDarkBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SheetRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 17, color: FortRunTheme.textMuted),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: FortRunTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}
