import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game/catalog.dart';
import 'game/combat_rules.dart';
import 'game/game_rules.dart';
import 'game/summon_rules.dart';
import 'features/cards/deck_builder.dart';
import 'features/profile/cloud_account_controller.dart';
import 'models/player_save.dart';
import 'services/local_save_service.dart';
import 'services/cloud_factory.dart';
import 'services/storage_factory.dart';
import 'theme/kardrune_theme.dart';

typedef RandomRoll = double Function();

class KardRuneApp extends StatelessWidget {
  const KardRuneApp({
    super.key,
    this.random,
    this.saveService,
    this.cloudController,
    this.nowMs,
  });
  final RandomRoll? random;
  final LocalSaveService? saveService;
  final CloudAccountController? cloudController;
  final int Function()? nowMs;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Idle KardRune',
    theme: KardRuneTheme.data,
    home: IdleShell(
      random: random ?? math.Random().nextDouble,
      saveService: saveService,
      cloudController: cloudController,
      nowMs: nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
    ),
  );
}

class IdleShell extends StatefulWidget {
  const IdleShell({
    super.key,
    required this.random,
    this.saveService,
    this.cloudController,
    required this.nowMs,
  });
  final RandomRoll random;
  final LocalSaveService? saveService;
  final CloudAccountController? cloudController;
  final int Function() nowMs;
  @override
  State<IdleShell> createState() => _IdleShellState();
}

class _IdleShellState extends State<IdleShell> {
  int tab = 0, shards = 1500, page = 0, rewardsLeft = 10;
  String name = 'Runebearer', avatar = 'player';
  String battleStatus = '';
  bool italian = false;
  final owned = <String>{};
  final attacks = <String, int>{}, crits = <String, int>{};
  var active = 'sam:1',
      duels = 0,
      wins = 0,
      pulls = 0,
      practiceDay = '',
      practiceCount = 0;
  List<String> deck = [];
  late final LocalSaveService? _saveService;
  CloudAccountController? _cloud;
  bool _ownsCloud = false;

  @override
  void initState() {
    super.initState();
    _saveService = widget.saveService ?? createDefaultLocalSave();
    final save =
        _saveService?.load(nowMs: widget.nowMs()) ?? PlayerSave.initial();
    name = save.name;
    avatar = save.avatar;
    shards = save.shards;
    active = save.active;
    duels = save.duels;
    wins = save.wins;
    pulls = save.pulls;
    practiceDay = save.practiceDay;
    practiceCount = save.practiceCount;
    owned.addAll(save.owned);
    attacks.addAll(save.attacks);
    crits.addAll(save.crits);
    deck = _saveService?.loadDeck().where(owned.contains).toList() ?? [];
    final daily = GameRules.dailyRewardState(
      DailyRewardState(day: practiceDay, count: practiceCount),
      widget.nowMs(),
    );
    practiceDay = daily.day;
    practiceCount = daily.count;
    rewardsLeft = GameRules.dailyRewardLimit - practiceCount;
    _cloud = widget.cloudController;
    if (_cloud != null) {
      _cloud!.addListener(_cloudChanged);
      _cloud!.start();
    } else if (_saveService != null) {
      _initializeCloud();
    }
  }

  Future<void> _initializeCloud() async {
    final controller = await createDefaultCloudController(
      _saveService!,
      _applyRemoteSave,
    );
    if (!mounted || controller == null) return;
    _cloud = controller;
    _ownsCloud = true;
    controller.addListener(_cloudChanged);
    controller.start();
    setState(() {});
  }

  void _cloudChanged() {
    if (mounted) setState(() {});
  }

  void _applyRemoteSave(PlayerSave save) {
    if (!mounted) return;
    setState(() {
      name = save.name;
      avatar = save.avatar;
      shards = save.shards;
      active = save.active;
      duels = save.duels;
      wins = save.wins;
      pulls = save.pulls;
      practiceDay = save.practiceDay;
      practiceCount = save.practiceCount;
      rewardsLeft = GameRules.dailyRewardLimit - practiceCount;
      owned
        ..clear()
        ..addAll(save.owned);
      attacks
        ..clear()
        ..addAll(save.attacks);
      crits
        ..clear()
        ..addAll(save.crits);
      deck = _saveService?.loadDeck().where(owned.contains).toList() ?? [];
    });
  }

  @override
  void dispose() {
    _cloud?.removeListener(_cloudChanged);
    if (_ownsCloud) _cloud?.dispose();
    super.dispose();
  }

