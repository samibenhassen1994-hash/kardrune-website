import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';

import 'game/catalog.dart';
import 'game/combat_rules.dart';
import 'game/game_rules.dart';
import 'game/summon_rules.dart';
import 'game/skill_catalog.dart';
import 'features/cards/deck_builder.dart';
import 'features/cards/card_stat_badges.dart';
import 'features/cards/skill_preview.dart';
import 'features/summon/summon_result.dart';
import 'features/summon/summon_screen.dart';
import 'features/summon/free_pull_notifications.dart';
import 'features/profile/cloud_account_controller.dart';
import 'features/pvp/live_match_coordinator.dart';
import 'features/pvp/live_pvp_arena.dart';
import 'features/pvp/flame_battle_audio.dart';
import 'features/pvp/arena_landing.dart';
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
    this.enableCloudBootstrap = true,
    this.nowMs,
  });
  final RandomRoll? random;
  final LocalSaveService? saveService;
  final CloudAccountController? cloudController;
  final LiveMatchCoordinator? liveMatchCoordinator;
  final AppUpdateController? updateController;
  final bool enableCloudBootstrap;
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
      enableCloudBootstrap: enableCloudBootstrap,
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
    required this.enableCloudBootstrap,
    required this.nowMs,
  });
  final RandomRoll random;
  final LocalSaveService? saveService;
  final CloudAccountController? cloudController;
  final LiveMatchCoordinator? liveMatchCoordinator;
  final AppUpdateController? updateController;
  final bool enableCloudBootstrap;
  final int Function() nowMs;
  @override
  State<IdleShell> createState() => _IdleShellState();
}

