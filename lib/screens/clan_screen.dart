import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/clan_model.dart';
import '../models/user_model.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';

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
    final dbService = context.read<DatabaseService>();
    final uid = context.read<AuthService>().currentUser?.id;
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

  void _showCreateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FortRunTheme.cardDark,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Create Clan',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose a powerful name. Your clan will dominate Islamabad.',
              style: GoogleFonts.outfit(
                  color: FortRunTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Clan name',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
              maxLength: 24,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: FortRunTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
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
          actorId: uid, action: 'clan_join', targetName: name,
          detail: 'Created and joined clan');
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create clan: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _joinClan(ClanModel clan) async {
    final dbService = context.read<DatabaseService>();
    final uid = context.read<AuthService>().currentUser?.id;
    if (uid == null || clan.id == null) return;

    final count = await dbService.getClanMemberCount(clan.id!);
    if (count >= AppConstants.maxClanMembers) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This clan is full (max 10 members)')));
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      await dbService.joinClan(clan.id!, uid);
      await dbService.logActivity(
          actorId: uid, action: 'clan_join', targetName: clan.name);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to join clan: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _leaveClan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FortRunTheme.cardDark,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Leave Clan?',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'You will leave ${_userClan?.name ?? "your clan"}. Your walls remain but won\'t count toward clan totals.',
          style: GoogleFonts.outfit(
              color: FortRunTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: FortRunTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: FortRunTheme.enemyRed),
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
          actorId: uid, action: 'clan_leave', targetName: _userClan?.name);
      await dbService.leaveClan(uid);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to leave clan: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FortRunTheme.scaffoldDark,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: FortRunTheme.primaryGreen))
          : RefreshIndicator(
              color: FortRunTheme.primaryGreen,
              backgroundColor: FortRunTheme.cardDark,
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: FortRunTheme.cardDark,
                    automaticallyImplyLeading: false,
                    title: Row(
                      children: [
                        const Icon(Icons.shield,
                            color: FortRunTheme.primaryGreen, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'CLANS',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: Container(height: 1,
                          color: FortRunTheme.cardDarkBorder),
                    ),
                  ),
                  if (_userClan != null)
                    ..._buildClanView()
                  else
                    ..._buildNoClanView(),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildClanView() {
    final maxKm = _clanMembers.isEmpty
        ? 1.0
        : _clanMembers
            .map((m) => m.totalKm)
            .reduce((a, b) => a > b ? a : b)
            .clamp(1.0, double.infinity);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Clan Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FortRunTheme.primaryGreen.withOpacity(0.12),
                      FortRunTheme.primaryGreenDeep.withOpacity(0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: FortRunTheme.primaryGreen.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: FortRunTheme.primaryGradient,
                      ),
                      child: const Icon(Icons.shield,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _userClan!.name,
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ClanStat(
                          '${_clanMembers.length}/${AppConstants.maxClanMembers}',
                          'Members',
                          Icons.people_outline,
                        ),
                        Container(
                            width: 1,
                            height: 30,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            color: Colors.white12),
                        _ClanStat(
                          '${_userClan!.totalPoints}',
                          'Points',
                          Icons.stars_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Members section
              Row(
                children: [
                  Text('MEMBERS',
                      style: GoogleFonts.outfit(
                        color: FortRunTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      )),
                  const Spacer(),
                  Text(
                    '${_clanMembers.length} runners',
                    style: const TextStyle(
                        color: FortRunTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ..._clanMembers.map((m) => _MemberTile(
                    member: m,
                    isCurrentUser: m.id == _user?.id,
                    maxKm: maxKm,
                  )),

              const SizedBox(height: 20),

              // Leave button
              OutlinedButton.icon(
                onPressed: _leaveClan,
                icon: const Icon(Icons.exit_to_app_rounded, size: 16),
                label: const Text('Leave Clan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FortRunTheme.enemyRed,
                  side: const BorderSide(color: FortRunTheme.enemyRed),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildNoClanView() {
    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            // Create clan
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FortRunTheme.primaryGreen.withOpacity(0.08),
                    FortRunTheme.cardDarkAlt,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: FortRunTheme.primaryGreen.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start a Clan',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    'Form a team, claim territories together and dominate the city.',
                    style: GoogleFonts.outfit(
                        color: FortRunTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('CREATE NEW CLAN'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (_allClans.isNotEmpty) ...[
              Text('JOIN A CLAN',
                  style: GoogleFonts.outfit(
                    color: FortRunTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  )),
              const SizedBox(height: 12),
              ..._allClans.map((clan) => _ClanBrowseTile(
                    clan: clan,
                    onJoin: () => _joinClan(clan),
                  )),
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.groups_outlined,
                          color: FortRunTheme.textMuted, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No clans yet.\nBe the first to create one!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                            color: FortRunTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
          ]),
        ),
      ),
    ];
  }
}

class _ClanStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _ClanStat(this.value, this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: FortRunTheme.textMuted, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(
                color: FortRunTheme.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final UserModel member;
  final bool isCurrentUser;
  final double maxKm;
  const _MemberTile(
      {required this.member,
      required this.isCurrentUser,
      required this.maxKm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? FortRunTheme.primaryGreen.withOpacity(0.06)
            : FortRunTheme.cardDarkAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? FortRunTheme.primaryGreen.withOpacity(0.25)
              : FortRunTheme.cardDarkBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FortRunTheme.cardDark,
                  border: Border.all(
                    color: isCurrentUser
                        ? FortRunTheme.primaryGreen
                        : FortRunTheme.cardDarkBorder,
                  ),
                ),
                child: Center(
                  child: Text(
                    member.name.isNotEmpty
                        ? member.name[0].toUpperCase()
                        : 'R',
                    style: GoogleFonts.outfit(
                      color: isCurrentUser
                          ? FortRunTheme.primaryGreen
                          : FortRunTheme.textSecondary,
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
                        Text(
                          member.name,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: FortRunTheme.primaryGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('you',
                                style: GoogleFonts.outfit(
                                    color: FortRunTheme.primaryGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${member.totalKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                          color: FortRunTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '${member.points}',
                style: GoogleFonts.outfit(
                  color: FortRunTheme.starGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 2),
              const Text(' pts',
                  style: TextStyle(
                      color: FortRunTheme.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          // Contribution bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: maxKm > 0 ? (member.totalKm / maxKm).clamp(0.0, 1.0) : 0,
              minHeight: 3,
              backgroundColor: FortRunTheme.cardDark,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCurrentUser
                    ? FortRunTheme.primaryGreen
                    : FortRunTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClanBrowseTile extends StatelessWidget {
  final ClanModel clan;
  final VoidCallback onJoin;
  const _ClanBrowseTile({required this.clan, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FortRunTheme.cardDarkAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FortRunTheme.cardDarkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FortRunTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: FortRunTheme.primaryGreen.withOpacity(0.2)),
            ),
            child: const Icon(Icons.shield_outlined,
                color: FortRunTheme.primaryGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clan.name,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    )),
                Text('${clan.totalPoints} pts',
                    style: const TextStyle(
                        color: FortRunTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onJoin,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: FortRunTheme.primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: FortRunTheme.primaryGreen.withOpacity(0.3)),
              ),
              child: Text('JOIN',
                  style: GoogleFonts.outfit(
                    color: FortRunTheme.primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}
