import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import '../utils/theme.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.id;
    final dbService = context.read<DatabaseService>();

    return Scaffold(
      backgroundColor: FortRunTheme.scaffoldDark,
      body: uid == null
          ? const Center(child: Text('Not logged in',
              style: TextStyle(color: Colors.white)))
          : StreamBuilder<UserModel?>(
              stream: dbService.streamUser(uid),
              builder: (context, userSnap) {
                final user = userSnap.data;
                return StreamBuilder<List<RunModel>>(
                  stream: dbService.streamUserRuns(uid),
                  builder: (context, runSnap) {
                    final runs = runSnap.data ?? [];
                    return CustomScrollView(
                      slivers: [
                        _AppBar(),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              if (user != null)
                                _XPProgressBar(user: user),
                              const SizedBox(height: 20),
                              _SectionLabel('DAILY CHALLENGES'),
                              const SizedBox(height: 10),
                              ..._dailyChallenges(runs, user).map(
                                  (c) => _ChallengeCard(challenge: c)),
                              const SizedBox(height: 20),
                              _SectionLabel('WEEKLY CHALLENGES'),
                              const SizedBox(height: 10),
                              ..._weeklyChallenges(runs, user).map(
                                  (c) => _ChallengeCard(challenge: c)),
                              const SizedBox(height: 20),
                              _SectionLabel('MILESTONE CHALLENGES'),
                              const SizedBox(height: 10),
                              ..._milestoneChallenges(user).map(
                                  (c) => _ChallengeCard(challenge: c)),
                              const SizedBox(height: 20),
                              _PakistanChallenges(),
                            ]),
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

  List<_Challenge> _dailyChallenges(List<RunModel> runs, UserModel? user) {
    final today = DateTime.now();
    final todayRuns = runs.where((r) {
      final d = r.timestamp;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).toList();

    final todayKm = todayRuns.fold(0.0, (s, r) => s + r.distanceKm);
    final todayRan = todayRuns.isNotEmpty;

    return [
      _Challenge(
        title: 'First Run of the Day',
        description: 'Complete at least one run today',
        icon: Icons.directions_run_rounded,
        color: FortRunTheme.primaryGreen,
        current: todayRan ? 1 : 0,
        target: 1,
        unit: 'run',
        reward: '+50 XP',
        type: ChallengeType.daily,
      ),
      _Challenge(
        title: 'Hit 3km Today',
        description: 'Run a total of 3km within today',
        icon: Icons.straighten_rounded,
        color: FortRunTheme.safeBlue,
        current: todayKm,
        target: 3.0,
        unit: 'km',
        reward: '+80 XP',
        type: ChallengeType.daily,
      ),
      _Challenge(
        title: 'Claim a New Wall',
        description: 'Run and capture at least one new territory wall',
        icon: Icons.grid_view_rounded,
        color: FortRunTheme.warningOrange,
        current: (user?.totalRuns ?? 0) > 0 ? 1 : 0,
        target: 1,
        unit: 'wall',
        reward: '+30 XP',
        type: ChallengeType.daily,
      ),
    ];
  }

  List<_Challenge> _weeklyChallenges(List<RunModel> runs, UserModel? user) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekRuns = runs.where((r) =>
        r.timestamp.isAfter(DateTime(weekStart.year, weekStart.month, weekStart.day))).toList();

    final weekKm = weekRuns.fold(0.0, (s, r) => s + r.distanceKm);
    final weekDays = weekRuns.map((r) {
      final d = r.timestamp;
      return '${d.year}-${d.month}-${d.day}';
    }).toSet().length;

    return [
      _Challenge(
        title: '20km Week',
        description: 'Run 20 kilometers total this week',
        icon: Icons.emoji_events_rounded,
        color: FortRunTheme.starGold,
        current: weekKm,
        target: 20.0,
        unit: 'km',
        reward: '+200 XP + Badge',
        type: ChallengeType.weekly,
      ),
      _Challenge(
        title: '5-Day Streak',
        description: 'Run on 5 different days this week',
        icon: Icons.local_fire_department_rounded,
        color: FortRunTheme.enemyRed,
        current: weekDays.toDouble(),
        target: 5,
        unit: 'days',
        reward: '+150 XP + 1.5× multiplier',
        type: ChallengeType.weekly,
      ),
      _Challenge(
        title: 'Territory Expansion',
        description: 'Run in 3 different sectors this week',
        icon: Icons.map_rounded,
        color: FortRunTheme.primaryGreen,
        current: weekRuns.map((r) => r.primarySector).toSet().length.toDouble(),
        target: 3,
        unit: 'sectors',
        reward: '+120 XP',
        type: ChallengeType.weekly,
      ),
    ];
  }

  List<_Challenge> _milestoneChallenges(UserModel? user) {
    final km = user?.totalKm ?? 0.0;
    final runs = user?.totalRuns ?? 0;
    final pts = user?.points ?? 0;

    return [
      _Challenge(
        title: '5K Club',
        description: 'Run a total of 5 kilometers across all time',
        icon: Icons.directions_run_rounded,
        color: FortRunTheme.primaryGreen,
        current: km.clamp(0, 5),
        target: 5,
        unit: 'km',
        reward: '🥇 5K Badge',
        type: ChallengeType.milestone,
      ),
      _Challenge(
        title: 'First 10 Runs',
        description: 'Complete 10 runs in FortRun',
        icon: Icons.repeat_rounded,
        color: FortRunTheme.safeBlue,
        current: runs.clamp(0, 10).toDouble(),
        target: 10,
        unit: 'runs',
        reward: '🏃 Veteran Badge',
        type: ChallengeType.milestone,
      ),
      _Challenge(
        title: '100 Points',
        description: 'Earn 100 territory points total',
        icon: Icons.stars_rounded,
        color: FortRunTheme.starGold,
        current: pts.clamp(0, 100).toDouble(),
        target: 100,
        unit: 'pts',
        reward: '⭐ Century Badge',
        type: ChallengeType.milestone,
      ),
      _Challenge(
        title: 'Marathon Legend',
        description: 'Run a total of 42km across all sessions',
        icon: Icons.military_tech_rounded,
        color: Colors.deepPurple,
        current: km.clamp(0, 42),
        target: 42,
        unit: 'km',
        reward: '🏅 Marathon Legend Badge',
        type: ChallengeType.milestone,
      ),
    ];
  }
}

// ── App bar ───────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: FortRunTheme.scaffoldDark,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: Text(
        'Challenges',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: FortRunTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FortRunTheme.primaryGreen.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.refresh_rounded,
                    color: FortRunTheme.primaryGreen, size: 14),
                const SizedBox(width: 4),
                Text('Daily',
                    style: GoogleFonts.outfit(
                      color: FortRunTheme.primaryGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: FortRunTheme.cardDarkBorder),
      ),
    );
  }
}

