import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:share_plus/share_plus.dart';
import '../utils/theme.dart';

/// ============================================================
/// RunSummaryScreen — Post-run celebration with route map,
/// stats breakdown, and social sharing.
/// ============================================================

class RunSummaryScreen extends StatefulWidget {
  final double distanceKm;
  final int durationSeconds;
  final String sector;
  final int pointsEarned;
  final int streak;
  final double multiplier;
  final List<ll.LatLng> routePoints;

  const RunSummaryScreen({
    super.key,
    required this.distanceKm,
    required this.durationSeconds,
    required this.sector,
    required this.pointsEarned,
    required this.streak,
    required this.multiplier,
    required this.routePoints,
  });

  @override
  State<RunSummaryScreen> createState() => _RunSummaryScreenState();
}

class _RunSummaryScreenState extends State<RunSummaryScreen>
    with TickerProviderStateMixin {
  late final AnimationController _headerCtrl;
  late final AnimationController _statsCtrl;
  late final Animation<double> _headerScale;
  late final Animation<double> _statsOpacity;
  late final Animation<Offset> _statsSlide;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _statsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _headerScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutBack),
    );
    _statsOpacity = CurvedAnimation(parent: _statsCtrl, curve: Curves.easeOut);
    _statsSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _statsCtrl, curve: Curves.easeOut));

    _headerCtrl.forward().then((_) => _statsCtrl.forward());
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _statsCtrl.dispose();
    super.dispose();
  }

  String get _formattedDuration {
    int hrs = widget.durationSeconds ~/ 3600;
    int mins = (widget.durationSeconds % 3600) ~/ 60;
    int secs = widget.durationSeconds % 60;
    if (hrs > 0) {
      return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String get _formattedPace {
    if (widget.distanceKm <= 0) return '--:--';
    double minPerKm = (widget.durationSeconds / 60) / widget.distanceKm;
    int mins = minPerKm.floor();
    int secs = ((minPerKm - mins) * 60).round();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _shareRun() {
    final distStr = widget.distanceKm.toStringAsFixed(2);
    final pts = widget.pointsEarned;
    final sector = widget.sector;
    final streakStr = widget.streak > 0 ? ' 🔥 ${widget.streak}-day streak!' : '';

    Share.share(
      '🏃 I just ran ${distStr}km in Sector $sector on FortRun!\n'
      '⭐ Earned $pts points$streakStr\n\n'
      'Join me and help claim Islamabad! 🇵🇰\n'
      '#FortRun #Islamabad #Running',
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = widget.routePoints.length >= 2;
    final isStreak = widget.streak > 0;
    final isMilestone = widget.streak == 7 || widget.streak == 14 ||
        widget.streak == 30 || widget.streak == 3;

    return Scaffold(
      backgroundColor: FortRunTheme.scaffoldDark,
      body: Container(
        decoration: const BoxDecoration(gradient: FortRunTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // ── Animated Trophy Header ─────────────────
                ScaleTransition(
                  scale: _headerScale,
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: FortRunTheme.primaryGreen.withOpacity(0.1),
                            ),
                          ),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: FortRunTheme.primaryGradient,
                            ),
                            child: Icon(
                              isMilestone
                                  ? Icons.military_tech_rounded
                                  : Icons.emoji_events_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isMilestone ? 'MILESTONE!' : 'RUN COMPLETE',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sector ${widget.sector}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: FortRunTheme.primaryGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Route Map ─────────────────────────────
                if (hasRoute) ...[
                  SlideTransition(
                    position: _statsSlide,
                    child: FadeTransition(
                      opacity: _statsOpacity,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: FortRunTheme.primaryGreen.withOpacity(0.2),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: widget.routePoints[
                                widget.routePoints.length ~/ 2],
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                              subdomains: const ['a', 'b', 'c', 'd'],
                              userAgentPackageName: 'com.fortrun.app',
                            ),
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: widget.routePoints,
                                  color: FortRunTheme.primaryGreen,
                                  strokeWidth: 4,
                                  gradientColors: [
                                    FortRunTheme.primaryGreen,
                                    FortRunTheme.primaryGreenDeep,
                                  ],
                                ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: widget.routePoints.first,
                                  child: const Icon(Icons.circle,
                                      color: FortRunTheme.safeBlue, size: 12),
                                ),
                                Marker(
                                  point: widget.routePoints.last,
                                  child: const Icon(Icons.location_on,
                                      color: FortRunTheme.primaryGreen, size: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Stats Grid ────────────────────────────
                SlideTransition(
                  position: _statsSlide,
                  child: FadeTransition(
                    opacity: _statsOpacity,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _StatCard(
                              value: widget.distanceKm.toStringAsFixed(2),
                              label: 'KILOMETERS',
                              icon: Icons.straighten_rounded,
                              color: FortRunTheme.primaryGreen,
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              value: _formattedDuration,
                              label: 'DURATION',
                              icon: Icons.timer_outlined,
                              color: FortRunTheme.safeBlue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _StatCard(
                              value: _formattedPace,
                              label: 'PACE /KM',
                              icon: Icons.speed_rounded,
                              color: FortRunTheme.warningOrange,
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              value: '+${widget.pointsEarned}',
                              label: 'POINTS',
                              icon: Icons.stars_rounded,
                              color: FortRunTheme.starGold,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Streak Banner ─────────────────────────
                if (isStreak) ...[
                  const SizedBox(height: 16),
                  SlideTransition(
                    position: _statsSlide,
                    child: FadeTransition(
                      opacity: _statsOpacity,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2A1F00),
                              Color(0xFF1A1200),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: FortRunTheme.starGold.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: FortRunTheme.starGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.local_fire_department,
                                color: FortRunTheme.starGold,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.streak}-Day Streak!',
                                    style: GoogleFonts.outfit(
                                      color: FortRunTheme.starGold,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (widget.multiplier > 1)
                                    Text(
                                      '${widget.multiplier}× points multiplier applied',
                                      style: GoogleFonts.outfit(
                                        color: FortRunTheme.starGold
                                            .withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // ── Action Buttons ────────────────────────
                SlideTransition(
                  position: _statsSlide,
                  child: FadeTransition(
                    opacity: _statsOpacity,
                    child: Row(
                      children: [
                        // Share button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _shareRun,
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text('Share'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                  color: FortRunTheme.cardDarkBorder),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Done button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              'DONE',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: FortRunTheme.cardDarkAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: FortRunTheme.textMuted,
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