class _IdleShellState extends State<IdleShell> {
  static const _freeSummonKey = 'idle-free-standard-v1';
  static const _freeSummonWindowMs = 12 * 60 * 60 * 1000;
  static const _motionKey = 'idle-motion-preference-v1';
  static const _pvpRewardKey = 'idle-pvp-completed-rewards-v1';
  int tab = 0, shards = 1500, page = 0;
  String name = 'Runebearer', avatar = 'player';
  bool italian = false;
  final owned = <String>{};
  final attacks = <String, int>{}, crits = <String, int>{};
  final skills = <String, String>{};
  var active = 'sam:1',
      duels = 0,
      wins = 0,
      pulls = 0,
      practiceDay = '',
      practiceCount = 0;
  List<String> deck = [];
  Map<String, Object?>? _pendingDuplicate;
  bool _summonOpen = false;
  bool _snoozeDuplicate = false;
  bool _summonRequestPending = false;
  String? _pendingOnlineRollId;
  MotionPreference motion = MotionPreference.automatic;
  late final LocalSaveService? _saveService;
  CloudAccountController? _cloud;
  bool _cloudInitializing = false;
  String _cloudInitializationMessage = 'Connecting account services…';
  LiveMatchCoordinator? _pvp;
  Timer? _opponentIntroTimer;
  String? _introMatchId;
  bool _showOpponentIntro = false;
  late final FlameBattleAudio _flameAudio = createFlameBattleAudio();
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
    skills.addAll(save.skills);
    if (_saveService?.storage.read(CloudAccountController.lastUserKey) == null) {
      var migrated = false;
      for (final id in owned) {
        if (skills.containsKey(id)) continue;
        final stage = int.tryParse(id.split(':').last) ?? 1;
        skills[id] = SkillCatalog.roll(stage, widget.random(), widget.random()).id;
        migrated = true;
      }
      if (migrated) _saveService?.save(save.copyWith(skills: Map.of(skills)));
    }
    _pendingDuplicate = save.pendingDuplicate;
    if (_pendingDuplicate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resumeDuplicate();
      });
    }
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
    _pvp = widget.liveMatchCoordinator;
    _pvp?.addListener(_pvpChanged);
    _pvp?.onMatchFinished = _pvpFinished;
    _updates = widget.updateController ?? createDefaultUpdateController();
    _ownsUpdates = widget.updateController == null && _updates != null;
    _updates?.addListener(_updateChanged);
    _updates?.start();
    _cloud = widget.cloudController;
    if (_cloud != null) {
      _cloud!.addListener(_cloudChanged);
      _cloud!.start();
    } else if (_saveService != null && widget.enableCloudBootstrap) {
      _initializeCloud();
    } else {
      _cloudInitializationMessage =
          'Account services unavailable. Local progress is safe.';
    }
  }

  Future<void> _initializeCloud() async {
    if (_cloudInitializing || _cloud != null) return;
    setState(() {
      _cloudInitializing = true;
      _cloudInitializationMessage = 'Connecting account services…';
    });
    try {
      final controller = await createDefaultCloudController(
        _saveService!,
        _applyRemoteSave,
      );
      if (!mounted) return;
      if (controller == null) {
        setState(() {
          _cloudInitializationMessage =
              'Account services unavailable. Local progress is safe.';
        });
        return;
      }
      _cloud = controller;
      _ownsCloud = true;
      controller.addListener(_cloudChanged);
      controller.start();
      setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() {
          _cloudInitializationMessage =
              'Account services unavailable. Local progress is safe.';
        });
      }
    } finally {
      if (mounted) setState(() => _cloudInitializing = false);
    }
  }

  void _cloudChanged() {
    unawaited(notificationAccountChanged(_cloud?.identity?.uid ?? 'guest').then((_) async {
      await refreshFreePullNotifications(
        api: _cloud?.identity == null ? null : _cloud?.api,
        uid: _cloud?.identity?.uid,
      );
      if (mounted) setState(() {});
    }));
    if (_cloud?.identity != null && _pvp == null) {
      _pvp = LiveMatchCoordinator(
        repository: PvpRepository(_cloud!.api),
        connect: LivePvpSocket.connect,
      )..addListener(_pvpChanged);
      _pvp!.onMatchFinished = _pvpFinished;
      _loadCloudDeck();
    } else if (_cloud?.identity == null && _pvp != null) {
      _pvp!.removeListener(_pvpChanged);
      _pvp!.dispose();
      _pvp = null;
    }
    if (mounted) setState(() {});
  }

  void _pvpFinished(String matchId, String reason) {
    if (reason == 'completed' && _cloud?.identity != null) {
      _claimPvpReward(matchId);
      return;
    }
    if (reason == 'completed' && _saveService != null) {
      final storage = _saveService.storage;
      final claimed = <String>[];
      try {
        final decoded = jsonDecode(storage.read(_pvpRewardKey) ?? '[]');
        if (decoded is List) claimed.addAll(decoded.whereType<String>());
      } catch (_) {}
      if (!claimed.contains(matchId)) {
        claimed.add(matchId);
        // Durable marker is written before the reward. Demo wallet is local;
        // never award the same server match twice after re-entry.
        storage.write(_pvpRewardKey, jsonEncode(claimed.take(500).toList()));
        setState(() => shards += 100);
        _persist();
      }
    }
  }

  Future<void> _claimPvpReward(String matchId) async {
    final cloud = _cloud;
    if (cloud == null) return;
    final accountUid = cloud.identity?.uid;
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        if (cloud.state != CloudAccountState.synced) await cloud.loadCloud();
        final response = await cloud.api.post('/api/pvp/reward', {
          'matchId': matchId, 'revision': cloud.revision,
        });
        if (!mounted || cloud.identity?.uid != accountUid) return;
        cloud.applyServerSave(response);
        return;
      } catch (error) {
        if (attempt == 5) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('PvP reward pending. Cloud result: $error')));
          }
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
  }

  void _pvpChanged() {
    _updates?.setMatchActive(_pvp?.state == LiveMatchState.arena);
    final hand = _pvp?.arena.hand;
    if (_pvp?.state == LiveMatchState.arena && hand != null &&
        hand.round == 1 && hand.matchId != _introMatchId) {
      _introMatchId = hand.matchId;
      _showOpponentIntro = true;
      _opponentIntroTimer?.cancel();
      _opponentIntroTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _showOpponentIntro = false);
      });
    }
    if (_pvp?.state != LiveMatchState.arena) _showOpponentIntro = false;
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Deck saved locally · Cloud: $error')));
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
        owned
        ..clear()
        ..addAll(save.owned);
      attacks
        ..clear()
        ..addAll(save.attacks);
      crits
        ..clear()
        ..addAll(save.crits);
      skills
        ..clear()
        ..addAll(save.skills);
      _pendingDuplicate = save.pendingDuplicate;
      deck = _saveService?.loadDeck().where(owned.contains).toList() ?? [];
    });
  }

  @override
  void dispose() {
    _opponentIntroTimer?.cancel();
    _cloud?.removeListener(_cloudChanged);
    _pvp?.removeListener(_pvpChanged);
    _pvp?.dispose();
    _updates?.removeListener(_updateChanged);
    if (_ownsUpdates) _updates?.dispose();
    if (_ownsCloud) _cloud?.dispose();
    _flameAudio.dispose();
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
        skills: Map.of(skills),
        pendingDuplicate: _pendingDuplicate,
      ),
    );
    _cloud?.localChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_pvp?.state == LiveMatchState.arena) {
      return _motionWrap(
        _withUpdate(
          Stack(children: [
            Positioned.fill(child: LivePvpArena(
                  controller: _pvp!.arena,
                  audio: _flameAudio,
                  playerName: name,
                  playerAvatar: avatar,
                  onPlay: _pvp!.play,
                  onReady: _pvp!.ready,
                  onSurrender: _pvp!.close,
                  onComplete: () {
                    setState(() => tab = 0);
                    _pvp?.close();
                  },
            )),
            if (_showOpponentIntro && _pvp!.arena.hand != null)
              Positioned.fill(child: _OpponentIntro(
                name: _pvp!.arena.hand!.opponent,
                avatar: _pvp!.arena.hand!.opponentAvatar ?? 'player')),
          ]),
        ),
      );
    }
    return _motionWrap(
      _withUpdate(
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: tab == 0 || tab == 2,
          body: SafeArea(
            top: tab != 0 && tab != 2,
            bottom: tab != 0 && tab != 2,
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
                      if (tab != 0 && tab != 2) _Header(shards: shards, name: name, avatar: avatar),
                      Expanded(
                        child: IndexedStack(
                          index: tab,
                          children: [
                            ArenaLanding(
                              header: _Header(shards: shards, name: name, avatar: avatar, transparent: true),
                              hint: _cloud?.identity == null
                                  ? (italian ? 'ACCEDI DAL PROFILO PER GIOCARE' : 'SIGN IN FROM PROFILE TO PLAY LIVE')
                                  : deck.length < 3
                                      ? (italian ? 'AGGIUNGI TRE CARTE AL MAZZO' : 'ADD THREE CARDS TO YOUR DECK')
                                      : _pvp?.state == LiveMatchState.idle
                                          ? ''
                                          : _pvp?.message ?? '',
                              searching: _pvp?.state == LiveMatchState.connecting ||
                                  _pvp?.state == LiveMatchState.waiting,
                              onStart: _pvp != null && deck.length >= 3
                                  ? _pvp!.findMatch
                                  : () => setState(() => tab = _cloud?.identity == null ? 3 : 1),
                              onCancel: _pvp?.close,
                            ),
                            _Cards(
                              page: page,
                              title: italian ? 'CARTE' : 'CARDS',
                              owned: owned.toList(),
                              deck: deck,
                              active: active,
                              attacks: attacks,
                              crits: crits,
                              skills: skills,
                              onPage: (v) => setState(() => page = v),
                              onDeck: _saveDeck,
                              onSelect: (id) {
                                setState(() => active = id);
                                _persist();
                              },
                            ),
                            SummonScreen(
                              header: _Header(shards: shards, name: name, avatar: avatar,
                                transparent: true, onNotifications: () async {
                                  try {
                                    await toggleFreePullNotifications(
                                      api: _cloud?.identity == null ? null : _cloud?.api,
                                      uid: _cloud?.identity?.uid,
                                    );
                                    if (mounted) setState(() {});
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Notifications unavailable: $error')),
                                      );
                                    }
                                  }
                                }),
                              shards: shards,
                              active: tab == 2,
                              accountKey: _cloud?.identity?.uid ?? 'guest',
                              loadFreeStatus: _freeSummonStatus,
                              onSummon: _summon,
                              onFreeSummon: () => _summon(false, free: true),
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
                              onLanguage: () =>
                                  setState(() => italian = !italian),
                              motion: motion,
                              onMotion: (value) {
                                setState(() => motion = value);
                                _saveService?.storage.write(
                                  _motionKey,
                                  value.name,
                                );
                              },
                              cloud: _cloud,
                              cloudMessage: _cloudInitializationMessage,
                              onCloudRetry: _initializeCloud,
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
            arenaOverlay: tab == 0 || tab == 2,
            onTap: (value) => setState(() => tab = value),
          ),
        ),
      ),
    );
  }

  Widget _motionWrap(Widget child) {
    final media = MediaQuery.of(context);
    final reduce = switch (motion) {
      MotionPreference.automatic => false,
      MotionPreference.full => false,
      MotionPreference.reduced => true,
    };
    return MediaQuery(
      data: media.copyWith(disableAnimations: reduce),
      child: child,
    );
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

  Future<Map<String, dynamic>> _freeSummonStatus() async {
    if (_cloud?.identity != null) return _cloud!.api.get('/api/summon');
    final now = widget.nowMs();
    final used = _localFreeSummons(now);
    return {'available': 2 - used.length,
      'nextAt': used.isEmpty ? null : used.first + _freeSummonWindowMs,
      'serverNow': now};
  }

  List<int> _localFreeSummons(int now) {
    try {
      final decoded = jsonDecode(_saveService?.storage.read(_freeSummonKey) ?? '[]');
      if (decoded is List) {
        return decoded.whereType<int>()
          .where((v) => v > now - _freeSummonWindowMs && v <= now).toList()..sort();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _summon(bool featured, {bool free = false}) async {
    if (_pendingDuplicate != null) {
      _resumeDuplicate();
      return;
    }
    if (_summonOpen || _summonRequestPending || (!free && shards < SummonRules.cost(featured))) return;
    if (free && (featured || (await _freeSummonStatus())['available'] == 0)) {
      return;
    }
    if (!mounted) return;
    if (_cloud?.identity != null) {
      if (_cloud!.state != CloudAccountState.synced) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Review or sync your cloud save before summoning.')));
        return;
      }
      await _summonOnline(featured, free: free);
      return;
    }
    final stage = SummonRules.stageFor(featured, widget.random());
    final index = SummonRules.heroIndex(
      featured,
      widget.random(),
      widget.random(),
    );
    final hero = KardRuneCatalog.heroes[index];
    final id = '${hero.id}:$stage';
    final duplicate = owned.contains(id);
    final attack = CombatRules.rollAttack(widget.random);
    final crit = CombatRules.rollCrit(widget.random);
    final skill = SkillCatalog.roll(stage, widget.random(), widget.random());
    setState(() {
      if (!free) { shards -= SummonRules.cost(featured); }
      pulls++;
      if (duplicate) {
        _pendingDuplicate = {'id': id, 'attack': attack, 'crit': crit,
          'skillId': skill.id, 'skillVersion': SkillCatalog.version};
      } else {
        owned.add(id);
        attacks[id] = attack;
        crits[id] = crit;
        skills[id] = skill.id;
      }
    });
    if (free) {
      _saveService?.storage.write(_freeSummonKey,
        jsonEncode([..._localFreeSummons(widget.nowMs()), widget.nowMs()]));
    }
    _persist();
    _reveal(id, attack, crit, duplicate, skill.id);
  }

  String _newRollId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _summonOnline(bool featured, {bool free = false}) async {
    final cloud = _cloud!;
    final accountUid = cloud.identity?.uid;
    _summonRequestPending = true;
    final rollId = _pendingOnlineRollId ??= _newRollId();
    try {
      if (!await cloud.prepareServerMutation()) throw StateError('Cloud save needs review');
      final result = await cloud.api.post('/api/summon', {
        'featured': featured, 'free': free,
        'revision': cloud.revision, 'rollId': rollId,
      });
      if (!mounted || cloud.identity?.uid != accountUid) return;
      cloud.applyServerSave(result);
      _pendingOnlineRollId = null;
      if (result['card'] is! Map) return;
      final card = Map<String, dynamic>.from(result['card'] as Map);
      _reveal(card['id'] as String, card['attack'] as int,
        card['crit'] as int, result['duplicate'] == true, card['skillId'] as String);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Summon unavailable: $error')));
      }
    } finally {
      _summonRequestPending = false;
    }
  }

  void _resumeDuplicate() {
    if (_pendingDuplicate == null || _summonOpen) return;
    final p = _pendingDuplicate!;
    _reveal(p['id'] as String, p['attack'] as int, p['crit'] as int, true,
      p['skillId'] as String?);
  }

  void _reveal(String id, int attack, int crit, bool duplicate, String? skillId) {
    if (!mounted || _summonOpen) return;
    final parts = id.split(':');
    final stage = int.parse(parts.last);
    final hero = KardRuneCatalog.heroes.firstWhere((h) => h.id == parts.first);
    _summonOpen = true;
    void decide(BuildContext dialogContext, bool replace) {
      if (_pendingDuplicate == null) return;
      final rollId = _pendingDuplicate!['rollId'];
      if (rollId is String) {
        if (_cloud?.identity == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sign in to resolve this saved online summon.')));
        } else {
          _decideOnline(dialogContext, rollId, replace);
        }
        return;
      }
      final decision = SummonRules.resolveDuplicate(replace: replace);
      setState(() {
        if (decision.useNewStats) {
          attacks[id] = attack;
          crits[id] = crit;
          if (skillId != null) skills[id] = skillId;
        } else {
          shards += decision.refund;
        }
        _pendingDuplicate = null;
      });
      _persist();
      Navigator.of(dialogContext).pop();
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SummonResult(
        heroName: hero.name,
        stage: stage,
        asset: hero.cardAsset(hero.stages[stage - 1]),
        hp: CombatRules.hpForStage(stage),
        oldAttack: duplicate ? attacks[id] : null,
        oldCrit: duplicate ? crits[id] : null,
        newAttack: attack,
        newCrit: crit,
        newSkillId: skillId,
        oldSkillId: skills[id],
        onKeep: () => decide(dialogContext, false),
        onReplace: () => decide(dialogContext, true),
        onContinue: () => Navigator.of(dialogContext).pop(),
        onLater: duplicate ? () {
          _snoozeDuplicate = true;
          Navigator.of(dialogContext).pop();
        } : null,
      ),
    ).whenComplete(() {
      _summonOpen = false;
      if (mounted && _pendingDuplicate != null && !_snoozeDuplicate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _resumeDuplicate();
        });
      }
      _snoozeDuplicate = false;
    });
  }

  Future<void> _decideOnline(BuildContext dialogContext, String rollId, bool replace) async {
    if (_summonRequestPending || _cloud?.state != CloudAccountState.synced) return;
    _summonRequestPending = true;
    final cloud = _cloud!;
    final accountUid = cloud.identity?.uid;
    try {
      if (!await cloud.prepareServerMutation()) throw StateError('Cloud save needs review');
      final response = await cloud.api.post('/api/summon/decision', {
        'rollId': rollId, 'replace': replace, 'revision': cloud.revision,
      });
      if (!mounted || cloud.identity?.uid != accountUid) return;
      cloud.applyServerSave(response);
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Decision unavailable: $error')));
      }
    } finally {
      _summonRequestPending = false;
    }
  }
}

