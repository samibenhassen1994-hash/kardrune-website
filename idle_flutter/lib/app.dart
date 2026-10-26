import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game/catalog.dart';
import 'game/combat_rules.dart';
import 'game/game_rules.dart';
import 'game/summon_rules.dart';
import 'features/cards/deck_builder.dart';
import 'features/profile/cloud_account_controller.dart';
import 'features/pvp/live_match_coordinator.dart';
import 'features/pvp/live_pvp_arena.dart';
import 'models/player_save.dart';
import 'services/local_save_service.dart';
import 'services/live_pvp_socket.dart';
import 'repositories/pvp_repository.dart';
import 'services/cloud_factory.dart';
import 'services/app_update_controller.dart';
import 'services/update_factory.dart';
import 'services/storage_factory.dart';
import 'theme/kardrune_theme.dart';

typedef RandomRoll = double Function();

enum MotionPreference { automatic, full, reduced }

class KardRuneApp extends StatelessWidget {
  const KardRuneApp({
    super.key,
    this.random,
    this.saveService,
    this.cloudController,
    this.liveMatchCoordinator,
    this.updateController,
    this.nowMs,
  });
  final RandomRoll? random;
  final LocalSaveService? saveService;
  final CloudAccountController? cloudController;
  final LiveMatchCoordinator? liveMatchCoordinator;
  final AppUpdateController? updateController;
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
      liveMatchCoordinator: liveMatchCoordinator,
      updateController: updateController,
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
    this.liveMatchCoordinator,
    this.updateController,
    required this.nowMs,
  });
  final RandomRoll random;
  final LocalSaveService? saveService;
  final CloudAccountController? cloudController;
  final LiveMatchCoordinator? liveMatchCoordinator;
  final AppUpdateController? updateController;
  final int Function() nowMs;
  @override
  State<IdleShell> createState() => _IdleShellState();
}

