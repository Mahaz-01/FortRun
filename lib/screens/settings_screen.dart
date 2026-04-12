import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';

/// ============================================================
/// SettingsScreen — App preferences and account actions.
/// ============================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _useMiles = false;
  bool _notifications = true;

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
      });
    }
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FortRunTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will be logged out of FortRun. Your data is safe.',
          style: TextStyle(color: FortRunTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: FortRunTheme.textMuted)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // ── Preferences Section ──────────────────────
              const Text(
                'PREFERENCES',
                style: TextStyle(
                  color: FortRunTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),

              _settingTile(
                icon: Icons.straighten,
                title: 'Use Miles',
                subtitle: _useMiles ? 'Distances shown in miles' : 'Distances shown in kilometers',
                trailing: Switch(
                  value: _useMiles,
                  activeTrackColor: FortRunTheme.primaryGreen,
                  onChanged: (val) {
                    setState(() => _useMiles = val);
                    _savePref('use_miles', val);
                  },
                ),
              ),

              _settingTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Territory alerts and streak reminders',
                trailing: Switch(
                  value: _notifications,
                  activeTrackColor: FortRunTheme.primaryGreen,
                  onChanged: (val) {
                    setState(() => _notifications = val);
                    _savePref('notifications', val);
                  },
                ),
              ),

              const SizedBox(height: 30),

              // ── Account Section ──────────────────────────
              const Text(
                'ACCOUNT',
                style: TextStyle(
                  color: FortRunTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),

              _settingTile(
                icon: Icons.logout,
                title: 'Sign Out',
                subtitle: 'Log out of your account',
                iconColor: FortRunTheme.enemyRed,
                onTap: _confirmSignOut,
              ),

              const SizedBox(height: 30),

              // ── About Section ───────────────────────────
              const Text(
                'ABOUT',
                style: TextStyle(
                  color: FortRunTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),

              _settingTile(
                icon: Icons.info_outline,
                title: 'FortRun',
                subtitle: 'Version 1.0.0',
              ),

              const SizedBox(height: 10),

              Center(
                child: Text(
                  'Made for runners in Islamabad',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(76),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FortRunTheme.cardDarkAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? FortRunTheme.primaryGreen, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: FortRunTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
