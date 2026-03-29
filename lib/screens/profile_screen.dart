import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import '../utils/theme.dart';

/// ============================================================
/// ProfileScreen — User stats, controlled territories, run history.
/// ============================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dbService = context.read<DatabaseService>();
    final uid = authService.currentUser?.id;

    if (uid == null) {
      return const Center(child: Text('Not logged in'));
    }

    return Scaffold(
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
        child: StreamBuilder<UserModel?>(
          stream: dbService.streamUser(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: FortRunTheme.primaryGreen),
              );
            }

            final user = snapshot.data;
            if (user == null) {
              return const Center(
                child: Text('User data not found', style: TextStyle(color: Colors.white)),
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // ── Avatar & Name ───────────────────────
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: FortRunTheme.primaryGradient,
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: FortRunTheme.cardDark,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'R',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: FortRunTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.phone ?? user.email ?? '',
                      style: const TextStyle(color: FortRunTheme.textMuted, fontSize: 13),
                    ),
                    if (user.currentFortressSector != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: FortRunTheme.primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: FortRunTheme.primaryGreen.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          '🏰 Fortress: ${user.currentFortressSector}',
                          style: const TextStyle(
                            color: FortRunTheme.primaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Stats Grid ──────────────────────────
                    Row(
                      children: [
                        _statCard(
                          '${user.totalKm.toStringAsFixed(1)}',
                          'Total KM',
                          Icons.straighten,
                          FortRunTheme.primaryGreen,
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          '${user.points}',
                          'Points',
                          Icons.star,
                          FortRunTheme.starGold,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ── Run History ──────────────────────────
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'RUN HISTORY',
                        style: TextStyle(
                          color: FortRunTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    FutureBuilder<List<RunModel>>(
                      future: dbService.getUserRuns(uid),
                      builder: (context, runSnap) {
                        if (runSnap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(30),
                            child: CircularProgressIndicator(
                              color: FortRunTheme.primaryGreen,
                            ),
                          );
                        }

                        final runs = runSnap.data ?? [];
                        if (runs.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: FortRunTheme.cardDarkAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.directions_run, color: FortRunTheme.textMuted, size: 40),
                                SizedBox(height: 10),
                                Text(
                                  'No runs yet. Hit START RUN!',
                                  style: TextStyle(color: FortRunTheme.textMuted),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: runs.map((run) => _runTile(run)).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // ── Sign Out Button ─────────────────────
                    OutlinedButton.icon(
                      onPressed: () => authService.signOut(),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FortRunTheme.enemyRed,
                        side: const BorderSide(color: FortRunTheme.enemyRed),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: FortRunTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: FortRunTheme.textMuted,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _runTile(RunModel run) {
    String distance = '${run.distanceKm.toStringAsFixed(2)} km';
    int mins = run.durationSeconds ~/ 60;
    String duration = '${mins}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FortRunTheme.cardDarkAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FortRunTheme.primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_run,
                color: FortRunTheme.primaryGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sector ${run.primarySector}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$distance · $duration',
                  style: const TextStyle(color: FortRunTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '+${run.pointsEarned} ⭐',
            style: const TextStyle(
              color: FortRunTheme.starGold,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
