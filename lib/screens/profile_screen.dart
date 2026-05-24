import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import '../utils/theme.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dbService = context.read<DatabaseService>();
    final uid = authService.currentUser?.id;

    if (uid == null) {
      return const Center(
          child: Text('Not logged in', style: TextStyle(color: Colors.white)));
    }

    return Scaffold(
      backgroundColor: FortRunTheme.scaffoldDark,
      body: StreamBuilder<UserModel?>(
        stream: dbService.streamUser(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: FortRunTheme.primaryGreen, strokeWidth: 2));
          }
          final user = snap.data;
          if (user == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_off_rounded,
                      color: FortRunTheme.textMuted, size: 48),
                  const SizedBox(height: 12),
                  Text('Profile loading...',
                      style: GoogleFonts.outfit(
                          color: FortRunTheme.textMuted, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Pull to refresh if this persists.',
                      style: const TextStyle(
                          color: FortRunTheme.textMuted, fontSize: 13)),
                ],
              ),
            );
          }

          return StreamBuilder<List<RunModel>>(
            stream: dbService.streamUserRuns(uid),
            builder: (context, runSnap) {
              final runs = runSnap.data ?? [];
              return CustomScrollView(
                slivers: [
                  _HeroAppBar(user: user, dbService: dbService),
                  SliverToBoxAdapter(child: _WeekRings(runs: runs)),
                  if (user.streakCount > 0)
                    SliverToBoxAdapter(child: _StreakBanner(user: user)),
                  SliverToBoxAdapter(child: _StatsRow(user: user)),
                  SliverToBoxAdapter(child: _AchievementsSection(user: user)),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: _SectionLabel('RECENT RUNS'),
                    ),
                  ),
                  if (runs.isEmpty)
                    SliverToBoxAdapter(child: _EmptyRuns())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _RunTile(run: runs[i]),
                          childCount: runs.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── Hero sliver app bar ───────────────────────────────────────

class _HeroAppBar extends StatelessWidget {
  final UserModel user;
  final DatabaseService dbService;
  const _HeroAppBar({required this.user, required this.dbService});

  void _editName(BuildContext context) {
    final ctrl = TextEditingController(text: user.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FortRunTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Runner Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              hintText: 'Your name', prefixIcon: Icon(Icons.person_rounded)),
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
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await dbService.updateUser(user.id, {'name': name});
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF0D0D0D),
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(Icons.settings_outlined, color: FortRunTheme.textMuted),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A1A0A), Color(0xFF080808)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // Background decorative arcs
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FortRunTheme.primaryGreen.withOpacity(0.04),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar
                      GestureDetector(
                        onTap: () => _editName(context),
                        child: Stack(
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    FortRunTheme.primaryGreen,
                                    FortRunTheme.primaryGreenDeep,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: FortRunTheme.primaryGreen.withOpacity(0.3),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF0D0D0D),
                                  ),
                                  child: Center(
                                    child: Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : 'R',
                                      style: GoogleFonts.outfit(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: FortRunTheme.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Edit badge
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: FortRunTheme.primaryGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFF0D0D0D), width: 2),
                                ),
                                child: const Icon(Icons.edit_rounded,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user.name,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email ?? user.phone ?? '',
                        style: const TextStyle(
                            color: FortRunTheme.textMuted, fontSize: 13),
                      ),
                      if (user.currentFortressSector != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: FortRunTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: FortRunTheme.primaryGreen.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.castle_rounded,
                                  color: FortRunTheme.primaryGreen, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Fortress: ${user.currentFortressSector}',
                                style: GoogleFonts.outfit(
                                  color: FortRunTheme.primaryGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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

// ── Weekly activity rings ─────────────────────────────────────

class _WeekRings extends StatelessWidget {
  final List<RunModel> runs;
  const _WeekRings({required this.runs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Build a set of days this week that have runs (Mon=0..Sun=6)
    final ranDays = <int>{};
    for (final run in runs) {
      final diff = now.difference(run.timestamp).inDays;
      if (diff < 7) {
        // Normalize to weekday index Mon=0
        final dayIdx = (run.timestamp.weekday - 1) % 7;
        ranDays.add(dayIdx);
      }
    }

    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIdx = (now.weekday - 1) % 7;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FortRunTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FortRunTheme.cardDarkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'THIS WEEK',
                style: GoogleFonts.outfit(
                  color: FortRunTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '${ranDays.length}/7 days',
                style: GoogleFonts.outfit(
                  color: ranDays.length >= 5
                      ? FortRunTheme.primaryGreen
                      : FortRunTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final hasRun = ranDays.contains(i);
              final isToday = i == todayIdx;
              return _DayRing(
                day: days[i],
                hasRun: hasRun,
                isToday: isToday,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DayRing extends StatelessWidget {
  final String day;
  final bool hasRun;
  final bool isToday;

  const _DayRing({
    required this.day,
    required this.hasRun,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: CustomPaint(
            painter: _RingPainter(
              filled: hasRun,
              isToday: isToday,
              color: hasRun
                  ? FortRunTheme.primaryGreen
                  : isToday
                      ? FortRunTheme.primaryGreen.withOpacity(0.3)
                      : FortRunTheme.cardDarkBorder,
            ),
            child: Center(
              child: hasRun
                  ? const Icon(Icons.check_rounded,
                      color: FortRunTheme.primaryGreen, size: 16)
                  : Text(
                      day,
                      style: GoogleFonts.outfit(
                        color: isToday ? Colors.white : FortRunTheme.textMuted,
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isToday
                ? FortRunTheme.primaryGreen
                : Colors.transparent,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final bool filled;
  final bool isToday;
  final Color color;

  const _RingPainter({
    required this.filled,
    required this.isToday,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final strokeWidth = 2.5;

    final bgPaint = Paint()
      ..color = FortRunTheme.cardDarkBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background circle
    canvas.drawCircle(center, radius, bgPaint);

    if (filled) {
      // Full circle
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi,
        false,
        fgPaint,
      );
    } else if (isToday) {
      // Quarter arc for today
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi / 2,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.filled != filled || old.isToday != isToday || old.color != color;
}

// ── Streak banner ─────────────────────────────────────────────

class _StreakBanner extends StatelessWidget {
  final UserModel user;
  const _StreakBanner({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FortRunTheme.starGold.withOpacity(0.10),
            FortRunTheme.warningOrange.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FortRunTheme.starGold.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FortRunTheme.starGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                color: FortRunTheme.starGold, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.streakCount}-Day Streak 🔥',
                  style: GoogleFonts.outfit(
                    color: FortRunTheme.starGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Best: ${user.longestStreak} days',
                  style: const TextStyle(
                      color: FortRunTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (user.streakCount >= 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: FortRunTheme.starGold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: FortRunTheme.starGold.withOpacity(0.3)),
              ),
              child: Text(
                user.streakCount >= 7 ? '2.0×' : '1.5×',
                style: GoogleFonts.outfit(
                  color: FortRunTheme.starGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final UserModel user;
  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: user.totalKm.toStringAsFixed(1),
              unit: 'km',
              label: 'Total Distance',
              color: FortRunTheme.primaryGreen,
              icon: Icons.straighten_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '${user.totalRuns}',
              unit: 'runs',
              label: 'Activities',
              color: FortRunTheme.safeBlue,
              icon: Icons.directions_run_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '${user.points}',
              unit: 'pts',
              label: 'Territory Pts',
              color: FortRunTheme.starGold,
              icon: Icons.stars_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: FortRunTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: GoogleFonts.outfit(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: FortRunTheme.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Achievements ──────────────────────────────────────────────

class _AchievementsSection extends StatelessWidget {
  final UserModel user;
  const _AchievementsSection({required this.user});

  List<_Badge> get _badges => [
        _Badge('First Run', Icons.directions_run_rounded, FortRunTheme.primaryGreen,
            user.totalRuns >= 1),
        _Badge('5K Club', Icons.straighten_rounded, FortRunTheme.safeBlue,
            user.totalKm >= 5),
        _Badge('10K Warrior', Icons.military_tech_rounded, FortRunTheme.warningOrange,
            user.totalKm >= 10),
        _Badge('Streak\nMaster', Icons.local_fire_department_rounded, FortRunTheme.starGold,
            user.longestStreak >= 7),
        _Badge('Century', Icons.star_rounded, Colors.purple, user.points >= 100),
        _Badge('Fort\nOwner', Icons.castle_rounded, FortRunTheme.primaryGreenDeep,
            user.currentFortressSector != null),
        _Badge('50K Beast', Icons.emoji_events_rounded, Colors.amber,
            user.totalKm >= 50),
        _Badge('Marathon', Icons.flag_rounded, Colors.deepPurple,
            user.totalKm >= 42),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: _SectionLabel('ACHIEVEMENTS'),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _badges.length,
            itemBuilder: (context, i) => _BadgeTile(badge: _badges[i]),
          ),
        ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final _Badge badge;
  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badge.unlocked
                  ? badge.color.withOpacity(0.12)
                  : FortRunTheme.cardDark,
              border: Border.all(
                color: badge.unlocked
                    ? badge.color.withOpacity(0.55)
                    : FortRunTheme.cardDarkBorder,
                width: badge.unlocked ? 2 : 1,
              ),
              boxShadow: badge.unlocked
                  ? [
                      BoxShadow(
                        color: badge.color.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              badge.icon,
              color: badge.unlocked ? badge.color : FortRunTheme.cardDarkBorder,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            badge.label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              color: badge.unlocked ? Colors.white : FortRunTheme.textMuted,
              fontWeight: badge.unlocked ? FontWeight.w600 : FontWeight.w400,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _Badge {
  final String label;
  final IconData icon;
  final Color color;
  final bool unlocked;
  const _Badge(this.label, this.icon, this.color, this.unlocked);
}

// ── Run tile ──────────────────────────────────────────────────

class _RunTile extends StatelessWidget {
  final RunModel run;
  const _RunTile({required this.run});

  String get _pace {
    if (run.distanceKm <= 0) return '--:--';
    final totalMins = run.durationSeconds / 60;
    final paceMin = totalMins / run.distanceKm;
    final min = paceMin.floor();
    final sec = ((paceMin - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  String get _time {
    final h = run.durationSeconds ~/ 3600;
    final m = (run.durationSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FortRunTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FortRunTheme.cardDarkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FortRunTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: FortRunTheme.primaryGreen.withOpacity(0.2)),
            ),
            child: const Icon(Icons.directions_run_rounded,
                color: FortRunTheme.primaryGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.primarySector.isNotEmpty
                      ? 'Sector ${run.primarySector}'
                      : 'Run',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _RunChip('${run.distanceKm.toStringAsFixed(2)} km',
                        FortRunTheme.primaryGreen),
                    const SizedBox(width: 6),
                    _RunChip(_time, FortRunTheme.textMuted),
                    const SizedBox(width: 6),
                    _RunChip('$_pace /km', FortRunTheme.safeBlue),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${run.pointsEarned}',
                style: GoogleFonts.outfit(
                  color: FortRunTheme.starGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text('pts',
                  style: const TextStyle(
                      color: FortRunTheme.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RunChip extends StatelessWidget {
  final String text;
  final Color color;
  const _RunChip(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w500));
  }
}

// ── Empty runs ────────────────────────────────────────────────

class _EmptyRuns extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: FortRunTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FortRunTheme.cardDarkBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: FortRunTheme.primaryGreen.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                  color: FortRunTheme.primaryGreen.withOpacity(0.2)),
            ),
            child: const Icon(Icons.directions_run_rounded,
                color: FortRunTheme.primaryGreen, size: 28),
          ),
          const SizedBox(height: 14),
          Text('No runs yet',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 6),
          const Text(
            'Hit GO on the map to start\nyour first territory run.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: FortRunTheme.textMuted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        color: FortRunTheme.textMuted,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 1.5,
      ),
    );
  }
}