class _OpponentIntro extends StatelessWidget {
  const _OpponentIntro({required this.name, required this.avatar});
  final String name, avatar;

  @override
  Widget build(BuildContext context) {
    final safeAvatar = const ['player', 'guard', 'vassal', 'king'].contains(avatar)
        ? avatar : 'player';
    return ColoredBox(color: const Color(0xff080e20), child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('YOUR OPPONENT', style: TextStyle(color: Color(0xffffd78c),
          fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 20),
        Container(width: 120, height: 120, padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: const Color(0xffff8075), width: 3),
            boxShadow: const [BoxShadow(color: Color(0xaaff493d), blurRadius: 24)]),
          child: CircleAvatar(backgroundImage: AssetImage(
            'assets/idle/avatars/avatar_$safeAvatar.webp'))),
        const SizedBox(height: 16),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xffffe4b3), fontFamily: 'Georgia',
            fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(
          color: Color(0xffffd78c), strokeWidth: 2.5)),
        const SizedBox(height: 10),
        const Text('ENTERING THE ARENA', style: TextStyle(
          color: Color(0xffb7c9df), fontSize: 11, letterSpacing: 1.4)),
      ]),
    ));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.shards, required this.name, required this.avatar,
    this.transparent = false, this.onNotifications});
  final int shards;
  final String name, avatar;
  final bool transparent;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    final safeAvatar = const ['player', 'guard', 'vassal', 'king'].contains(avatar)
        ? avatar : 'player';
    return Container(
      height: transparent ? 68 : 76,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: transparent ? const Color(0x99071120) : const Color(0xdd071226),
        border: const Border(bottom: BorderSide(color: Color(0x65d2b780))),
      ),
      child: Row(children: [
        Container(
          width: 55, height: 55,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(colors: [
              Color(0xff7b391c), Color(0xffffe7a4), Color(0xffba692b),
              Color(0xffffe7a4), Color(0xff7b391c),
            ]),
            border: Border.all(color: const Color(0xffffeab3), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0xccd69339), blurRadius: 12)],
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: const Color(0xff5b2c18), width: 2)),
            child: CircleAvatar(backgroundImage: AssetImage(
              'assets/idle/avatars/avatar_$safeAvatar.webp')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xffffe1a6), fontFamily: 'Georgia',
            fontWeight: FontWeight.w800, fontSize: 16,
            shadows: [Shadow(color: Colors.black, blurRadius: 6)]))),
        if (onNotifications != null) IconButton(
          tooltip: 'Free Summon notifications',
          onPressed: onNotifications,
          icon: Icon(freePullNotificationsGranted
            ? Icons.notifications_active_outlined : Icons.notifications_outlined,
            color: const Color(0xffffd982)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0x99132132),
            border: Border.all(color: const Color(0x99d5b477)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('◆', style: TextStyle(color: Color(0xff72d8ff))),
            const SizedBox(width: 5),
            Text(shards.toString().replaceAllMapped(
              RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','),
              style: const TextStyle(color: Color(0xffffe1a6), fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }
}
class _RuneNavigation extends StatelessWidget {
  const _RuneNavigation({
    required this.current,
    required this.italian,
    required this.arenaOverlay,
    required this.onTap,
  });
  final int current;
  final bool italian;
  final bool arenaOverlay;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      (Icons.shield_outlined, 'ARENA'),
      (Icons.style_outlined, italian ? 'CARTE' : 'CARDS'),
      (Icons.auto_awesome_outlined, italian ? 'EVOCA' : 'SUMMON'),
      (Icons.person_outline, italian ? 'PROFILO' : 'PROFILE'),
    ];
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: arenaOverlay ? const Color(0xc2091426) : const Color(0xf5091426),
        border: const Border(top: BorderSide(color: Color(0x59bca46c))),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24)],
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
                              child: Divider(
                                color: Color(0xfff9d892),
                                thickness: 2,
                                height: 2,
                              ),
                            ),
                          ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              items[i].$1,
                              size: 23,
                              color: current == i
                                  ? const Color(0xfff9d892)
                                  : const Color(0xff91a1b9),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              items[i].$2,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: current == i
                                    ? const Color(0xfff9d892)
                                    : const Color(0xff91a1b9),
                              ),
                            ),
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

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(width: 27, child: Divider(color: Color(0x5ce8bd66))),
      const SizedBox(width: 10),
      Text(
        'ARENA OF THE RUNES',
        style: TextStyle(
          color: const Color(0xffe7bf68),
          fontSize: compact ? 8 : 9,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(width: 10),
      const SizedBox(width: 27, child: Divider(color: Color(0x5ce8bd66))),
    ],
  );
}