class _IdleShellState extends State<IdleShell> {
  static const _motionKey = 'idle-motion-preference-v1';
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
  MotionPreference motion = MotionPreference.automatic;
  late final LocalSaveService? _saveService;
  CloudAccountController? _cloud;
  LiveMatchCoordinator? _pvp;
  bool _ownsCloud = false;
  late final AppUpdateController? _updates;
  bool _ownsUpdates = false;

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
    motion = MotionPreference.values.firstWhere(
      (value) => value.name == _saveService?.storage.read(_motionKey),
      orElse: () => MotionPreference.automatic,
    );
    final daily = GameRules.dailyRewardState(
      DailyRewardState(day: practiceDay, count: practiceCount),
      widget.nowMs(),
    );
    practiceDay = daily.day;
    practiceCount = daily.count;
    rewardsLeft = GameRules.dailyRewardLimit - practiceCount;
    _pvp = widget.liveMatchCoordinator;
    _pvp?.addListener(_pvpChanged);
    _updates = widget.updateController ?? createDefaultUpdateController();
    _ownsUpdates = widget.updateController == null && _updates != null;
    _updates?.addListener(_updateChanged);
    _updates?.start();
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
    if (_cloud?.identity != null && _pvp == null) {
      _pvp = LiveMatchCoordinator(
        repository: PvpRepository(_cloud!.api),
        connect: LivePvpSocket.connect,
      )..addListener(_pvpChanged);
      _loadCloudDeck();
    } else if (_cloud?.identity == null && _pvp != null) {
      _pvp!.removeListener(_pvpChanged);
      _pvp!.dispose();
      _pvp = null;
    }
    if (mounted) setState(() {});
  }

  void _pvpChanged() {
    _updates?.setMatchActive(_pvp?.state == LiveMatchState.arena);
    if (mounted) setState(() {});
  }

  void _updateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCloudDeck() async {
    try {
      final value = await _pvp!.loadDeck();
      if (!mounted || value.isEmpty) return;
      setState(() => deck = value.where(owned.contains).take(9).toList());
      _saveService?.saveDeck(deck);
    } catch (_) {}
  }

  Future<void> _saveDeck(List<String> value) async {
    setState(() => deck = [...value]);
    _saveService?.saveDeck(deck);
    if (_pvp != null) {
      try {
        await _pvp!.saveDeck(deck);
      } catch (error) {
        if (mounted) {
          setState(() => battleStatus = 'Deck saved locally · Cloud: $error');
        }
      }
    }
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
    _pvp?.removeListener(_pvpChanged);
    _pvp?.dispose();
    _updates?.removeListener(_updateChanged);
    if (_ownsUpdates) _updates?.dispose();
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
  Widget build(BuildContext context) {
    if (_pvp?.state == LiveMatchState.arena) {
      return _motionWrap(_withUpdate(
        Stack(
          children: [
            Positioned.fill(
              child: LivePvpArena(
                controller: _pvp!.arena,
                onPlay: _pvp!.play,
                onReady: _pvp!.ready,
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: IconButton(
                  key: const Key('close-live-arena'),
                  onPressed: _pvp!.close,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ));
    }
    return _motionWrap(_withUpdate(
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xff070e20),
              gradient: RadialGradient(
                center: Alignment(0, -1.12),
                radius: 1.25,
                colors: [Color(0xff1c3256), Color(0xff070e20)],
                stops: [0, .58],
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
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
                          onLive: _pvp?.findMatch,
                          liveStatus: _pvp?.message,
                          canLive: _pvp != null && deck.isNotEmpty,
                        ),
                        _Cards(
                          page: page,
                          title: italian ? 'CARTE' : 'CARDS',
                          owned: owned.toList(),
                          deck: deck,
                          onPage: (v) => setState(() => page = v),
                          onDeck: _saveDeck,
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
                          motion: motion,
                          onMotion: (value) {
                            setState(() => motion = value);
                            _saveService?.storage.write(_motionKey, value.name);
                          },
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
        ),
        bottomNavigationBar: _RuneNavigation(
          current: tab,
          italian: italian,
          onTap: (value) => setState(() => tab = value),
        ),
      ),
    ));
  }

  Widget _motionWrap(Widget child) {
    final media = MediaQuery.of(context);
    final reduce = switch (motion) {
      MotionPreference.automatic => media.disableAnimations,
      MotionPreference.full => false,
      MotionPreference.reduced => true,
    };
    return MediaQuery(data: media.copyWith(disableAnimations: reduce), child: child);
  }

  Widget _withUpdate(Widget child) => Stack(
    children: [
      Positioned.fill(child: child),
      if (_updates?.available == true)
        Positioned(
          top: 8,
          left: 16,
          right: 16,
          child: SafeArea(
            child: Material(
              color: const Color(0xff2c2350),
              borderRadius: BorderRadius.circular(10),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Expanded(child: Text('A new version is ready.')),
                    TextButton(
                      key: const Key('apply-update'),
                      onPressed: _updates!.apply,
                      child: const Text('UPDATE'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
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
  Widget build(BuildContext context) => Container(
    height: 79,
    padding: const EdgeInsets.symmetric(horizontal: 19),
    decoration: const BoxDecoration(
      color: Color(0xdd071226),
      border: Border(bottom: BorderSide(color: Color(0x30d2b780))),
    ),
    child: Row(
      children: [
        Transform.rotate(
          angle: -.12,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff1c3857), Color(0xff081122)],
              ),
              border: Border.all(color: const Color(0xffefc574), width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x33e7ab42), blurRadius: 20),
              ],
            ),
            child: const Text(
              'KR',
              style: TextStyle(
                color: Color(0xfff6d68e),
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: 'IDLE ',
                  children: [
                    TextSpan(
                      text: 'KARDRUNE',
                      style: TextStyle(color: Color(0xfff5d28b)),
                    ),
                  ],
                ),
                maxLines: 1,
                style: TextStyle(
                  color: Color(0xfff9f4e9),
                  fontFamily: 'Georgia',
                  fontSize: 15,
                  letterSpacing: .7,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'THE POCKET REALM',
                style: TextStyle(
                  color: Color(0xff8fa6c8),
                  fontSize: 8,
                  letterSpacing: 2.1,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xff1c2942),
            border: Border.all(color: const Color(0x50c6a961)),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('◆', style: TextStyle(color: Color(0xff72d8ff))),
              const SizedBox(width: 5),
              Text(
                shards.toString().replaceAllMapped(
                  RegExp(r'\B(?=(\d{3})+(?!\d))'),
                  (_) => ',',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RuneNavigation extends StatelessWidget {
  const _RuneNavigation({required this.current, required this.italian, required this.onTap});
  final int current;
  final bool italian;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      (Icons.emoji_events_outlined, 'TOURNAMENT'),
      (Icons.style_outlined, italian ? 'CARTE' : 'CARDS'),
      (Icons.auto_awesome_outlined, italian ? 'EVOCA' : 'SUMMON'),
      (Icons.person_outline, italian ? 'PROFILO' : 'PROFILE'),
    ];
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xf5091426),
        border: Border(top: BorderSide(color: Color(0x59bca46c))),
        boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 24)],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: current == i,
                  label: items[i].$2,
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (current == i)
                          const Positioned(
                            top: 0,
                            child: SizedBox(
                              width: 38,
                              child: Divider(color: Color(0xfff9d892), thickness: 2, height: 2),
                            ),
                          ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(items[i].$1, size: 23, color: current == i ? const Color(0xfff9d892) : const Color(0xff91a1b9)),
                            const SizedBox(height: 4),
                            Text(items[i].$2, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: current == i ? const Color(0xfff9d892) : const Color(0xff91a1b9))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tournament extends StatelessWidget {
  const _Tournament({
    required this.rewardsLeft,
    required this.status,
    required this.onStart,
    required this.onLive,
    required this.liveStatus,
    required this.canLive,
  });
  final int rewardsLeft;
  final String status;
  final VoidCallback onStart;
  final VoidCallback? onLive;
  final String? liveStatus;
  final bool canLive;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxHeight < 560;
      return Padding(
        padding: EdgeInsets.fromLTRB(compact ? 13 : 19, compact ? 8 : 16, compact ? 13 : 19, 7),
        child: Column(
          children: [
            _Eyebrow(compact: compact),
            SizedBox(height: compact ? 3 : 7),
            Text.rich(
              const TextSpan(
                text: 'TOURNAMENT ',
                children: [TextSpan(text: 'PvP', style: TextStyle(color: Color(0xfff5d28b)))],
              ),
              style: TextStyle(
                color: const Color(0xfff9f4e9),
                fontFamily: 'Georgia',
                fontSize: compact ? 24 : 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 5),
              const Text(
                'Build your team. Face your rivals. Rise to the top of the Rune Circuit.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xffb9c5d8), fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 5),
            _SeasonBanner(compact: compact),
            SizedBox(height: compact ? 8 : 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR NEXT BATTLE', style: TextStyle(color: Color(0xffeac981), fontSize: 8, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                      SizedBox(height: 3),
                      Text('PRACTICE ARENA', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0x331c5478), border: Border.all(color: const Color(0x6678c5ff)), borderRadius: BorderRadius.circular(30)),
                  child: const Text('SOLO DEMO', style: TextStyle(color: Color(0xffa6daff), fontSize: 8, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 9),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 120),
                padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 11, vertical: compact ? 5 : 10),
                decoration: BoxDecoration(
                  gradient: const RadialGradient(colors: [Color(0xff203958), Color(0xff0b172f)]),
                  border: Border.all(color: const Color(0x45d3ad5b)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(child: _HomeCombatant(id: 'sam', label: 'SAM · S1', subtitle: 'YOUR HERO', compact: compact)),
                    SizedBox(
                      width: compact ? 34 : 48,
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('VS', style: TextStyle(fontFamily: 'Georgia', color: Color(0xffe9c67d), fontSize: 21, fontWeight: FontWeight.w800)),
                          Text('⚔', style: TextStyle(color: Color(0xffe9c67d), fontSize: 13)),
                        ],
                        ),
                      ),
                    ),
                    Expanded(child: _HomeCombatant(id: 'dren', label: 'DREN · S1', subtitle: 'RANDOM OPPONENT', compact: compact, enemy: true)),
                  ],
                ),
              ),
            ),
            SizedBox(height: compact ? 5 : 8),
            if (status.isNotEmpty)
              Text(status, key: const Key('battle-status'), style: const TextStyle(color: Color(0xff83dfa9), fontSize: 10)),
            Text('Rewarded duels remaining today: $rewardsLeft/10', style: const TextStyle(color: Color(0xff93a6bc), fontSize: 10)),
            SizedBox(height: compact ? 5 : 7),
            _RuneButton(actionKey: const Key('start-practice-duel'), label: '⚔  START PRACTICE DUEL', onTap: onStart, gold: true),
            const SizedBox(height: 5),
            if (liveStatus != null)
              Text(liveStatus!, key: const Key('live-match-status'), style: const TextStyle(fontSize: 10, color: Color(0xffa6b9d0))),
            _RuneButton(
              actionKey: const Key('find-live-match'),
              label: onLive == null ? 'SIGN IN FOR LIVE PVP' : deckLabel,
              onTap: canLive ? onLive : null,
            ),
          ],
        ),
      );
    },
  );
  String get deckLabel =>
      canLive ? 'FIND LIVE MATCH' : 'SAVE A DECK TO PLAY LIVE';
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(width: 27, child: Divider(color: Color(0x5ce8bd66))),
      const SizedBox(width: 10),
      Text('ARENA OF THE RUNES', style: TextStyle(color: const Color(0xffe7bf68), fontSize: compact ? 8 : 9, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
      const SizedBox(width: 10),
      const SizedBox(width: 27, child: Divider(color: Color(0x5ce8bd66))),
    ],
  );
}

class _SeasonBanner extends StatelessWidget {
  const _SeasonBanner({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: compact ? 58 : 96,
    padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 22, vertical: compact ? 8 : 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xff253550), Color(0xff101e37)]),
      border: Border.all(color: const Color(0x66dfbe77)),
      borderRadius: BorderRadius.circular(15),
      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10))],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SEASON PREVIEW', style: TextStyle(color: Color(0xffeac981), fontSize: 8, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
              SizedBox(height: compact ? 3 : 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  const TextSpan(text: 'THE RUNE ', children: [TextSpan(text: 'CIRCUIT', style: TextStyle(color: Color(0xfff5d28b)))]),
                  maxLines: 1,
                  style: TextStyle(fontFamily: 'Georgia', fontSize: compact ? 17 : 22, fontWeight: FontWeight.w700),
                ),
              ),
              if (!compact) const Text('First championship • Coming with online accounts', style: TextStyle(color: Color(0xffacbddd), fontSize: 9)),
            ],
          ),
        ),
        Text('♜', style: TextStyle(color: const Color(0xffe2c476), fontSize: compact ? 35 : 54)),
      ],
    ),
  );
}

