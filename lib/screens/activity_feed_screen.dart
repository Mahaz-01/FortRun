import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../utils/theme.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _subscription;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  late AnimationController _listCtrl;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
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
        _listCtrl.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _listCtrl.dispose();
    super.dispose();
  }

  IconData _iconForAction(String action) {
    switch (action) {
      case 'run_complete':
        return Icons.directions_run_rounded;
      case 'zone_captured':
        return Icons.flag_rounded;
      case 'sabotage':
        return Icons.local_fire_department_rounded;
      case 'clan_join':
        return Icons.group_add_rounded;
      case 'clan_leave':
        return Icons.group_remove_rounded;
      case 'streak':
        return Icons.bolt_rounded;
      default:
        return Icons.info_rounded;
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
        return const Color(0xFFFFD600);
      default:
        return FortRunTheme.textMuted;
    }
  }

  String _labelForAction(String action) {
    switch (action) {
      case 'run_complete':
        return 'RUN';
      case 'zone_captured':
        return 'CAPTURE';
      case 'sabotage':
        return 'SABOTAGE';
      case 'clan_join':
        return 'JOINED';
      case 'clan_leave':
        return 'LEFT';
      case 'streak':
        return 'STREAK';
      default:
        return 'EVENT';
    }
  }

  String _descriptionForItem(Map<String, dynamic> item) {
    final actor = item['actor_name'] ?? 'Runner';
    final action = item['action'] ?? '';
    final target = item['target_name'] ?? '';
    final detail = item['detail'] ?? '';

    switch (action) {
      case 'run_complete':
        return '$actor completed a run in $target${detail.isNotEmpty ? ' · $detail' : ''}';
      case 'zone_captured':
        return '$actor captured Sector $target!${detail.isNotEmpty ? ' $detail' : ''}';
      case 'sabotage':
        return '$actor sabotaged Sector $target!${detail.isNotEmpty ? ' $detail' : ''}';
      case 'clan_join':
        return '$actor joined clan $target';
      case 'clan_leave':
        return '$actor left clan $target';
      case 'streak':
        return '$actor hit a $detail';
      default:
        return '$actor · $detail';
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

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FortRunTheme.scaffoldDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: FortRunTheme.scaffoldDark,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
              color: Colors.white,
            ),
            title: const Text(
              'Activity Feed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: FortRunTheme.cardDarkBorder,
              ),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: FortRunTheme.primaryGreen,
                  strokeWidth: 2,
                ),
              )
            : _items.isEmpty
                ? _EmptyState()
                : _FeedList(
                    items: _items,
                    listCtrl: _listCtrl,
                    iconForAction: _iconForAction,
                    colorForAction: _colorForAction,
                    labelForAction: _labelForAction,
                    descriptionForItem: _descriptionForItem,
                    timeAgo: _timeAgo,
                    initials: _initials,
                  ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: FortRunTheme.cardDark,
              shape: BoxShape.circle,
              border: Border.all(color: FortRunTheme.cardDarkBorder),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: FortRunTheme.textMuted,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No activity yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Be the first to run and claim\nterritories in your area.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FortRunTheme.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feed list ─────────────────────────────────────────────────

class _FeedList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final AnimationController listCtrl;
  final IconData Function(String) iconForAction;
  final Color Function(String) colorForAction;
  final String Function(String) labelForAction;
  final String Function(Map<String, dynamic>) descriptionForItem;
  final String Function(String?) timeAgo;
  final String Function(String?) initials;

  const _FeedList({
    required this.items,
    required this.listCtrl,
    required this.iconForAction,
    required this.colorForAction,
    required this.labelForAction,
    required this.descriptionForItem,
    required this.timeAgo,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final action = (item['action'] ?? '') as String;
        final color = colorForAction(action);

        final delay = (index * 40).clamp(0, 400);
        final entryAnim = CurvedAnimation(
          parent: listCtrl,
          curve: Interval(
            delay / 1000.0,
            (delay / 1000.0 + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        );

        return AnimatedBuilder(
          animation: entryAnim,
          builder: (context, child) => Opacity(
            opacity: entryAnim.value,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - entryAnim.value)),
              child: child,
            ),
          ),
          child: _FeedCard(
            item: item,
            action: action,
            color: color,
            icon: iconForAction(action),
            label: labelForAction(action),
            description: descriptionForItem(item),
            timestamp: timeAgo(item['created_at']?.toString()),
            actorInitials: initials(item['actor_name']?.toString()),
          ),
        );
      },
    );
  }
}

// ── Feed card ─────────────────────────────────────────────────

class _FeedCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String action;
  final Color color;
  final IconData icon;
  final String label;
  final String description;
  final String timestamp;
  final String actorInitials;

  const _FeedCard({
    required this.item,
    required this.action,
    required this.color,
    required this.icon,
    required this.label,
    required this.description,
    required this.timestamp,
    required this.actorInitials,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: FortRunTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FortRunTheme.cardDarkBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Subtle left accent bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withAlpha(0)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar circle
                  _Avatar(
                    initials: actorInitials,
                    color: color,
                    icon: icon,
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _ActionBadge(label: label, color: color),
                            const Spacer(),
                            Text(
                              timestamp,
                              style: const TextStyle(
                                color: FortRunTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (_hasExtra(item)) ...[
                          const SizedBox(height: 8),
                          _ExtraChips(item: item, action: action),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasExtra(Map<String, dynamic> item) {
    return item['km'] != null || item['xp'] != null || item['walls'] != null;
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final Color color;
  final IconData icon;

  const _Avatar({
    required this.initials,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(60), width: 1.5),
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: FortRunTheme.cardDark, width: 1.5),
            ),
            child: Icon(icon, color: Colors.black, size: 10),
          ),
        ),
      ],
    );
  }
}

class _ActionBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ActionBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ExtraChips extends StatelessWidget {
  final Map<String, dynamic> item;
  final String action;

  const _ExtraChips({required this.item, required this.action});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (item['km'] != null) {
      chips.add(_Chip(
        icon: Icons.straighten_rounded,
        label: '${item['km']} km',
        color: FortRunTheme.primaryGreen,
      ));
    }
    if (item['walls'] != null) {
      chips.add(_Chip(
        icon: Icons.grid_view_rounded,
        label: '${item['walls']} walls',
        color: FortRunTheme.safeBlue,
      ));
    }
    if (item['xp'] != null) {
      chips.add(_Chip(
        icon: Icons.star_rounded,
        label: '+${item['xp']} XP',
        color: FortRunTheme.starGold,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FortRunTheme.cardDarkAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FortRunTheme.cardDarkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
