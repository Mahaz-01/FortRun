import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_map_screen.dart';
import 'challenges_screen.dart';
import 'leaderboard_screen.dart';
import 'clan_screen.dart';
import 'profile_screen.dart';
import '../utils/theme.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    HomeMapScreen(),
    ChallengesScreen(),
    LeaderboardScreen(),
    ClanScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(
          top: BorderSide(color: FortRunTheme.cardDarkBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Map',
                index: 0,
                current: currentIndex,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.emoji_events_outlined,
                activeIcon: Icons.emoji_events_rounded,
                label: 'Challenges',
                index: 1,
                current: currentIndex,
                onTap: () => onTap(1),
                accentColor: FortRunTheme.starGold,
              ),
              _NavItem(
                icon: Icons.leaderboard_outlined,
                activeIcon: Icons.leaderboard_rounded,
                label: 'Ranks',
                index: 2,
                current: currentIndex,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.shield_outlined,
                activeIcon: Icons.shield_rounded,
                label: 'Clan',
                index: 3,
                current: currentIndex,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                index: 4,
                current: currentIndex,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final VoidCallback onTap;
  final Color? accentColor;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    final color = accentColor ?? FortRunTheme.primaryGreen;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? color.withOpacity(0.13) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? color : FortRunTheme.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: isActive ? color : FortRunTheme.textMuted,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w400,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