class _HomeCombatant extends StatelessWidget {
  const _HomeCombatant({required this.id, required this.label, required this.subtitle, required this.compact, this.enemy = false});
  final String id, label, subtitle;
  final bool compact, enemy;
  @override
  Widget build(BuildContext context) {
    final hero = KardRuneCatalog.heroes.firstWhere((item) => item.id == id);
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: const Color(0xff0b1529), border: Border.all(color: enemy ? const Color(0x75ab636b) : const Color(0x68bdac7a)), borderRadius: BorderRadius.circular(12)),
            child: Image.asset(hero.cardAsset(hero.stages.first), fit: BoxFit.contain),
          ),
        ),
        SizedBox(height: compact ? 3 : 6),
        Text(label, maxLines: 1, style: TextStyle(fontFamily: 'Georgia', fontSize: compact ? 11 : 14, fontWeight: FontWeight.w700)),
        Text(subtitle, maxLines: 1, style: TextStyle(color: const Color(0xff93a5c1), fontSize: compact ? 7 : 8, letterSpacing: .7)),
      ],
    );
  }
}

class _RuneButton extends StatelessWidget {
  const _RuneButton({this.actionKey, required this.label, required this.onTap, this.gold = false});
  final Key? actionKey;
  final String label;
  final VoidCallback? onTap;
  final bool gold;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: GestureDetector(
      key: actionKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? .45 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gold ? const [Color(0xfff8dd9d), Color(0xffbc8a3b)] : const [Color(0xff1e344f), Color(0xff13213a)]),
            border: Border.all(color: gold ? const Color(0x9cf6dd9b) : const Color(0x66c4aa66)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label, style: TextStyle(color: gold ? const Color(0xff251a0c) : const Color(0xfff7dba5), fontSize: 10, letterSpacing: .8, fontWeight: FontWeight.w800)),
        ),
      ),
    ),
  );
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(19, 12, 19, 8),
      child: Column(
        children: [
          Text(
            title == 'CARTE' ? 'LE TUE CARTE' : 'YOUR CARDS',
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 27, fontWeight: FontWeight.w700, color: Color(0xfff9f4e9)),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: const Color(0xff101d36), border: Border.all(color: const Color(0x66dfbe77)), borderRadius: BorderRadius.circular(13)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚔ PVP LOADOUT', style: TextStyle(color: Color(0xffa0b0c8), fontSize: 8, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
                const Text('MY DECK', style: TextStyle(fontFamily: 'Georgia', color: Color(0xfff5d28b), fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    for (var i = 0; i < 9; i++)
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: .72,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: const Color(0xff0b172f), border: Border.all(color: const Color(0x667a89a6)), borderRadius: BorderRadius.circular(4)),
                            child: i < deck.length
                                ? Image.asset(_assetForId(deck[i]), fit: BoxFit.contain)
                                : Text('${i + 1}'.padLeft(2, '0'), style: const TextStyle(color: Color(0xff71819c), fontSize: 7)),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _RuneButton(onTap: () => _openDeck(context), label: '✦  EDIT DECK IN CARDS'),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xff1c3252), Color(0xff0c182e)]), border: Border.all(color: const Color(0x54bca766)), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('COLLECTION PROGRESS', style: TextStyle(color: Color(0xffafc2d6), letterSpacing: 1.2, fontSize: 8)),
                Text('${owned.length} / 27 CARDS', style: const TextStyle(fontFamily: 'Georgia', fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: owned.length / 27, minHeight: 6, backgroundColor: const Color(0xff071025), color: const Color(0xfff4d38c))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _FilterLabel('ALL HEROES', active: page == 0),
              const SizedBox(width: 6),
              _FilterLabel('OWNED', active: true),
              const SizedBox(width: 6),
              _FilterLabel('BY RARITY'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: .72,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [for (final item in slice) _card(item.key, item.value, owned.contains('${item.key.id}:${item.value}'))],
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
        ],
      ),
    );
  }

  String _assetForId(String id) {
    final parts = id.split(':');
    final hero = KardRuneCatalog.heroes.firstWhere((item) => item.id == parts.first);
    return hero.cardAsset(hero.stages[int.parse(parts.last) - 1]);
  }

  void _openDeck(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: const Color(0xff101d36),
      shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xffd5ad62)), borderRadius: BorderRadius.circular(16)),
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
  );

  Widget _card(dynamic h, int s, bool isOwned) => Semantics(
    label: '${h.name} Stage $s',
    button: true,
    child: Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: const Color(0xff111e35), border: Border.all(color: const Color(0x62c3a669)), borderRadius: BorderRadius.circular(12)),
      child: Opacity(opacity: isOwned ? 1 : .28, child: Image.asset(h.cardAsset(h.stages[s - 1]), fit: BoxFit.contain)),
    ),
  );
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.label, {this.active = false});
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: active ? const Color(0xff463c30) : const Color(0xff142541), border: Border.all(color: active ? const Color(0x88dabb77) : const Color(0x457484a1)), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: active ? const Color(0xffffe3a4) : const Color(0xffacbfd6), fontSize: 8)),
    ),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(19, 12, 19, 8),
    child: Column(
      children: [
        Text.rich(
          TextSpan(text: title == 'EVOCA' ? 'EVOCA ' : 'HERO ', children: [TextSpan(text: title == 'EVOCA' ? 'EROI' : 'SUMMON', style: const TextStyle(color: Color(0xfff5d28b)))]),
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(gradient: const RadialGradient(center: Alignment(0, -.3), colors: [Color(0xff624966), Color(0xff152443)]), border: Border.all(color: const Color(0x88e1bc71)), borderRadius: BorderRadius.circular(16)),
            child: Stack(
              children: [
                Positioned.fill(child: Image.asset(KardRuneCatalog.heroes.firstWhere((hero) => hero.id == 'dren').cardAsset(KardRuneCatalog.heroes.firstWhere((hero) => hero.id == 'dren').stages[2]), fit: BoxFit.contain)),
                Positioned(top: 14, left: 14, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: const Color(0xffd8b35f), borderRadius: BorderRadius.circular(5)), child: const Text('FEATURED HERO', style: TextStyle(color: Color(0xff241b13), fontSize: 8, letterSpacing: .8, fontWeight: FontWeight.w800)))),
                const Positioned(left: 0, right: 0, bottom: 10, child: Column(children: [Text('EPIC · SHADOW', style: TextStyle(color: Color(0xffe9c880), fontSize: 8, letterSpacing: 1.1, fontWeight: FontWeight.w800)), Text('DREN', style: TextStyle(fontFamily: 'Georgia', fontSize: 25, fontWeight: FontWeight.w700)), Text('The darkness answers his call.', style: TextStyle(color: Color(0xffcad1e0), fontSize: 10))])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        _SummonChoice(
          eyebrow: 'SUMMON PORTAL 01',
          title: 'Standard Summon',
          symbol: '✧',
          action: 'SUMMON 1     ◆ 300',
          enabled: shards >= 300,
          onTap: () => onSummon(false),
        ),
        const SizedBox(height: 8),
        _SummonChoice(
          eyebrow: 'SUMMON PORTAL 02',
          title: 'Featured Summon',
          symbol: '✦',
          action: 'FEATURED PULL     ◆ 600',
          enabled: shards >= 600,
          gold: true,
          onTap: () => onSummon(true),
        ),
      ],
    ),
  );
}

