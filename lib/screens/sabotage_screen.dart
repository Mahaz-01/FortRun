import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/game_engine.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// ============================================================
/// SabotageScreen — Pick a restaurant, verify proximity,
/// and deduct massive points from the zone owner.
/// ============================================================

class SabotageScreen extends StatefulWidget {
  final String sector;

  const SabotageScreen({super.key, required this.sector});

  @override
  State<SabotageScreen> createState() => _SabotageScreenState();
}

class _SabotageScreenState extends State<SabotageScreen> {
  SabotageSpot? _selectedSpot;
  bool _isProcessing = false;
  bool _isCheckingCooldown = true;
  bool _canSabotage = true;
  String? _proximityError;

  List<SabotageSpot> get _nearbySpots => AppConstants.sabotageSpots
      .where((s) => s.sector == widget.sector)
      .toList();

  @override
  void initState() {
    super.initState();
    _checkCooldown();
  }

  Future<void> _checkCooldown() async {
    final dbService = context.read<DatabaseService>();
    final uid = context.read<AuthService>().currentUser?.id;
    if (uid == null) return;

    final allowed = await dbService.checkSabotageCooldown(uid, widget.sector);
    if (mounted) {
      setState(() {
        _canSabotage = allowed;
        _isCheckingCooldown = false;
      });
    }
  }

  bool _checkProximity() {
    if (_selectedSpot == null) return false;

    final locService = context.read<LocationService>();
    final pos = locService.currentPosition;
    if (pos == null) {
      setState(() => _proximityError = 'Cannot determine your location.');
      return false;
    }

    final distanceMeters = locService.distanceToPointMeters(
      pos.latitude,
      pos.longitude,
      _selectedSpot!.lat,
      _selectedSpot!.lng,
    );

    if (distanceMeters > AppConstants.sabotageProximityMeters) {
      setState(() => _proximityError =
          'You are ${distanceMeters.round()}m away. Get within ${AppConstants.sabotageProximityMeters.round()}m of ${_selectedSpot!.name}.');
      return false;
    }

    setState(() => _proximityError = null);
    return true;
  }

  Future<void> _executeSabotage() async {
    if (_selectedSpot == null) return;

    if (!_checkProximity()) return;

    setState(() => _isProcessing = true);

    final authService = context.read<AuthService>();
    final gameEngine = context.read<GameEngine>();
    final dbService = context.read<DatabaseService>();
    final uid = authService.currentUser?.id;

    if (uid == null) {
      setState(() => _isProcessing = false);
      return;
    }

    int damage = await gameEngine.processSabotage(
      runnerId: uid,
      sector: widget.sector,
      restaurantName: _selectedSpot!.name,
      dbService: dbService,
    );

    setState(() => _isProcessing = false);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: FortRunTheme.cardDark,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.local_fire_department,
                  color: FortRunTheme.enemyRed, size: 28),
              SizedBox(width: 10),
              Text('SABOTAGE!',
                  style: TextStyle(color: FortRunTheme.enemyRed)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                damage > 0
                    ? 'You destroyed $damage points from Sector ${widget.sector}\'s owner!'
                    : 'Sabotage failed! Try again later.',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (damage > 0) ...[
                const SizedBox(height: 12),
                Text(
                  'at ${_selectedSpot!.name}',
                  style: const TextStyle(
                    color: FortRunTheme.starGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '+${(damage * 0.25).round()} bonus points for you!',
                  style: TextStyle(
                    color: FortRunTheme.primaryGreen.withAlpha(204),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('DONE',
                  style: TextStyle(color: FortRunTheme.primaryGreen)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sabotage — ${widget.sector}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isCheckingCooldown
            ? const Center(
                child: CircularProgressIndicator(
                    color: FortRunTheme.primaryGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Cooldown warning ──────────────────────
                    if (!_canSabotage) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FortRunTheme.warningOrange.withAlpha(25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: FortRunTheme.warningOrange.withAlpha(102)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.timer,
                                color: FortRunTheme.warningOrange, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Cooldown active! You can sabotage this sector again in a few hours.',
                                style: TextStyle(
                                    color: FortRunTheme.warningOrange,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Warning banner ────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: FortRunTheme.sabotageGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Go to a restaurant in enemy territory to sabotage the owner and steal their points!',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Select Restaurant ─────────────────────
                    const Text(
                      '1. SELECT RESTAURANT',
                      style: TextStyle(
                        color: FortRunTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_nearbySpots.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: FortRunTheme.cardDarkAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No sabotage spots registered in this sector yet.',
                          style: TextStyle(color: FortRunTheme.textMuted),
                        ),
                      )
                    else
                      ..._nearbySpots.map((spot) {
                        bool isSelected = _selectedSpot == spot;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSpot = spot;
                              _proximityError = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? FortRunTheme.primaryGreen.withAlpha(38)
                                  : FortRunTheme.cardDarkAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(
                                      color: FortRunTheme.primaryGreen,
                                      width: 2)
                                  : Border.all(color: Colors.transparent),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.restaurant,
                                  color: isSelected
                                      ? FortRunTheme.primaryGreen
                                      : FortRunTheme.textMuted,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    spot.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : FortRunTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle,
                                      color: FortRunTheme.primaryGreen,
                                      size: 22),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 28),

                    // ── Step 2: GPS Verification ──────────────
                    const Text(
                      '2. VERIFY LOCATION (GPS)',
                      style: TextStyle(
                        color: FortRunTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FortRunTheme.cardDarkAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.gps_fixed,
                            color: _proximityError == null
                                ? FortRunTheme.primaryGreen
                                : FortRunTheme.enemyRed,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _selectedSpot == null
                                  ? 'Select a restaurant first'
                                  : _proximityError ??
                                      'GPS will verify you are at ${_selectedSpot!.name} when you execute.',
                              style: TextStyle(
                                color: _proximityError != null
                                    ? FortRunTheme.enemyRed
                                    : FortRunTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Execute Sabotage ──────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient:
                              (_selectedSpot != null && _canSabotage)
                                  ? FortRunTheme.sabotageGradient
                                  : null,
                          color:
                              (_selectedSpot == null || !_canSabotage)
                                  ? Colors.grey[800]
                                  : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: (_selectedSpot != null &&
                                    _canSabotage &&
                                    !_isProcessing)
                                ? _executeSabotage
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 18),
                              child: Center(
                                child: _isProcessing
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        _canSabotage
                                            ? 'EXECUTE SABOTAGE'
                                            : 'COOLDOWN ACTIVE',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
