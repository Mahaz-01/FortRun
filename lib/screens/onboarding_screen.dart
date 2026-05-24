import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';
import '../utils/tappable.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _page = 0;

  late final AnimationController _iconCtrl;
  late final Animation<double> _iconScale;

  static const _pages = [
    _OnboardPage(
      icon: Icons.map_rounded,
      color: FortRunTheme.primaryGreen,
      title: 'Own\nYour City',
      subtitle:
          'Run through the streets of your city to claim territory. Every kilometer earns you walls, sectors, and points.',
      detail: 'No gym. No treadmill. Just run outside.',
    ),
    _OnboardPage(
      icon: Icons.local_fire_department_rounded,
      color: FortRunTheme.enemyRed,
      title: 'Battle &\nSabotage',
      subtitle:
          'Rival runners can invade your territory. Counter-attack by sabotaging at local restaurants near their zones.',
      detail: 'Team up with clans to control entire districts.',
    ),
    _OnboardPage(
      icon: Icons.emoji_events_rounded,
      color: FortRunTheme.starGold,
      title: 'Rise to\nthe Top',
      subtitle:
          'Complete weekly challenges, build streaks, and climb the leaderboard. The most active runner rules the map.',
      detail: 'Streaks give up to 2× XP multiplier.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    _iconCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    return Scaffold(
      backgroundColor: FortRunTheme.scaffoldDark,
      body: Stack(
        children: [
          // Gradient background shifts color per page
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  page.color.withOpacity(0.08),
                  FortRunTheme.scaffoldDark,
                  FortRunTheme.scaffoldDark,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Skip button ──────────────────────────────
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.outfit(
                        color: FortRunTheme.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // ── Pages ────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) {
                      setState(() => _page = i);
                      _iconCtrl.forward(from: 0);
                    },
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _PageContent(
                      page: _pages[i],
                      iconScale: _iconScale,
                      isActive: i == _page,
                    ),
                  ),
                ),

                // ── Dots + button ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                  child: Column(
                    children: [
                      // Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final isActive = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _pages[_page].color
                                  : FortRunTheme.cardDarkBorder,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 28),

                      // Next / Get Started
                      Tappable(
                        onTap: _next,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [page.color, page.color.withOpacity(0.7)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: page.color.withOpacity(0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _page < _pages.length - 1
                                  ? 'Next'
                                  : 'Start Running',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _PageContent extends StatelessWidget {
  final _OnboardPage page;
  final Animation<double> iconScale;
  final bool isActive;

  const _PageContent({
    required this.page,
    required this.iconScale,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          AnimatedBuilder(
            animation: iconScale,
            builder: (_, __) => Transform.scale(
              scale: iconScale.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: page.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: page.color.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: page.color.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(page.icon, color: page.color, size: 48),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            style: GoogleFonts.outfit(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 20),

          // Subtitle
          Text(
            page.subtitle,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: FortRunTheme.textSecondary,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),

          // Detail chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: page.color.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded, color: page.color, size: 14),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    page.detail,
                    style: TextStyle(
                      color: page.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
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

class _OnboardPage {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String detail;

  const _OnboardPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.detail,
  });
}