// ── XP progress bar ───────────────────────────────────────────

class _XPProgressBar extends StatelessWidget {
  final UserModel user;
  const _XPProgressBar({required this.user});

  int get _level => (user.points / 100).floor() + 1;
  int get _xpInLevel => user.points % 100;
  int get _xpToNext => 100;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1A0A), Color(0xFF080F08)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FortRunTheme.primaryGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FortRunTheme.primaryGreen.withOpacity(0.12),
                  border: Border.all(
                      color: FortRunTheme.primaryGreen.withOpacity(0.4),
                      width: 2),
                ),
                child: Center(
                  child: Text(
                    '$_level',
                    style: GoogleFonts.outfit(
                      color: FortRunTheme.primaryGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _levelTitle(_level),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('Level $_level · ${user.points} total XP',
                        style: const TextStyle(
                            color: FortRunTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                '$_xpInLevel / $_xpToNext XP',
                style: GoogleFonts.outfit(
                  color: FortRunTheme.primaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _xpInLevel / _xpToNext,
              minHeight: 8,
              backgroundColor: FortRunTheme.cardDarkBorder,
              valueColor:
                  const AlwaysStoppedAnimation(FortRunTheme.primaryGreen),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_xpToNext - _xpInLevel} XP to Level ${_level + 1}',
            style: const TextStyle(color: FortRunTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _levelTitle(int level) {
    if (level <= 1) return 'Recruit';
    if (level <= 3) return 'Street Runner';
    if (level <= 6) return 'Territory Seeker';
    if (level <= 10) return 'Fort Commander';
    if (level <= 15) return 'City Warlord';
    return 'Legend';
  }
}

// ── Challenge card ────────────────────────────────────────────

class _ChallengeCard extends StatelessWidget {
  final _Challenge challenge;
  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final pct = (challenge.current / challenge.target).clamp(0.0, 1.0);
    final done = pct >= 1.0;
    final color = done ? FortRunTheme.primaryGreen : challenge.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FortRunTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: done
              ? FortRunTheme.primaryGreen.withOpacity(0.4)
              : FortRunTheme.cardDarkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Icon(
                  done ? Icons.check_rounded : challenge.icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Title + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            challenge.title,
                            style: GoogleFonts.outfit(
                              color: done
                                  ? FortRunTheme.primaryGreen
                                  : Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        _TypeBadge(type: challenge.type),
                      ],
                    ),
                    Text(
                      challenge.description,
                      style: const TextStyle(
                          color: FortRunTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 7,
                        backgroundColor: FortRunTheme.cardDarkBorder,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      done
                          ? 'Completed!'
                          : '${_fmt(challenge.current)} / ${_fmt(challenge.target)} ${challenge.unit}',
                      style: TextStyle(
                          color: done
                              ? FortRunTheme.primaryGreen
                              : FortRunTheme.textMuted,
                          fontSize: 11,
                          fontWeight:
                              done ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(done ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Text(
                  challenge.reward,
                  style: GoogleFonts.outfit(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

class _TypeBadge extends StatelessWidget {
  final ChallengeType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final label = type == ChallengeType.daily
        ? 'DAILY'
        : type == ChallengeType.weekly
            ? 'WEEKLY'
            : 'MILESTONE';
    final color = type == ChallengeType.daily
        ? FortRunTheme.primaryGreen
        : type == ChallengeType.weekly
            ? FortRunTheme.safeBlue
            : FortRunTheme.starGold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          )),
    );
  }
}

// ── Pakistan special challenges ───────────────────────────────

class _PakistanChallenges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF01411C).withOpacity(0.3),
            FortRunTheme.scaffoldDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF01411C).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🇵🇰', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                'Pakistan Day Challenge',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Run 23km on March 23rd to celebrate Pakistan Day. '
            'Complete this to unlock the exclusive Pakistan Day badge.',
            style: const TextStyle(
                color: FortRunTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SpecialChip(Icons.calendar_today_rounded, 'Mar 23'),
              const SizedBox(width: 8),
              _SpecialChip(Icons.straighten_rounded, '23 km'),
              const SizedBox(width: 8),
              _SpecialChip(Icons.military_tech_rounded, 'Exclusive Badge'),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: FortRunTheme.textMuted, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'More seasonal challenges (Eid, Independence Day) coming soon!',
                    style: TextStyle(
                        color: FortRunTheme.textMuted, fontSize: 12),
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

class _SpecialChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SpecialChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF01411C).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFF01411C).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.greenAccent, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────

enum ChallengeType { daily, weekly, milestone }

class _Challenge {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final double current;
  final double target;
  final String unit;
  final String reward;
  final ChallengeType type;

  const _Challenge({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.current,
    required this.target,
    required this.unit,
    required this.reward,
    required this.type,
  });
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        color: FortRunTheme.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}
