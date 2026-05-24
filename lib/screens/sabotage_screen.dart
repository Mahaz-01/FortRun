import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/game_engine.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/restaurant_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

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
  bool _isLoadingRestaurants = true;
  bool _canSabotage = true;
  String? _proximityError;
  List<SabotageSpot> _spots = [];

  final RestaurantService _restaurantService = RestaurantService();

  @override
  void initState() {
    super.initState();
    _checkCooldown();
    _loadRestaurants();
  }

  Future<void> _checkCooldown() async {
    final dbService = context.read<DatabaseService>();
    final uid = context.read<AuthService>().currentUser?.id;
    if (uid == null) return;

    final allowed =
        await dbService.checkSabotageCooldown(uid, widget.sector);
    if (mounted) {
      setState(() {
        _canSabotage = allowed;
        _isCheckingCooldown = false;
      });
    }
  }

  Future<void> _loadRestaurants() async {
    final locService = context.read<LocationService>();
    final pos = locService.currentPosition;

    setState(() => _isLoadingRestaurants = true);

    if (pos != null) {
      try {
        final spots = await _restaurantService.getNearbyRestaurants(
          lat: pos.latitude,
          lng: pos.longitude,
          radiusMeters: 1500,
          currentSector: widget.sector,
        );
        if (mounted) {
          setState(() {
            _spots = spots;
            _isLoadingRestaurants = false;
          });
          return;
        }
      } catch (_) {}
    }

    // Fallback: hardcoded spots
    if (mounted) {
      setState(() {
        _spots = AppConstants.fallbackSabotageSpots
            .where((s) => s.sector == widget.sector)
            .toList();
        _isLoadingRestaurants = false;
      });
    }
  }

  bool _checkProximity() {
    if (_selectedSpot == null) return false;
    final locService = context.read<LocationService>();
    final pos = locService.currentPosition;
    if (pos == null) {
      setState(
          () => _proximityError = 'Cannot determine your location.');
      return false;
    }

    final dist = locService.distanceToPointMeters(
      pos.latitude, pos.longitude,
      _selectedSpot!.lat, _selectedSpot!.lng,
    );

    if (dist > AppConstants.sabotageProximityMeters) {
      setState(() => _proximityError =
          'You are ${dist.round()}m away. Get within ${AppConstants.sabotageProximityMeters.round()}m of ${_selectedSpot!.name}.');
      return false;
    }

    setState(() => _proximityError = null);
    return true;
  }

  Future<void> _executeSabotage() async {
    if (_selectedSpot == null || !_checkProximity()) return;

    setState(() => _isProcessing = true);

    final authService = context.read<AuthService>();
    final gameEngine = context.read<GameEngine>();
    final dbService = context.read<DatabaseService>();
    final uid = authService.currentUser?.id;
    if (uid == null) {
      setState(() => _isProcessing = false);
      return;
    }

    final damage = await gameEngine.processSabotage(
      runnerId: uid,
      sector: widget.sector,
      restaurantName: _selectedSpot!.name,
      dbService: dbService,
    );

    setState(() => _isProcessing = false);

    if (mounted) {
      _showSabotageResult(damage);
    }
  }

  void _showSabotageResult(int damage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: FortRunTheme.cardDark,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: damage > 0
                    ? FortRunTheme.sabotageGradient
                    : const LinearGradient(
                        colors: [FortRunTheme.textMuted, FortRunTheme.textMuted]),
              ),
              child: Icon(
                damage > 0
                    ? Icons.local_fire_department
                    : Icons.block_outlined,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              damage > 0 ? 'SABOTAGED!' : 'FAILED',
              style: GoogleFonts.outfit(
                color: damage > 0 ? FortRunTheme.enemyRed : FortRunTheme.textMuted,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            if (damage > 0) ...[
              Text(
                '$damage pts destroyed from Sector ${widget.sector}!',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'at ${_selectedSpot!.name}',
                style: GoogleFonts.outfit(
                    color: FortRunTheme.primaryGreen, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '+${(damage * 0.25).round()} bonus points for you!',
                style: GoogleFonts.outfit(
                    color: FortRunTheme.starGold, fontSize: 13),
              ),
            ] else
              Text(
                'Sabotage failed. Try again later.',
                style: GoogleFonts.outfit(
                    color: FortRunTheme.textMuted, fontSize: 14),
              ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('DONE'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FortRunTheme.scaffoldDark,
      appBar: AppBar(
        title: Text(
          'Sabotage — Sector ${widget.sector}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isCheckingCooldown
          ? const Center(child: CircularProgressIndicator(
              color: FortRunTheme.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cooldown Warning ──────────────────────
                  if (!_canSabotage) _CooldownBanner(),

                  // ── How it works banner ───────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: FortRunTheme.sabotageGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Go to a restaurant in enemy territory. GPS will verify your location.',
                            style: GoogleFonts.outfit(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Step 1: Choose restaurant ─────────────
                  _StepLabel(
                      '1', 'SELECT A RESTAURANT', FortRunTheme.primaryGreen),
                  const SizedBox(height: 12),

                  if (_isLoadingRestaurants)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                                color: FortRunTheme.primaryGreen),
                            SizedBox(height: 12),
                            Text(
                              'Loading nearby restaurants...',
                              style: TextStyle(
                                  color: FortRunTheme.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_spots.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: FortRunTheme.cardDarkAlt,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: FortRunTheme.cardDarkBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.restaurant_outlined,
                              color: FortRunTheme.textMuted, size: 36),
                          const SizedBox(height: 10),
                          Text(
                            'No restaurants found in this sector.\nTry moving closer to enemy territory.',
                            style: GoogleFonts.outfit(
                                color: FortRunTheme.textMuted, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _loadRestaurants,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry'),
                            style: TextButton.styleFrom(
                                foregroundColor: FortRunTheme.primaryGreen),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._spots.map((spot) => _SpotCard(
                          spot: spot,
                          isSelected: _selectedSpot == spot,
                          onTap: () => setState(() {
                            _selectedSpot = spot;
                            _proximityError = null;
                          }),
                        )),

                  const SizedBox(height: 24),

                  // ── Step 2: GPS Verify ────────────────────
                  _StepLabel('2', 'GPS VERIFICATION', FortRunTheme.safeBlue),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FortRunTheme.cardDarkAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _proximityError != null
                            ? FortRunTheme.enemyRed.withOpacity(0.4)
                            : FortRunTheme.cardDarkBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.gps_fixed_rounded,
                          color: _proximityError != null
                              ? FortRunTheme.enemyRed
                              : FortRunTheme.primaryGreen,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedSpot == null
                                ? 'Select a restaurant first'
                                : _proximityError ??
                                    'GPS will verify you\'re at ${_selectedSpot!.name} when you execute.',
                            style: GoogleFonts.outfit(
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

                  const SizedBox(height: 32),

                  // ── Execute Button ────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: (_selectedSpot != null &&
                              _canSabotage &&
                              !_isProcessing)
                          ? _executeSabotage
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding:
                            const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: (_selectedSpot != null && _canSabotage)
                              ? FortRunTheme.sabotageGradient
                              : null,
                          color: (_selectedSpot == null || !_canSabotage)
                              ? FortRunTheme.cardDarkAlt
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          border: (_selectedSpot == null || !_canSabotage)
                              ? Border.all(color: FortRunTheme.cardDarkBorder)
                              : null,
                        ),
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
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _canSabotage
                                          ? Icons.local_fire_department
                                          : Icons.timer_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _canSabotage
                                          ? 'EXECUTE SABOTAGE'
                                          : 'COOLDOWN ACTIVE',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _CooldownBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FortRunTheme.warningOrange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: FortRunTheme.warningOrange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined,
              color: FortRunTheme.warningOrange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cooldown active! You can sabotage this sector again in a few hours.',
              style: GoogleFonts.outfit(
                  color: FortRunTheme.warningOrange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final String step;
  final String label;
  final Color color;
  const _StepLabel(this.step, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              step,
              style: GoogleFonts.outfit(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: FortRunTheme.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SpotCard extends StatelessWidget {
  final SabotageSpot spot;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpotCard(
      {required this.spot, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? FortRunTheme.primaryGreen.withOpacity(0.08)
              : FortRunTheme.cardDarkAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? FortRunTheme.primaryGreen
                : FortRunTheme.cardDarkBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? FortRunTheme.primaryGreen.withOpacity(0.15)
                    : FortRunTheme.cardDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.restaurant_rounded,
                color: isSelected
                    ? FortRunTheme.primaryGreen
                    : FortRunTheme.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.white : FortRunTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (spot.cuisine != null)
                    Text(
                      spot.cuisine!,
                      style: const TextStyle(
                          color: FortRunTheme.textMuted, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (spot.isDynamic)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: FortRunTheme.safeBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: FortRunTheme.safeBlue.withOpacity(0.3)),
                ),
                child: Text(
                  'LIVE',
                  style: GoogleFonts.outfit(
                    color: FortRunTheme.safeBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle_rounded,
                    color: FortRunTheme.primaryGreen, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
