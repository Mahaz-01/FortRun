import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import '../utils/theme.dart';
import 'settings_screen.dart';

/// ============================================================
/// ProfileScreen — User stats, streaks, run history, settings.
/// ============================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _editName(BuildContext context, UserModel user) {
    final controller = TextEditingController(text: user.name);
    final dbService = context.read<DatabaseService>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FortRunTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Your name',
            prefixIcon: Icon(Icons.person),
          ),
          maxLength: 24,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: FortRunTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await dbService.updateUser(user.id, {'name': name});
              } catch (_) {}
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

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
                child: Text('User data not found',
                    style: TextStyle(color: Colors.white)),
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ── Top bar with settings ───────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          );
                        },
                        icon: const Icon(Icons.settings,
                            color: FortRunTheme.textMuted),
                      ),
                    ),

                    // ── Avatar & Name ───────────────────────
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: FortRunTheme.primaryGradient,
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: FortRunTheme.cardDark,
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'R',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: FortRunTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _editName(context, user),
                          child: const Icon(Icons.edit,
                              color: FortRunTheme.textMuted, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.phone ?? user.email ?? '',
                      style: const TextStyle(
                          color: FortRunTheme.textMuted, fontSize: 13),
                    ),
                    if (user.currentFortressSector != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: FortRunTheme.primaryGreen.withAlpha(38),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: FortRunTheme.primaryGreen.withAlpha(102),
                          ),
                        ),
                        child: Text(
                          'Fortress: ${user.currentFortressSector}',
                          style: const TextStyle(
                            color: FortRunTheme.primaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Streak Banner ─────────────────────────
                    if (user.streakCount > 0)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              FortRunTheme.starGold.withAlpha(30),
                              FortRunTheme.warningOrange.withAlpha(30),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: FortRunTheme.starGold.withAlpha(77)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.local_fire_department,
                                color: FortRunTheme.starGold, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              '${user.streakCount}-day streak',
                              style: const TextStyle(
                                color: FortRunTheme.starGold,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Best: ${user.longestStreak}',
                              style: TextStyle(
                                color: FortRunTheme.starGold.withAlpha(153),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Stats Grid ──────────────────────────
                    Row(
                      children: [
                        _statCard(
                          user.totalKm.toStringAsFixed(1),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _statCard(
                          '${user.totalRuns}',
                          'Total Runs',
                          Icons.directions_run,
                          FortRunTheme.safeBlue,
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          '${user.longestStreak}',
                          'Best Streak',
                          Icons.local_fire_department,
                          FortRunTheme.warningOrange,
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

                    StreamBuilder<List<RunModel>>(
                      stream: dbService.streamUserRuns(uid),
                      builder: (context, runSnap) {
                        if (runSnap.connectionState ==
                            ConnectionState.waiting) {
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
                                Icon(Icons.directions_run,
                                    color: FortRunTheme.textMuted, size: 40),
                                SizedBox(height: 10),
                                Text(
                                  'No runs yet. Hit START RUN!',
                                  style: TextStyle(
                                      color: FortRunTheme.textMuted),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children:
                              runs.map((run) => _runTile(run)).toList(),
                        );
                      },
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

  Widget _statCard(
      String value, String label, IconData icon, Color color) {
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
              color: FortRunTheme.primaryGreen.withAlpha(30),
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
                  style: const TextStyle(
                      color: FortRunTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '+${run.pointsEarned}',
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