  void _persist() {
    _saveService?.save(
      PlayerSave(
        name: name,
        avatar: avatar,
        shards: shards,
        owned: owned.toList(),
        active: active,
        duels: duels,
        wins: wins,
        pulls: pulls,
        practiceDay: practiceDay,
        practiceCount: practiceCount,
        attacks: Map.of(attacks),
        crits: Map.of(crits),
      ),
    );
    _cloud?.localChanged();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              _Header(shards: shards),
              Expanded(
                child: IndexedStack(
                  index: tab,
                  children: [
                    _Tournament(
                      rewardsLeft: rewardsLeft,
                      status: battleStatus,
                      onStart: _train,
                    ),
                    _Cards(
                      page: page,
                      title: italian ? 'CARTE' : 'CARDS',
                      owned: owned.toList(),
                      deck: deck,
                      onPage: (v) => setState(() => page = v),
                      onDeck: (value) {
                        setState(() => deck = [...value]);
                        _saveService?.saveDeck(deck);
                      },
                    ),
                    _Summon(
                      shards: shards,
                      title: italian ? 'EVOCA' : 'SUMMON',
                      onSummon: _summon,
                    ),
                    _Profile(
                      name: name,
                      avatar: avatar,
                      onName: (v) {
                        setState(() => name = v);
                        _persist();
                      },
                      onAvatar: (v) {
                        setState(() => avatar = v);
                        _persist();
                      },
                      onLanguage: () => setState(() => italian = !italian),
                      cloud: _cloud,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: tab,
      type: BottomNavigationBarType.fixed,
      onTap: (v) => setState(() => tab = v),
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.shield),
          label: 'TOURNAMENT',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.style),
          label: italian ? 'CARTE' : 'CARDS',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.auto_awesome),
          label: italian ? 'EVOCA' : 'SUMMON',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person),
          label: italian ? 'PROFILO' : 'PROFILE',
        ),
      ],
    ),
  );
  void _train() {
    final parts = active.split(':');
    final stage = int.tryParse(parts.last) ?? 1;
    final result = GameRules.resolvePractice(
      DailyRewardState(day: practiceDay, count: practiceCount),
      attacks[active] ?? CombatRules.legacyAttack(active),
      stage,
      widget.random(),
      widget.nowMs(),
    );
    setState(() {
      shards += result.reward;
      duels++;
      if (result.win) wins++;
      practiceDay = result.daily.day;
      practiceCount = result.daily.count;
      rewardsLeft = GameRules.dailyRewardLimit - practiceCount;
      battleStatus =
          '${result.win ? 'VICTORY' : 'DEFEAT'} · +${result.reward} SHARDS';
    });
    _persist();
  }

  void _summon(bool featured) {
    final cost = SummonRules.cost(featured);
    if (shards < cost) return;
    final stage = SummonRules.stageFor(featured, widget.random());
    final index = SummonRules.heroIndex(
      featured,
      widget.random(),
      widget.random(),
    );
    final id = '${KardRuneCatalog.heroes[index].id}:$stage',
        duplicate = owned.contains(id);
    final attack = CombatRules.rollAttack(widget.random);
    final crit = CombatRules.rollCrit(widget.random);
    setState(() {
      shards -= cost;
      pulls++;
      if (!duplicate) {
        owned.add(id);
        attacks[id] = attack;
        crits[id] = crit;
      }
    });
    _persist();
    if (duplicate) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('DUPLICATE CARD'),
          content: Text(
            'Current ATK ${attacks[id]} · CRIT ${crits[id]}%\nNew ATK $attack · CRIT $crit%',
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => shards += 100);
                _persist();
                Navigator.pop(c);
              },
              child: const Text('KEEP CURRENT · +100'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  attacks[id] = attack;
                  crits[id] = crit;
                });
                _persist();
                Navigator.pop(c);
              },
              child: const Text('REPLACE'),
            ),
          ],
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          '${KardRuneCatalog.heroes[index].name.toUpperCase()} · STAGE $stage',
        ),
        content: Image.asset(
          KardRuneCatalog.heroes[index].cardAsset(
            KardRuneCatalog.heroes[index].stages[stage - 1],
          ),
          fit: BoxFit.contain,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.shards});
  final int shards;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Text(
            'IDLE KARDRUNE',
            style: TextStyle(
              color: KardRuneTheme.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          const Icon(Icons.diamond_outlined, color: KardRuneTheme.gold),
          Text(
            shards.toString().replaceAllMapped(
              RegExp(r'\B(?=(\d{3})+(?!\d))'),
              (_) => ',',
            ),
          ),
        ],
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xdd0b1c31),
        border: Border.all(color: KardRuneTheme.gold.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: KardRuneTheme.gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

class _Tournament extends StatelessWidget {
  const _Tournament({
    required this.rewardsLeft,
    required this.status,
    required this.onStart,
  });
  final int rewardsLeft;
  final String status;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => _Panel(
    title: 'TOURNAMENT',
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const Text(
          'TRAINING ARENA',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _hero('sam', 1),
              const Icon(Icons.flash_on, color: KardRuneTheme.gold, size: 34),
              _hero('dren', 1),
            ],
          ),
        ),
        Text('Daily rewards remaining · $rewardsLeft'),
        if (status.isNotEmpty) Text(status, key: const Key('battle-status')),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onStart,
            child: const Text('⚔ START DUEL'),
          ),
        ),
      ],
    ),
  );
  Widget _hero(String id, int stage) {
    final h = KardRuneCatalog.heroes.firstWhere((x) => x.id == id);
    return Flexible(
      child: AspectRatio(
        aspectRatio: .72,
        child: Image.asset(
          h.cardAsset(h.stages[stage - 1]),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({
    required this.page,
    required this.title,
    required this.owned,
    required this.deck,
    required this.onPage,
    required this.onDeck,
  });
  final int page;
  final String title;
  final List<String> owned;
  final List<String> deck;
  final ValueChanged<int> onPage;
  final ValueChanged<List<String>> onDeck;
  @override
  Widget build(BuildContext context) {
    final all = [
      for (final h in KardRuneCatalog.heroes)
        for (var s = 1; s <= 3; s++) MapEntry(h, s),
    ];
    final slice = all.skip(page * 4).take(4);
    return _Panel(
      title: title,
      child: Column(
        children: [
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: .72,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [for (final item in slice) _card(item.key, item.value)],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: page > 0 ? () => onPage(page - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${page + 1} / 7'),
              IconButton(
                onPressed: page < 6 ? () => onPage(page + 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => Dialog(
                  child: SizedBox(
                    width: 430,
                    height: 650,
                    child: DeckBuilder(
                      owned: owned,
                      initial: deck,
                      onSave: (value) {
                        onDeck(value);
                        Navigator.pop(dialogContext);
                      },
                    ),
                  ),
                ),
              ),
              child: const Text('DECK BUILDER'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(dynamic h, int s) => Semantics(
    label: '${h.name} Stage $s',
    button: true,
    child: Image.asset(h.cardAsset(h.stages[s - 1]), fit: BoxFit.contain),
  );
}

class _Summon extends StatelessWidget {
  const _Summon({
    required this.shards,
    required this.title,
    required this.onSummon,
  });
  final int shards;
  final String title;
  final ValueChanged<bool> onSummon;
  @override
  Widget build(BuildContext context) => _Panel(
    title: title,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const Icon(Icons.auto_awesome, color: KardRuneTheme.gold, size: 72),
        const Text(
          'CALL HEROES FROM THE RUNES',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: shards >= 300 ? () => onSummon(false) : null,
            child: const Text('STANDARD · 300'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: shards >= 600 ? () => onSummon(true) : null,
            child: const Text('FEATURED · 600'),
          ),
        ),
      ],
    ),
  );
}

class _Profile extends StatelessWidget {
  const _Profile({
    required this.name,
    required this.avatar,
    required this.onName,
    required this.onAvatar,
    required this.onLanguage,
    required this.cloud,
  });
  final String name, avatar;
  final ValueChanged<String> onName, onAvatar;
  final VoidCallback onLanguage;
  final CloudAccountController? cloud;
  @override
  Widget build(BuildContext context) => _Panel(
    title: 'PROFILE',
    child: Column(
      children: [
        Expanded(
          child: Image.asset(
            'assets/idle/avatars/avatar_$avatar.webp',
            fit: BoxFit.contain,
          ),
        ),
        Text(name, style: const TextStyle(fontSize: 20)),
        Wrap(
          children: [
            for (final id in ['player', 'guard', 'vassal', 'king'])
              IconButton(
                onPressed: () => onAvatar(id),
                icon: CircleAvatar(
                  backgroundImage: AssetImage(
                    'assets/idle/avatars/avatar_$id.webp',
                  ),
                ),
              ),
          ],
        ),
        TextField(
          maxLength: 20,
          decoration: const InputDecoration(labelText: 'DISPLAY NAME'),
          onSubmitted: onName,
        ),
        if (cloud != null) ...[
          Text(
            cloud!.identity?.email ??
                cloud!.identity?.displayName ??
                cloud!.message,
            key: const Key('cloud-identity'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            cloud!.message,
            key: const Key('cloud-status'),
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
          if (cloud!.identity == null)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('cloud-google'),
                    onPressed: cloud!.signInGoogle,
                    child: const Text('GOOGLE'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    key: const Key('cloud-email'),
                    onPressed: () => _emailDialog(context),
                    child: const Text('EMAIL'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                if (cloud!.state == CloudAccountState.review) ...[
                  Expanded(
                    child: TextButton(
                      onPressed: cloud!.uploadLocal,
                      child: const Text('UPLOAD LOCAL'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: cloud!.loadCloud,
                      child: const Text('LOAD CLOUD'),
                    ),
                  ),
                ],
                IconButton(
                  key: const Key('cloud-logout'),
                  onPressed: cloud!.signOut,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
        ],
        TextButton(onPressed: onLanguage, child: const Text('ITALIANO')),
      ],
    ),
  );

  Future<void> _emailDialog(BuildContext context) async {
    final email = TextEditingController(), password = TextEditingController();
    var register = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('KARDRUNE ACCOUNT'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('cloud-email-field'),
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'EMAIL'),
              ),
              TextField(
                key: const Key('cloud-password-field'),
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PASSWORD'),
              ),
              CheckboxListTile(
                value: register,
                onChanged: (value) =>
                    setDialogState(() => register = value ?? false),
                title: const Text('CREATE ACCOUNT'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              key: const Key('cloud-email-submit'),
              onPressed: () async {
                if (password.text.length < 6 || !email.text.contains('@')) {
                  return;
                }
                await cloud!.signInEmail(
                  email.text.trim(),
                  password.text,
                  register: register,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('CONTINUE'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    password.dispose();
  }
}
