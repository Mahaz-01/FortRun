import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/theme.dart';

/// ============================================================
/// RunSummaryScreen — Full-screen post-run results.
/// ============================================================

class RunSummaryScreen extends StatelessWidget {
  final double distanceKm;
  final int durationSeconds;
  final String sector;
  final int pointsEarned;
  final int streak;
  final double multiplier;
  final List<LatLng> routePoints;

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

  String _formatDuration(int seconds) {
    int hrs = seconds ~/ 3600;
    int mins = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    if (hrs > 0) {
      return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatPace() {
    if (distanceKm <= 0) return '--:--';
    double minutesPerKm = (durationSeconds / 60) / distanceKm;
    int mins = minutesPerKm.floor();
    int secs = ((minutesPerKm - mins) * 60).round();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A2E), Color(0xFF0F3460)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // Trophy icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: FortRunTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: FortRunTheme.primaryGreen.withAlpha(102),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.emoji_events_rounded, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  'RUN COMPLETE',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sector $sector',
                  style: TextStyle(
                    fontSize: 15,
                    color: FortRunTheme.primaryGreen.withAlpha(204),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 32),

                // Route map preview
                if (routePoints.length >= 2)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FortRunTheme.primaryGreen.withAlpha(51)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: routePoints[routePoints.length ~/ 2],
                        zoom: 15,
                      ),
                      polylines: {
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: routePoints,
                          color: FortRunTheme.primaryGreen,
                          width: 4,
                        ),
                      },
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      scrollGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      liteModeEnabled: true,
                    ),
                  ),

                const SizedBox(height: 28),

                // Stats grid
                Row(
                  children: [
                    _bigStatCard(
                      distanceKm.toStringAsFixed(2),
                      'KM',
                      Icons.straighten,
                      FortRunTheme.primaryGreen,
                    ),
                    const SizedBox(width: 12),
                    _bigStatCard(
                      _formatDuration(durationSeconds),
                      'TIME',
                      Icons.timer_outlined,
                      FortRunTheme.safeBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _bigStatCard(
                      _formatPace(),
                      'PACE /KM',
                      Icons.speed,
                      FortRunTheme.warningOrange,
                    ),
                    const SizedBox(width: 12),
                    _bigStatCard(
                      '+$pointsEarned',
                      'POINTS',
                      Icons.star,
                      FortRunTheme.starGold,
                    ),
                  ],
                ),

                // Streak banner
                if (streak > 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          FortRunTheme.starGold.withAlpha(38),
                          FortRunTheme.warningOrange.withAlpha(38),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FortRunTheme.starGold.withAlpha(77)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_fire_department, color: FortRunTheme.starGold, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          '$streak-day streak! ${multiplier > 1 ? "(${multiplier}x points)" : ""}',
                          style: const TextStyle(
                            color: FortRunTheme.starGold,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 36),

                // Done button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
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

  Widget _bigStatCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: FortRunTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(51)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: FortRunTheme.textMuted,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
