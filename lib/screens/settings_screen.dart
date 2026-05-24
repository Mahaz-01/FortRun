import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';
import '../utils/tappable.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _useMiles = false;
  bool _notifications = true;
  String _selectedCityId = 'islamabad';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _useMiles = prefs.getBool('use_miles') ?? false;
        _notifications = prefs.getBool('notifications') ?? true;
        _selectedCityId = prefs.getString('selected_city') ?? 'islamabad';
      });
    }
  }

  Future<void> _savePref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CityPickerSheet(
        selectedId: _selectedCityId,
        onSelect: (cityId) {
          setState(() => _selectedCityId = cityId);
          _savePref('selected_city', cityId);
        },
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FortRunTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will be logged out. Your territory and progress are safe.',
          style: TextStyle(color: FortRunTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: FortRunTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthService>().signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: FortRunTheme.enemyRed),
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
  }

  FortCity get _selectedCity => AppConstants.cityById(_selectedCityId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FortRunTheme.scaffoldDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: FortRunTheme.scaffoldDark,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
              color: Colors.white,
            ),
            title: Text(
              'Settings',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: FortRunTheme.cardDarkBorder),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── City ────────────────────────────────────────
                _SectionHeader('YOUR CITY'),
                const SizedBox(height: 10),
                Tappable(
                  onTap: _showCityPicker,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FortRunTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: FortRunTheme.primaryGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: FortRunTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: FortRunTheme.primaryGreen.withOpacity(0.25)),
                          ),
                          child: Center(
                            child: Text(_selectedCity.emoji,
                                style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedCity.name,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                _selectedCity.country,
                                style: const TextStyle(
                                    color: FortRunTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: FortRunTheme.textMuted),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Preferences ──────────────────────────────────
                _SectionHeader('PREFERENCES'),
                const SizedBox(height: 10),

                _ToggleTile(
                  icon: Icons.straighten_rounded,
                  title: 'Use Miles',
                  subtitle: _useMiles
                      ? 'Distances shown in miles'
                      : 'Distances shown in kilometers',
                  value: _useMiles,
                  onChanged: (v) {
                    setState(() => _useMiles = v);
                    _savePref('use_miles', v);
                  },
                ),
                const SizedBox(height: 8),
                _ToggleTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Territory alerts and streak reminders',
                  value: _notifications,
                  onChanged: (v) {
                    setState(() => _notifications = v);
                    _savePref('notifications', v);
                  },
                ),

                const SizedBox(height: 24),

                // ── FortRun Pro ──────────────────────────────────
                _SectionHeader('FORTRUN PRO'),
                const SizedBox(height: 10),
                _ProBanner(),

                const SizedBox(height: 24),

                // ── Account ──────────────────────────────────────
                _SectionHeader('ACCOUNT'),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.shield_outlined,
                  title: 'Privacy Policy',
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  iconColor: FortRunTheme.enemyRed,
                  titleColor: FortRunTheme.enemyRed,
                  onTap: _confirmSignOut,
                ),

                const SizedBox(height: 32),

                Center(
                  child: Column(
                    children: [
                      Text(
                        'FortRun v1.0.0',
                        style: GoogleFonts.outfit(
                          color: FortRunTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Made in Pakistan 🇵🇰',
                        style: GoogleFonts.outfit(
                          color: FortRunTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── City picker sheet ─────────────────────────────────────────

class _CityPickerSheet extends StatelessWidget {
  final String selectedId;
  final void Function(String) onSelect;

  const _CityPickerSheet({
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: FortRunTheme.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: FortRunTheme.cardDarkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Select Your City',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 6),
          const Text('FortRun centers your map and\nfinds nearby spots based on this.',
              style: TextStyle(color: FortRunTheme.textMuted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
          ...AppConstants.cities.map((city) {
            final isSelected = city.id == selectedId;
            return Tappable(
              onTap: city.comingSoon ? null : () {
                onSelect(city.id);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FortRunTheme.primaryGreen.withOpacity(0.08)
                      : FortRunTheme.cardDarkAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? FortRunTheme.primaryGreen.withOpacity(0.4)
                        : FortRunTheme.cardDarkBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Text(city.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(city.name,
                                  style: GoogleFonts.outfit(
                                    color: city.comingSoon
                                        ? FortRunTheme.textMuted
                                        : Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  )),
                              if (city.comingSoon) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: FortRunTheme.warningOrange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: FortRunTheme.warningOrange.withOpacity(0.3)),
                                  ),
                                  child: Text('SOON',
                                      style: GoogleFonts.outfit(
                                        color: FortRunTheme.warningOrange,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      )),
                                ),
                              ],
                            ],
                          ),
                          Text(city.description,
                              style: const TextStyle(
                                  color: FortRunTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: FortRunTheme.primaryGreen, size: 22)
                    else
                      const Icon(Icons.radio_button_unchecked_rounded,
                          color: FortRunTheme.cardDarkBorder, size: 22),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Pro banner ────────────────────────────────────────────────

class _ProBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A0A), Color(0xFF0A1500)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FortRunTheme.starGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: FortRunTheme.goldGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PRO',
                  style: GoogleFonts.outfit(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('FortRun Pro',
                  style: GoogleFonts.outfit(
                    color: FortRunTheme.starGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          _ProFeature(Icons.bolt_rounded, 'Unlimited sabotage per day'),
          _ProFeature(Icons.palette_outlined, 'Custom territory colors & themes'),
          _ProFeature(Icons.bar_chart_rounded, 'Advanced stats & training analytics'),
          _ProFeature(Icons.group_add_rounded, 'Create clans (free users can only join)'),
          _ProFeature(Icons.star_rounded, 'PRO badge on leaderboard'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: FortRunTheme.starGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Coming Soon — PKR 500/month',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProFeature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProFeature(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: FortRunTheme.starGold, size: 16),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: FortRunTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

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

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FortRunTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FortRunTheme.cardDarkBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: FortRunTheme.primaryGreen, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    )),
                Text(subtitle,
                    style: const TextStyle(
                        color: FortRunTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: FortRunTheme.primaryGreen,
            activeColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: FortRunTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FortRunTheme.cardDarkBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? FortRunTheme.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  color: titleColor ?? Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: FortRunTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
