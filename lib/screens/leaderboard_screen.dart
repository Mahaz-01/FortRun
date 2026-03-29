import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_engine.dart';
import '../utils/theme.dart';

/// ============================================================
/// LeaderboardScreen — Top runners and top territories.
/// ============================================================

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
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── Header ──────────────────────────────────
              const Text(
                '🏆 LEADERBOARD',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Islamabad Rankings',
                style: TextStyle(
                  fontSize: 13,
                  color: FortRunTheme.primaryGreen.withOpacity(0.7),
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 20),

              // ── Tab Bar ─────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: FortRunTheme.cardDarkAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: FortRunTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: FortRunTheme.textMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '🏃 RUNNERS'),
                    Tab(text: '🗺️ TERRITORIES'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Tab Views ───────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _RunnersTab(),
                    _TerritoriesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Runners Leaderboard Tab ────────────────────────────────────

class _RunnersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gameEngine = context.read<GameEngine>();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: gameEngine.getTopRunners(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: FortRunTheme.primaryGreen),
          );
        }

        final runners = snapshot.data ?? [];
        if (runners.isEmpty) {
          return const Center(
            child: Text(
              'No runners yet. Be the first!',
              style: TextStyle(color: FortRunTheme.textMuted),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: runners.length,
          itemBuilder: (context, index) {
            final runner = runners[index];
            final rank = index + 1;
            final name = runner['name'] ?? 'Unknown';
            final points = runner['points'] ?? 0;
            final km = (runner['total_km'] ?? 0.0).toDouble();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: rank <= 3
                    ? LinearGradient(
                        colors: [
                          FortRunTheme.cardDarkAlt,
                          rank == 1
                              ? FortRunTheme.starGold.withOpacity(0.08)
                              : rank == 2
                                  ? Colors.grey.withOpacity(0.08)
                                  : Colors.brown.withOpacity(0.08),
                        ],
                      )
                    : FortRunTheme.cardGradient,
                borderRadius: BorderRadius.circular(14),
                border: rank <= 3
                    ? Border.all(
                        color: rank == 1
                            ? FortRunTheme.starGold.withOpacity(0.3)
                            : rank == 2
                                ? Colors.grey.withOpacity(0.3)
                                : Colors.brown.withOpacity(0.3),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rank == 1
                          ? FortRunTheme.starGold
                          : rank == 2
                              ? Colors.grey
                              : rank == 3
                                  ? Colors.brown
                                  : FortRunTheme.cardDark,
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          color: rank <= 3 ? Colors.white : FortRunTheme.textMuted,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${km.toStringAsFixed(1)} km run',
                          style: const TextStyle(
                            color: FortRunTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$points ⭐',
                    style: const TextStyle(
                      color: FortRunTheme.starGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Territories Leaderboard Tab ────────────────────────────────

class _TerritoriesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gameEngine = context.read<GameEngine>();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: gameEngine.getTopZones(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: FortRunTheme.primaryGreen),
          );
        }

        final zones = snapshot.data ?? [];
        if (zones.isEmpty) {
          return const Center(
            child: Text(
              'No territories claimed yet. Start running!',
              style: TextStyle(color: FortRunTheme.textMuted),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: zones.length,
          itemBuilder: (context, index) {
            final zone = zones[index];
            final sectorId = zone['id'] ?? '';
            final name = zone['name'] ?? sectorId;
            final totalPoints = zone['total_points'] ?? 0;
            final controlPct = (zone['control_percentage'] ?? 0.0).toDouble();
            final ownerId = zone['owner_id'] ?? 'None';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: FortRunTheme.cardGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FortRunTheme.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.flag, color: FortRunTheme.primaryGreen, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Control: ${controlPct.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: FortRunTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        // Progress bar
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: controlPct / 100,
                            minHeight: 4,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              FortRunTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$totalPoints',
                        style: const TextStyle(
                          color: FortRunTheme.starGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'pts',
                        style: TextStyle(color: FortRunTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