class _SummonChoice extends StatelessWidget {
  const _SummonChoice({required this.eyebrow, required this.title, required this.symbol, required this.action, required this.enabled, required this.onTap, this.gold = false});
  final String eyebrow, title, symbol, action;
  final bool enabled, gold;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: gold ? const Color(0xff283248) : const Color(0xff12233d), border: Border.all(color: gold ? const Color(0x79d8b769) : const Color(0x5c6887a0)), borderRadius: BorderRadius.circular(13)),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(eyebrow, style: const TextStyle(color: Color(0xffe9c880), fontSize: 8, letterSpacing: 1)), Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.w700))])),
            Text(symbol, style: const TextStyle(color: Color(0xffe1c07a), fontSize: 28)),
          ],
        ),
        const SizedBox(height: 5),
        _RuneButton(label: action, onTap: enabled ? onTap : null, gold: gold),
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
    required this.motion,
    required this.onMotion,
    required this.cloud,
  });
  final String name, avatar;
  final ValueChanged<String> onName, onAvatar;
  final VoidCallback onLanguage;
  final MotionPreference motion;
  final ValueChanged<MotionPreference> onMotion;
  final CloudAccountController? cloud;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 500;
      return Padding(
    padding: const EdgeInsets.fromLTRB(19, 10, 19, 7),
    child: Column(
      children: [
        if (!compact) ...[const _Eyebrow(compact: true), const SizedBox(height: 3)],
        const Text.rich(
          TextSpan(text: 'PLAYER ', children: [TextSpan(text: 'PROFILE', style: TextStyle(color: Color(0xfff5d28b)))]),
          style: TextStyle(fontFamily: 'Georgia', fontSize: 25, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: const RadialGradient(center: Alignment(0, -.5), colors: [Color(0xff365174), Color(0xff111e35)]), border: Border.all(color: const Color(0x6bc6aa65)), borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                Expanded(child: Image.asset('assets/idle/avatars/avatar_$avatar.webp', fit: BoxFit.contain)),
                const Text('RUNE ADVENTURER', style: TextStyle(color: Color(0xffe8c77d), fontSize: 8, letterSpacing: 1.3)),
                Text(name, style: const TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700)),
                const Text('LOCAL ACCOUNT · LEVEL 1', style: TextStyle(color: Color(0xffa6daff), fontSize: 8)),
              ],
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 5),
          const Align(alignment: Alignment.centerLeft, child: Text('CHOOSE YOUR AVATAR', style: TextStyle(fontFamily: 'Georgia', fontSize: 11, fontWeight: FontWeight.w700))),
          Wrap(
            children: [
              for (final id in ['player', 'guard', 'vassal', 'king'])
                IconButton(
                  onPressed: () => onAvatar(id),
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                  icon: CircleAvatar(
                    backgroundImage: AssetImage(
                      'assets/idle/avatars/avatar_$id.webp',
                    ),
                  ),
                ),
            ],
          ),
        ],
        TextField(
          maxLength: 20,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            labelText: 'DISPLAY NAME',
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: const Color(0xff0e1b35),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x5e7a89a6)), borderRadius: BorderRadius.circular(9)),
          ),
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
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9),
          ),
          if (cloud!.identity == null)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('cloud-google'),
                    onPressed: cloud!.signInGoogle,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('GOOGLE'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    key: const Key('cloud-email'),
                    onPressed: () => _emailDialog(context),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
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
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('GRAPHICS SETTINGS · ANIMATIONS', style: TextStyle(color: Color(0xffeac981), fontSize: 8, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            for (final value in MotionPreference.values) ...[
              Expanded(
                child: GestureDetector(
                  key: ValueKey('motion-${value.name}${motion == value ? '-selected' : ''}'),
                  onTap: () => onMotion(value),
                  child: Container(
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: motion == value ? const Color(0xff463c30) : const Color(0xff142541),
                      border: Border.all(color: motion == value ? const Color(0x88dabb77) : const Color(0x457484a1)),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      switch (value) {
                        MotionPreference.automatic => 'AUTOMATIC',
                        MotionPreference.full => 'FULL',
                        MotionPreference.reduced => 'REDUCED',
                      },
                      style: TextStyle(color: motion == value ? const Color(0xffffe3a4) : const Color(0xffacbfd6), fontSize: 7, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              if (value != MotionPreference.reduced) const SizedBox(width: 5),
            ],
          ],
        ),
        TextButton(style: TextButton.styleFrom(visualDensity: VisualDensity.compact), onPressed: onLanguage, child: const Text('LANGUAGE · ITALIANO', style: TextStyle(color: Color(0xffa6b9d0), fontSize: 9))),
      ],
    ),
  );
    },
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