class _RuneButton extends StatelessWidget {
  const _RuneButton({
    required this.label,
    required this.onTap,
  });
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: GestureDetector(
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
            gradient: const LinearGradient(
              colors: [Color(0xff1e344f), Color(0xff13213a)],
            ),
            border: Border.all(color: const Color(0x66c4aa66)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xfff7dba5),
              fontSize: 10,
              letterSpacing: .8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Cards extends StatefulWidget {
  const _Cards({
    required this.page,
    required this.title,
    required this.owned,
    required this.deck,
    required this.active,
    required this.attacks,
    required this.crits,
    required this.skills,
    required this.onPage,
    required this.onDeck,
    required this.onSelect,
  });
  final int page;
  final String title;
  final List<String> owned;
  final List<String> deck;
  final String active;
  final Map<String, int> attacks, crits;
  final Map<String, String> skills;
  final ValueChanged<int> onPage;
  final ValueChanged<List<String>> onDeck;
  final ValueChanged<String> onSelect;
  @override
  State<_Cards> createState() => _CardsState();
}

class _CardsState extends State<_Cards> {
  final TextEditingController query = TextEditingController();
  String ownership = 'owned', rarity = 'all', stageFilter = 'all', skillFilter = 'all', sort = 'atk';
  bool expandedFilters = false;
  String get title => widget.title;
  List<String> get owned => widget.owned;
  List<String> get deck => widget.deck;
  String get active => widget.active;
  Map<String, int> get attacks => widget.attacks;
  Map<String, int> get crits => widget.crits;
  Map<String, String> get skills => widget.skills;
  ValueChanged<List<String>> get onDeck => widget.onDeck;
  ValueChanged<String> get onSelect => widget.onSelect;
  @override
  void initState() {super.initState(); query.addListener(_changed);}
  void _changed() {if(mounted) setState((){});}
  @override
  void dispose() {query.removeListener(_changed);query.dispose();super.dispose();}
  void reset() {query.clear();setState(() {
    ownership='owned';rarity='all';stageFilter='all';skillFilter='all';sort='atk';expandedFilters=false;
  });}
  String _t(String it, String en) => title == 'CARTE' ? it : en;
  @override
  Widget build(BuildContext context) {
    final all = [for(final h in KardRuneCatalog.heroes)
      for(var s=1;s<=3;s++) MapEntry(h,s)];
    final found = all.where((card) {
      final id = '${card.key.id}:${card.value}';
      final isOwned = owned.contains(id);
      final skill = SkillCatalog.byId(skills[id]);
      if(ownership=='owned'&&!isOwned || ownership=='missing'&&isOwned)return false;
      if(stageFilter!='all'&&card.value.toString()!=stageFilter)return false;
      if(rarity!='all'&&skill?.rarity!=rarity)return false;
      if(skillFilter!='all'&&skill?.id!=skillFilter)return false;
      final q=query.text.trim().toLowerCase();
      return q.isEmpty || card.key.name.toLowerCase().contains(q)
        || (skill?.name.toLowerCase().contains(q)??false)
        || (skill?.description.toLowerCase().contains(q)??false);
    }).toList();
    found.sort((a,b){
      final ai='${a.key.id}:${a.value}',bi='${b.key.id}:${b.value}';
      final ao=owned.contains(ai),bo=owned.contains(bi);
      if(ao!=bo)return ao?-1:1;
      final result=switch(sort){
        'atk'=>(attacks[bi]??-1).compareTo(attacks[ai]??-1),
        'crit'=>(crits[bi]??-1).compareTo(crits[ai]??-1),
        'stage'=>b.value.compareTo(a.value),
        'rarity'=>SkillCatalog.rarities.indexOf(SkillCatalog.byId(skills[bi])?.rarity??'common')
          .compareTo(SkillCatalog.rarities.indexOf(SkillCatalog.byId(skills[ai])?.rarity??'common')),
        _=>a.key.name.compareTo(b.key.name),
      };
      return result!=0?result:ai.compareTo(bi);
    });
    return Padding(padding:const EdgeInsets.fromLTRB(12,8,12,5),
      child:Column(children:[
        Row(children:[
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(title=='CARTE'?'LE TUE CARTE':'YOUR CARDS',style:const TextStyle(
              fontFamily:'Georgia',fontSize:23,fontWeight:FontWeight.w800,color:Color(0xffffd892))),
            Text('${owned.length}/27 ${_t('possedute','owned')} · ${deck.length}/9 ${_t('nel mazzo','in deck')}',
              style:const TextStyle(color:Color(0xffaabbd2),fontSize:11)),
          ])),
          OutlinedButton.icon(key:const Key('collection-edit-deck'),
            onPressed:()=>_openDeck(context),
            icon:const Icon(Icons.style_outlined,size:16),label:Text(_t('MODIFICA MAZZO','EDIT DECK')),
            style:OutlinedButton.styleFrom(foregroundColor:const Color(0xffffd892),
              side:const BorderSide(color:Color(0xffbba069)),
              textStyle:const TextStyle(fontSize:10,fontWeight:FontWeight.w900))),
        ]),
        const SizedBox(height:8),
        TextField(key:const Key('collection-search'),controller:query,
          style:const TextStyle(color:Colors.white,fontSize:14),
          decoration:InputDecoration(isDense:true,filled:true,fillColor:const Color(0xff162741),
            prefixIcon:const Icon(Icons.search,color:Color(0xffffd892)),
            suffixIcon:query.text.isNotEmpty?IconButton(onPressed:query.clear,
              icon:const Icon(Icons.close,color:Colors.white)):null,
            hintText:_t('Cerca personaggio o abilità...','Search hero or skill...'),hintStyle:const TextStyle(color:Color(0xffb4c4d6)),
            contentPadding:const EdgeInsets.symmetric(vertical:11),
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)))),
        const SizedBox(height:6),
        Row(children:[
          for(final item in [
              ('owned',_t('POSSEDUTE','OWNED')),
              ('all',_t('TUTTE','ALL')),
              ('missing',_t('BLOCCATE','LOCKED')),
            ])
            Padding(padding:const EdgeInsets.only(right:5),child:ChoiceChip(
              label:Text(item.$2),selected:ownership==item.$1,showCheckmark:false,
              onSelected:(_)=>setState(()=>ownership=item.$1),
              visualDensity:VisualDensity.compact,
              labelStyle:const TextStyle(fontSize:9,color:Colors.white,fontWeight:FontWeight.bold),
              selectedColor:const Color(0xff795d2c),backgroundColor:const Color(0xff1b2c46))),
          const Spacer(),
          IconButton(key:const Key('collection-toggle-filters'),tooltip:_t('Filtri avanzati','Advanced filters'),
            onPressed:()=>setState(()=>expandedFilters=!expandedFilters),
            icon:Icon(expandedFilters?Icons.tune:Icons.filter_list,color:const Color(0xffffd892))),
        ]),
        if(expandedFilters)...[
          Row(children:[
            Expanded(child:_dropdown(stageFilter,[
              ('all',_t('TUTTI GLI STAGE','ALL STAGES')),('1','STAGE 1'),('2','STAGE 2'),('3','STAGE 3')],
              (v)=>setState(()=>stageFilter=v))),
            const SizedBox(width:6),
            Expanded(child:_dropdown(rarity,[
              ('all',_t('TUTTE LE RARITÀ','ALL RARITIES')),
              ('common',_t('COMUNE','COMMON')),
              ('uncommon',_t('NON COMUNE','UNCOMMON')),
              ('rare',_t('RARA','RARE')),
              ('epic',_t('EPICA','EPIC')),
              ('legendary',_t('LEGGENDARIA','LEGENDARY')),
              ('ultra','ULTRA')],
              (v)=>setState((){rarity=v;skillFilter='all';}))),
          ]),
          const SizedBox(height:5),
          _dropdown(skillFilter,[
            ('all',_t('TUTTE LE ABILITÀ','ALL SKILLS')),
            for(final skill in SkillCatalog.skills)
              if(rarity=='all'||skill.rarity==rarity)(skill.id,skill.name.toUpperCase()),
          ],(v)=>setState(()=>skillFilter=v)),
        ],
        Row(children:[
          Expanded(child:_dropdown(sort,[
            ('atk',_t('ATK ALTO → BASSO','ATK HIGH → LOW')),
            ('crit',_t('CRIT ALTO → BASSO','CRIT HIGH → LOW')),
            ('rarity',_t('RARITÀ ABILITÀ','SKILL RARITY')),
            ('stage',_t('STAGE ALTO → BASSO','STAGE HIGH → LOW')),
            ('name',_t('NOME A–Z','NAME A–Z'))],
            (v)=>setState(()=>sort=v))),
          const SizedBox(width:6),
          Text('${found.length} ${_t('RISULTATI','RESULTS')}',style:const TextStyle(fontSize:10,color:Color(0xffb9cadf))),
          IconButton(onPressed:reset,tooltip:_t('Azzera filtri','Reset filters'),visualDensity:VisualDensity.compact,
            icon:const Icon(Icons.restart_alt,color:Color(0xffffd892),size:20)),
        ]),
        const SizedBox(height:4),
        Expanded(child:found.isEmpty?Center(child:TextButton(
          onPressed:reset,child:Text(_t('Nessuna carta trovata · AZZERA FILTRI','No cards found · RESET FILTERS'))))
          :GridView.builder(
            key:const Key('collection-scroll-grid'),
            keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
            padding:const EdgeInsets.only(bottom:14),
            gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:2,childAspectRatio:.68,mainAxisSpacing:9,crossAxisSpacing:9),
            itemCount:found.length,
            itemBuilder:(context,index){
              final card=found[index];
              return _card(context,card.key,card.value);
            })),
      ]));
  }

  Widget _dropdown(String value,List<(String,String)> options,ValueChanged<String> change)=>
    Container(padding:const EdgeInsets.symmetric(horizontal:8),
      decoration:BoxDecoration(color:const Color(0xff172a45),
        border:Border.all(color:const Color(0xff586880)),
        borderRadius:BorderRadius.circular(7)),
      child:DropdownButtonHideUnderline(child:DropdownButton<String>(
        value:value,isExpanded:true,isDense:true,dropdownColor:const Color(0xff182940),
        style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w800),
        items:[for(final item in options)DropdownMenuItem<String>(
          value:item.$1,child:Text(item.$2,maxLines:1,overflow:TextOverflow.ellipsis))],
        onChanged:(v){if(v!=null)change(v);},
      )));

  void _openDeck(BuildContext context) => showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: const Color(0xff0c1528),
      child: SafeArea(
        child: Column(children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xff101e37),
              border: Border(bottom: BorderSide(color: Color(0xffb89a61))),
            ),
            child: Row(children: [
              const SizedBox(width: 12),
              Expanded(child: Text(
                _t('MODIFICA IL MAZZO', 'EDIT MY DECK'),
                style: const TextStyle(
                  fontFamily: 'Georgia', fontSize: 21,
                  color: Color(0xfff5d28b), fontWeight: FontWeight.w800),
              )),
              IconButton(
                key: const Key('close-deck-editor'),
                tooltip: _t('Chiudi', 'Close'),
                onPressed: () => Navigator.maybePop(dialogContext),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 8),
            ]),
          ),
          Expanded(child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: DeckBuilder(
                italian: title == 'CARTE',
                owned: owned,
                initial: deck,
                attacks: attacks,
                crits: crits,
                skills: skills,
                onSave: (value) {
                  onDeck(value);
                  Navigator.pop(dialogContext);
                },
              ),
            ),
          )),
        ]),
      ),
    ),
  );

  Widget _card(BuildContext context, dynamic hero, int stage) {
    final id = '${hero.id}:$stage',
        isOwned = owned.contains(id),
        isSelected = active == id;
    return Semantics(
      label: '${hero.name} Stage $stage',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        key: ValueKey('collection-card-$id'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isOwned) onSelect(id);
          _openCard(context, hero, stage, isOwned);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xff111e35),
            border: Border.all(
              color: isSelected
                  ? const Color(0xff7fd7c3)
                  : const Color(0x62c3a669),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? const [BoxShadow(color: Color(0x557fd7c3), blurRadius: 8)]
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CharacterCardArt(
                key: ValueKey('card-frame-$id'),
                asset: hero.cardAsset(hero.stages[stage - 1]),
                artKey: ValueKey('card-art-$id'),
                statsKey: ValueKey('card-stats-$id'),
                hp: CombatRules.hpForStage(stage),
                attack: isOwned ? attacks[id] : null,
                crit: isOwned ? crits[id] : null,
                skillId: isOwned ? skills[id] : null,
                imageOpacity: isOwned ? 1 : .28,
              ),
              if (!isOwned)
                const IgnorePointer(
                  child: Center(
                    child: Text(
                      '?',
                      style: TextStyle(
                        fontSize: 28,
                        color: Color(0xfff5d28b),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCard(BuildContext context, dynamic hero, int stage, bool isOwned) {
    final id = '${hero.id}:$stage';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: ValueKey('card-details-$id'),
        backgroundColor: const Color(0xff101d36),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xffd5ad62)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 470,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * .94),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${hero.name.toString().toUpperCase()} · STAGE $stage',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    color: Color(0xfff5d28b),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: CharacterCardArt(
                    key: ValueKey('card-detail-frame-$id'),
                    asset: hero.cardAsset(hero.stages[stage - 1]),
                    hp: CombatRules.hpForStage(stage),
                    attack: isOwned ? attacks[id] : null,
                    crit: isOwned ? crits[id] : null,
                    skillId: isOwned ? skills[id] : null,
                  ),
                ),
                const SizedBox(height: 12),
                if (isOwned) if (SkillCatalog.byId(skills[id]) case final skill?) ...[
                  Center(child: SkillRarityBadge(skill: skill)),
                  const SizedBox(height: 4),
                  Text(skill.description, textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xffd2dced), fontSize: 11)),
                  Text('${skill.trigger} · ${skill.limit}', textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xffa9bdd4), fontSize: 10)),
                  Text('Stage $stage: ${(SkillCatalog.weights[stage]![SkillCatalog.rarities.indexOf(skill.rarity)] / 50).toStringAsFixed(2)}% per pull',
                    style: const TextStyle(color: Color(0xffa9bdd4), fontSize: 10)),
                  SkillPreviewButton(skill: skill),
                  const SizedBox(height: 8),
                ],
                Text(
                  isOwned ? (active == id ? 'ACTIVE CHAMPION' : 'OWNED CARD') : 'NOT COLLECTED',
                  style: TextStyle(
                    color: isOwned
                        ? const Color(0xff7fd7c3)
                        : const Color(0xffa0b0c8),
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _RuneButton(
                  label: 'CLOSE',
                  onTap: () => Navigator.pop(dialogContext),
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }
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
    required this.cloudMessage,
    required this.onCloudRetry,
  });
  final String name, avatar;
  final ValueChanged<String> onName, onAvatar;
  final VoidCallback onLanguage;
  final MotionPreference motion;
  final ValueChanged<MotionPreference> onMotion;
  final CloudAccountController? cloud;
  final String cloudMessage;
  final VoidCallback onCloudRetry;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 500;
      return Padding(
        padding: const EdgeInsets.fromLTRB(19, 10, 19, 7),
        child: Column(
          children: [
            if (!compact) ...[
              const _Eyebrow(compact: true),
              const SizedBox(height: 3),
            ],
            const Text.rich(
              TextSpan(
                text: 'PLAYER ',
                children: [
                  TextSpan(
                    text: 'PROFILE',
                    style: TextStyle(color: Color(0xfff5d28b)),
                  ),
                ],
              ),
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(0, -.5),
                    colors: [Color(0xff365174), Color(0xff111e35)],
                  ),
                  border: Border.all(color: const Color(0x6bc6aa65)),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Image.asset(
                        'assets/idle/avatars/avatar_$avatar.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const Text(
                      'RUNE ADVENTURER',
                      style: TextStyle(
                        color: Color(0xffe8c77d),
                        fontSize: 8,
                        letterSpacing: 1.3,
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'LOCAL ACCOUNT · LEVEL 1',
                      style: TextStyle(color: Color(0xffa6daff), fontSize: 8),
                    ),
                  ],
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 5),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CHOOSE YOUR AVATAR',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Wrap(
                children: [
                  for (final id in ['player', 'guard', 'vassal', 'king'])
                    IconButton(
                      onPressed: () => onAvatar(id),
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints.tightFor(
                        width: 38,
                        height: 38,
                      ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0x5e7a89a6)),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onSubmitted: onName,
            ),
            Container(
              key: const Key('account-section'),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 5, bottom: 5),
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 3),
              decoration: BoxDecoration(
                color: const Color(0xcc0e1b35),
                border: Border.all(color: const Color(0x668ca7c5)),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ACCOUNT',
                      style: TextStyle(
                        color: Color(0xffeac981),
                        fontSize: 8,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (cloud == null) ...[
                    Text(
                      cloudMessage,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9),
                    ),
                    TextButton(
                      key: const Key('cloud-retry'),
                      onPressed: onCloudRetry,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('RETRY'),
                    ),
                  ] else ...[
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
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('GOOGLE'),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              key: const Key('cloud-email'),
                              onPressed: () => _emailDialog(context),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('EMAIL'),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cloud!.identity?.displayName case final name?)
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            ),
                          if (cloud!.state == CloudAccountState.review) ...[
                            Row(
                              children: [
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
                            ),
                          ],
                          TextButton.icon(
                            key: const Key('cloud-logout'),
                            onPressed: cloud!.signOut,
                            icon: const Icon(Icons.logout, size: 14),
                            label: const Text('LOGOUT'),
                          ),
                          if (cloud!.hasGuestBackup)
                            TextButton(
                              onPressed: cloud!.restoreGuestBackup,
                              child: const Text('RESTORE OFFLINE SAVE'),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'GRAPHICS SETTINGS · ANIMATIONS',
                style: TextStyle(
                  color: Color(0xffeac981),
                  fontSize: 8,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                for (final value in MotionPreference.values) ...[
                  Expanded(
                    child: GestureDetector(
                      key: ValueKey(
                        'motion-${value.name}${motion == value ? '-selected' : ''}',
                      ),
                      onTap: () => onMotion(value),
                      child: Container(
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: motion == value
                              ? const Color(0xff463c30)
                              : const Color(0xff142541),
                          border: Border.all(
                            color: motion == value
                                ? const Color(0x88dabb77)
                                : const Color(0x457484a1),
                          ),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          switch (value) {
                            MotionPreference.automatic => 'AUTOMATIC',
                            MotionPreference.full => 'FULL',
                            MotionPreference.reduced => 'REDUCED',
                          },
                          style: TextStyle(
                            color: motion == value
                                ? const Color(0xffffe3a4)
                                : const Color(0xffacbfd6),
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (value != MotionPreference.reduced)
                    const SizedBox(width: 5),
                ],
              ],
            ),
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: onLanguage,
              child: const Text(
                'LANGUAGE · ITALIANO',
                style: TextStyle(color: Color(0xffa6b9d0), fontSize: 9),
              ),
            ),
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
                key: const Key('cloud-register-mode'),
                value: register,
                onChanged: (value) =>
                    setDialogState(() => register = value ?? false),
                title: const Text('CREATE ACCOUNT'),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('cloud-forgot-password'),
              onPressed: () async {
                final value = email.text.trim();
                if (!value.contains('@')) return;
                await cloud!.sendPasswordReset(value);
              },
              child: const Text('FORGOT PASSWORD'),
            ),
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
                final success = await cloud!.signInEmail(
                  email.text.trim(),
                  password.text,
                  register: register,
                );
                if (success && dialogContext.mounted) {
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
