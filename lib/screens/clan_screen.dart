import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/clan_model.dart';
import '../models/user_model.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';

/// ============================================================
/// ClanScreen — Create, browse, join, view, and leave clans.
/// ============================================================

class ClanScreen extends StatefulWidget {
  const ClanScreen({super.key});

  @override
  State<ClanScreen> createState() => _ClanScreenState();
}

class _ClanScreenState extends State<ClanScreen> {
  bool _isLoading = true;
  UserModel? _user;
  ClanModel? _userClan;
  List<UserModel> _clanMembers = [];
  List<ClanModel> _allClans = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authService = context.read<AuthService>();
    final dbService = context.read<DatabaseService>();
    final uid = authService.currentUser?.id;
    if (uid == null) return;

    setState(() => _isLoading = true);

    final user = await dbService.getUser(uid);
    ClanModel? clan;
    List<UserModel> members = [];

    if (user?.clanId != null) {
      clan = await dbService.getClan(user!.clanId!);
      members = await dbService.getClanMembers(user.clanId!);
    }

    final allClans = await dbService.getAllClans();

    if (mounted) {
      setState(() {
        _user = user;
        _userClan = clan;
        _clanMembers = members;
        _allClans = allClans;
        _isLoading = false;
      });
    }
  }

  void _showCreateClanDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FortRunTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Clan', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Clan name',
            prefixIcon: Icon(Icons.groups),
          ),
          maxLength: 24,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: FortRunTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _createClan(name);
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  Future<void> _createClan(String name) async {
    final dbService = context.read<DatabaseService>();
    final uid = context.read<AuthService>().currentUser?.id;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final clan = ClanModel(name: name, createdAt: DateTime.now());
      final clanId = await dbService.createClan(clan);
      await dbService.joinClan(clanId, uid);
      await dbService.logActivity(
        actorId: uid,
        action: 'clan_join',
        targetName: name,
        detail: 'Created and joined clan',
      );
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create clan: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _joinClan(ClanModel clan) async {
    final dbService = context.read<DatabaseService>();
    final uid = context.read<AuthService>().currentUser?.id;
    if (uid == null || clan.id == null) return;

    final memberCount = await dbService.getClanMemberCount(clan.id!);
    if (memberCount >= AppConstants.maxClanMembers) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This clan is full (max 10 members)')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await dbService.joinClan(clan.id!, uid);
      await dbService.logActivity(
        actorId: uid,
        action: 'clan_join',
        targetName: clan.name,
      );
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join clan: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _leaveClan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FortRunTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Clan?', style: TextStyle(color: Colors.white)),
        content: Text(
          'You will leave ${_userClan?.name ?? "your clan"}. Your walls will remain but won\'t count toward clan totals.',
          style: const TextStyle(color: FortRunTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: FortRunTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: FortRunTheme.enemyRed),
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final dbService = context.read<DatabaseService>();
    final uid = context.read<AuthService>().currentUser?.id;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      await dbService.logActivity(
        actorId: uid,
        action: 'clan_leave',
        targetName: _userClan?.name,
      );
      await dbService.leaveClan(uid);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave clan: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: FortRunTheme.primaryGreen))
              : RefreshIndicator(
                  color: FortRunTheme.primaryGreen,
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: _userClan != null ? _buildClanView() : _buildNoClanView(),
                  ),
                ),
        ),
      ),
    );
  }

  // ── User has a clan ─────────────────────────────────────────
  Widget _buildClanView() {
    return Column(
      children: [
        const SizedBox(height: 10),

        // Clan header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: FortRunTheme.cardGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FortRunTheme.primaryGreen.withAlpha(77)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FortRunTheme.primaryGreen.withAlpha(38),
                ),
                child: const Icon(Icons.shield, color: FortRunTheme.primaryGreen, size: 40),
              ),
              const SizedBox(height: 14),
              Text(
                _userClan!.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniStat(Icons.people, '${_clanMembers.length}/${AppConstants.maxClanMembers}'),
                  const SizedBox(width: 24),
                  _miniStat(Icons.star, '${_userClan!.totalPoints} pts'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Members
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'MEMBERS',
            style: TextStyle(
              color: FortRunTheme.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        ..._clanMembers.map((member) => _memberTile(member)),

        const SizedBox(height: 24),

        // Leave clan button
        OutlinedButton.icon(
          onPressed: _leaveClan,
          icon: const Icon(Icons.exit_to_app, size: 18),
          label: const Text('Leave Clan'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FortRunTheme.enemyRed,
            side: const BorderSide(color: FortRunTheme.enemyRed),
          ),
        ),
      ],
    );
  }

  Widget _miniStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: FortRunTheme.textMuted, size: 16),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: FortRunTheme.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _memberTile(UserModel member) {
    final isCurrentUser = member.id == _user?.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? FortRunTheme.primaryGreen.withAlpha(20)
            : FortRunTheme.cardDarkAlt,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: FortRunTheme.primaryGreen.withAlpha(77))
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: FortRunTheme.cardDark,
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : 'R',
              style: const TextStyle(
                color: FortRunTheme.primaryGreen,
                fontWeight: FontWeight.w800,
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
                    Text(
                      member.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    if (isCurrentUser)
                      const Text(' (you)', style: TextStyle(color: FortRunTheme.textMuted, fontSize: 12)),
                  ],
                ),
                Text(
                  '${member.totalKm.toStringAsFixed(1)} km',
                  style: const TextStyle(color: FortRunTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${member.points} pts',
            style: const TextStyle(
              color: FortRunTheme.starGold,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── User has no clan ────────────────────────────────────────
  Widget _buildNoClanView() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'CLANS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Team up to dominate Islamabad',
          style: TextStyle(
            fontSize: 13,
            color: FortRunTheme.primaryGreen.withAlpha(178),
          ),
        ),

        const SizedBox(height: 28),

        // Create clan button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showCreateClanDialog,
            icon: const Icon(Icons.add),
            label: const Text('CREATE NEW CLAN'),
          ),
        ),

        const SizedBox(height: 28),

        // Browse clans
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'JOIN A CLAN',
            style: TextStyle(
              color: FortRunTheme.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_allClans.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: FortRunTheme.cardDarkAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.groups, color: FortRunTheme.textMuted, size: 40),
                SizedBox(height: 10),
                Text(
                  'No clans yet. Be the first to create one!',
                  style: TextStyle(color: FortRunTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._allClans.map((clan) => _clanBrowseTile(clan)),
      ],
    );
  }

  Widget _clanBrowseTile(ClanModel clan) {
    return GestureDetector(
      onTap: () => _joinClan(clan),
      child: Container(
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
                color: FortRunTheme.primaryGreen.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield, color: FortRunTheme.primaryGreen, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clan.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${clan.totalPoints} pts',
                    style: const TextStyle(color: FortRunTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: FortRunTheme.primaryGreen.withAlpha(38),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'JOIN',
                style: TextStyle(
                  color: FortRunTheme.primaryGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
