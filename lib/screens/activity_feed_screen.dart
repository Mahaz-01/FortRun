import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../utils/theme.dart';

/// ============================================================
/// ActivityFeedScreen — Live feed of game events across all players.
/// ============================================================

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  StreamSubscription? _subscription;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToFeed();
  }

  void _listenToFeed() {
    final dbService = context.read<DatabaseService>();
    _subscription = dbService.streamActivityFeed(limit: 100).listen((items) {
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  IconData _iconForAction(String action) {
    switch (action) {
      case 'run_complete':
        return Icons.directions_run;
      case 'zone_captured':
        return Icons.flag;
      case 'sabotage':
        return Icons.local_fire_department;
      case 'clan_join':
        return Icons.group_add;
      case 'clan_leave':
        return Icons.group_remove;
      case 'streak':
        return Icons.local_fire_department;
      default:
        return Icons.info;
    }
  }

  Color _colorForAction(String action) {
    switch (action) {
      case 'run_complete':
        return FortRunTheme.primaryGreen;
      case 'zone_captured':
        return FortRunTheme.starGold;
      case 'sabotage':
        return FortRunTheme.enemyRed;
      case 'clan_join':
        return FortRunTheme.safeBlue;
      case 'clan_leave':
        return FortRunTheme.warningOrange;
      case 'streak':
        return FortRunTheme.starGold;
      default:
        return FortRunTheme.textMuted;
    }
  }

  String _descriptionForItem(Map<String, dynamic> item) {
    final actor = item['actor_name'] ?? 'Runner';
    final action = item['action'] ?? '';
    final target = item['target_name'] ?? '';
    final detail = item['detail'] ?? '';

    switch (action) {
      case 'run_complete':
        return '$actor completed a run in $target. $detail';
      case 'zone_captured':
        return '$actor captured Sector $target! $detail';
      case 'sabotage':
        return '$actor sabotaged Sector $target! $detail';
      case 'clan_join':
        return '$actor joined clan $target';
      case 'clan_leave':
        return '$actor left clan $target';
      case 'streak':
        return '$actor hit a $detail';
      default:
        return '$actor performed $action. $detail';
    }
  }

  String _timeAgo(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.tryParse(timestamp);
    if (dt == null) return '';

    final diff = DateTime.now().toUtc().difference(dt.toUtc());

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Feed'),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: FortRunTheme.primaryGreen))
            : _items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none, color: FortRunTheme.textMuted, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No activity yet. Start running!',
                          style: TextStyle(color: FortRunTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final action = item['action'] ?? '';
                      final color = _colorForAction(action);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: FortRunTheme.cardDarkAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(_iconForAction(action), color: color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _descriptionForItem(item),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _timeAgo(item['created_at']?.toString()),
                                    style: const TextStyle(
                                      color: FortRunTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
