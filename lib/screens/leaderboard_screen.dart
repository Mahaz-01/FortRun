import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../utils/theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FortRunTheme.scaffoldDark,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24,
              right: 24,
              bottom: 16,
            ),
            decoration: const BoxDecoration(
              color: FortRunTheme.cardDark,
              border: Border(
                bottom: BorderSide(color: FortRunTheme.cardDarkBorder),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.leaderboard,
                        color: FortRunTheme.primaryGreen, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'LEADERBOARD',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Islamabad',
                      style: GoogleFonts.outfit(
                        color: FortRunTheme.primaryGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: FortRunTheme.cardDarkAlt,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: FortRunTheme.cardDarkBorder),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: FortRunTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: FortRunTheme.textMuted,
                    labelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle:
                        GoogleFonts.outfit(fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'RUNNERS'),
                      Tab(text: 'TERRITORIES'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Views ────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _RunnersTab(),
                _TerritoriesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Runners Tab ───────────────────────────────────────────────

class _RunnersTab extends StatefulWidget {
  const _RunnersTab();

  @override
  State<_RunnersTab> createState() => _RunnersTabState();
}

class _RunnersTabState extends State<_RunnersTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<DatabaseService>().getTopRunners();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: FortRunTheme.primaryGreen),
          );
        }

        final runners = snapshot.data ?? [];
        if (runners.isEmpty) {
          return _empty('No runners yet. Be the first!');
        }

        return RefreshIndicator(
          color: FortRunTheme.primaryGreen,
          backgroundColor: FortRunTheme.cardDark,
          onRefresh: () async {
            setState(() {
              _future =
                  context.read<DatabaseService>().getTopRunners();
            });
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Podium for top 3
              if (runners.length >= 3)
                SliverToBoxAdapter(
                  child: _Podium(runners: runners.take(3).toList()),
                ),
              // Rest of the list
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final startIdx = runners.length >= 3 ? 3 : 0;
                      final idx = startIdx + i;
                      if (idx >= runners.length) return null;
                      return _RunnerRow(
                          runner: runners[idx], rank: idx + 1);
                    },
                    childCount: runners.length >= 3
                        ? runners.length - 3
                        : runners.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> runners;
  const _Podium({required this.runners});

  @override
  Widget build(BuildContext context) {
    final colors = [
      FortRunTheme.starGold,
      FortRunTheme.textSecondary,
      const Color(0xFFCD7F32), // bronze
    ];
    final heights = [110.0, 80.0, 60.0];
    final order = [1, 0, 2]; // display: 2nd, 1st, 3rd

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: order.map((i) {
          final runner = runners[i];
          final name = runner['name'] ?? 'Runner';
          final pts = runner['points'] ?? 0;
          final isFirst = i == 0;

          return Expanded(
            child: Column(
              children: [
                // Crown for #1
                if (isFirst)
                  const Icon(Icons.emoji_events,
                      color: FortRunTheme.starGold, size: 28),
                const SizedBox(height: 4),
                // Avatar
                Container(
                  width: isFirst ? 56 : 46,
                  height: isFirst ? 56 : 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colors[i].withOpacity(0.3),
                        colors[i].withOpacity(0.1),
                      ],
                    ),
                    border: Border.all(color: colors[i], width: 2),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'R',
                      style: GoogleFonts.outfit(
                        color: colors[i],
                        fontWeight: FontWeight.w800,
                        fontSize: isFirst ? 22 : 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name.split(' ').first,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$pts pts',
                  style: GoogleFonts.outfit(
                    color: colors[i],
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                // Podium block
                Container(
                  height: heights[i],
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors[i].withOpacity(0.3),
                        colors[i].withOpacity(0.1),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8)),
                    border: Border.all(
                      color: colors[i].withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '#${i + 1}',
                      style: GoogleFonts.outfit(
                        color: colors[i],
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RunnerRow extends StatelessWidget {
  final Map<String, dynamic> runner;
  final int rank;
  const _RunnerRow({required this.runner, required this.rank});

  @override
  Widget build(BuildContext context) {
    final name = runner['name'] ?? 'Runner';
    final pts = runner['points'] ?? 0;
    final km = (runner['total_km'] ?? 0.0).toDouble();
    final streak = runner['streak_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FortRunTheme.cardDarkAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FortRunTheme.cardDarkBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: GoogleFonts.outfit(
                color: FortRunTheme.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FortRunTheme.cardDark,
              border: Border.all(color: FortRunTheme.cardDarkBorder),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'R',
                style: GoogleFonts.outfit(
                  color: FortRunTheme.primaryGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (streak > 0) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.local_fire_department,
                          color: FortRunTheme.starGold, size: 12),
                      Text(
                        '$streak',
                        style: const TextStyle(
                            color: FortRunTheme.starGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${km.toStringAsFixed(1)} km',
                  style: const TextStyle(
                      color: FortRunTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '$pts',
            style: GoogleFonts.outfit(
              color: FortRunTheme.starGold,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'pts',
            style: TextStyle(
                color: FortRunTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Territories Tab ───────────────────────────────────────────

class _TerritoriesTab extends StatefulWidget {
  const _TerritoriesTab();

  @override
  State<_TerritoriesTab> createState() => _TerritoriesTabState();
}

class _TerritoriesTabState extends State<_TerritoriesTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<DatabaseService>().getTopZones();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: FortRunTheme.primaryGreen),
          );
        }

        final zones = snapshot.data ?? [];
        if (zones.isEmpty) {
          return _empty('No territories claimed yet. Start running!');
        }

        return RefreshIndicator(
          color: FortRunTheme.primaryGreen,
          backgroundColor: FortRunTheme.cardDark,
          onRefresh: () async {
            setState(() {
              _future =
                  context.read<DatabaseService>().getTopZones();
            });
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: zones.length,
            itemBuilder: (context, index) {
              final zone = zones[index];
              final name = zone['name'] ?? zone['id'] ?? '';
              final totalPoints = zone['total_points'] ?? 0;
              final controlPct =
                  (zone['control_percentage'] ?? 0.0).toDouble();
              final ownerName = zone['owner_name'] ?? 'Unclaimed';
              final isUnclaimed = ownerName == 'Unclaimed';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FortRunTheme.cardDarkAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: index == 0
                        ? FortRunTheme.primaryGreen.withOpacity(0.3)
                        : FortRunTheme.cardDarkBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isUnclaimed
                            ? FortRunTheme.cardDark
                            : FortRunTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isUnclaimed
                              ? FortRunTheme.cardDarkBorder
                              : FortRunTheme.primaryGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.outfit(
                            color: isUnclaimed
                                ? FortRunTheme.textMuted
                                : FortRunTheme.primaryGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
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
                            name,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isUnclaimed
                                ? 'Unclaimed — run here!'
                                : 'Owner: $ownerName',
                            style: const TextStyle(
                              color: FortRunTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: controlPct / 100,
                              minHeight: 3,
                              backgroundColor: FortRunTheme.cardDark,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isUnclaimed
                                    ? FortRunTheme.textMuted
                                    : FortRunTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$totalPoints',
                          style: GoogleFonts.outfit(
                            color: FortRunTheme.starGold,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const Text('pts',
                            style: TextStyle(
                                color: FortRunTheme.textMuted,
                                fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

Widget _empty(String message) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.sentiment_neutral,
            color: FortRunTheme.textMuted, size: 48),
        const SizedBox(height: 12),
        Text(message,
            style: const TextStyle(color: FortRunTheme.textMuted)),
      ],
    ),
  );
}
