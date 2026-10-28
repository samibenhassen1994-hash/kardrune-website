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
import 'features/profile/cloud_account_controller.dart';
import 'features/pvp/live_match_coordinator.dart';
import 'features/pvp/live_pvp_arena.dart';
import 'features/pvp/flame_pvp_demo.dart';
import 'features/pvp/flame_battle_audio.dart';
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
  static const _motionKey = 'idle-motion-preference-v1';
  static const _pvpRewardKey = 'idle-pvp-completed-rewards-v1';
  int tab = 0, shards = 1500, page = 0, rewardsLeft = 10;
  String name = 'Runebearer', avatar = 'player';
  String battleStatus = '';
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
  String? _pendingPracticeRollId;
  MotionPreference motion = MotionPreference.automatic;
  late final LocalSaveService? _saveService;
  CloudAccountController? _cloud;
  bool _cloudInitializing = false;
  String _cloudInitializationMessage = 'Connecting account services…';
  LiveMatchCoordinator? _pvp;
  bool _showFlameDemo = false;
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
    rewardsLeft = GameRules.dailyRewardLimit - practiceCount;
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
            setState(() => battleStatus =
              'PvP reward pending. Cloud result: $error');
          }
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
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
      skills
        ..clear()
        ..addAll(save.skills);
      _pendingDuplicate = save.pendingDuplicate;
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
    if (_showFlameDemo) {
      return _motionWrap(
        FlamePvpDemo(
          audio: _flameAudio,
          onBack: () => setState(() {
            _showFlameDemo = false;
            tab = 0;
          }),
        ),
      );
    }
    if (_pvp?.state == LiveMatchState.arena) {
      return _motionWrap(
        _withUpdate(
          LivePvpArena(
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
          ),
        ),
      );
    }
    return _motionWrap(
      _withUpdate(
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
                              activeCard: active,
                              attack: attacks[active],
                              crit: crits[active],
                              skillId: skills[active],
                              rewardsLeft: rewardsLeft,
                              status: battleStatus,
                              onStart: _train,
                              onLive: _pvp?.findMatch,
                              liveStatus: _pvp?.message,
                              canLive: _pvp != null && deck.length >= 3,
                              onFlameDemo: () {
                                _flameAudio.unlock();
                                setState(() => _showFlameDemo = true);
                              },
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

  void _train() {
    if (_cloud?.identity != null) {
      if (_cloud!.state != CloudAccountState.synced) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Review or sync your cloud save before training.')));
        return;
      }
      _trainOnline();
      return;
    }
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

  Future<void> _trainOnline() async {
    if (_summonRequestPending) return;
    final cloud = _cloud!;
    final accountUid = cloud.identity?.uid;
    _summonRequestPending = true;
    final rollId = _pendingPracticeRollId ??= _newRollId();
    try {
      if (!await cloud.prepareServerMutation()) throw StateError('Cloud save needs review');
      final result = await cloud.api.post('/api/practice', {
        'rollId': rollId, 'revision': cloud.revision,
      });
      if (!mounted || cloud.identity?.uid != accountUid) return;
      cloud.applyServerSave(result);
      _pendingPracticeRollId = null;
      setState(() => battleStatus =
        '${result['win'] == true ? 'VICTORY' : 'DEFEAT'} · +${result['reward']} SHARDS');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Practice unavailable: $error')));
      }
    } finally {
      _summonRequestPending = false;
    }
  }

  void _summon(bool featured) {
    if (_pendingDuplicate != null) {
      _resumeDuplicate();
      return;
    }
    if (_summonOpen || _summonRequestPending || shards < SummonRules.cost(featured)) return;
    if (_cloud?.identity != null) {
      if (_cloud!.state != CloudAccountState.synced) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Review or sync your cloud save before summoning.')));
        return;
      }
      _summonOnline(featured);
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
      shards -= SummonRules.cost(featured);
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

  Future<void> _summonOnline(bool featured) async {
    final cloud = _cloud!;
    final accountUid = cloud.identity?.uid;
    _summonRequestPending = true;
    final rollId = _pendingOnlineRollId ??= _newRollId();
    try {
      if (!await cloud.prepareServerMutation()) throw StateError('Cloud save needs review');
      final result = await cloud.api.post('/api/summon', {
        'featured': featured, 'revision': cloud.revision, 'rollId': rollId,
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
  const _RuneNavigation({
    required this.current,
    required this.italian,
    required this.onTap,
  });
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

class _Tournament extends StatelessWidget {
  const _Tournament({
    required this.activeCard,
    this.attack,
    this.crit,
    this.skillId,
    required this.rewardsLeft,
    required this.status,
    required this.onStart,
    required this.onLive,
    required this.liveStatus,
    required this.canLive,
    required this.onFlameDemo,
  });
  final int rewardsLeft;
  final String activeCard;
  final int? attack, crit;
  final String? skillId;
  final String status;
  final VoidCallback onStart;
  final VoidCallback? onLive;
  final String? liveStatus;
  final bool canLive;
  final VoidCallback onFlameDemo;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxHeight < 560;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 13 : 19,
          compact ? 8 : 16,
          compact ? 13 : 19,
          7,
        ),
        child: Column(
          children: [
            _Eyebrow(compact: compact),
            SizedBox(height: compact ? 3 : 7),
            Text.rich(
              const TextSpan(
                text: 'TOURNAMENT ',
                children: [
                  TextSpan(
                    text: 'PvP',
                    style: TextStyle(color: Color(0xfff5d28b)),
                  ),
                ],
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
                style: TextStyle(
                  color: Color(0xffb9c5d8),
                  fontSize: 12,
                  height: 1.35,
                ),
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
                      Text(
                        'YOUR NEXT BATTLE',
                        style: TextStyle(
                          color: Color(0xffeac981),
                          fontSize: 8,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'PRACTICE ARENA',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x331c5478),
                    border: Border.all(color: const Color(0x6678c5ff)),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'SOLO DEMO',
                    style: TextStyle(
                      color: Color(0xffa6daff),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 9),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 120),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 11,
                  vertical: compact ? 5 : 10,
                ),
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xff203958), Color(0xff0b172f)],
                  ),
                  border: Border.all(color: const Color(0x45d3ad5b)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _HomeCombatant(
                        id: activeCard.split(':').first,
                        stage: int.tryParse(activeCard.split(':').last) ?? 1,
                        attack: attack,
                        crit: crit,
                        skillId: skillId,
                        label: '${activeCard.split(':').first.toUpperCase()} · S${activeCard.split(':').last}',
                        subtitle: 'YOUR HERO',
                        compact: compact,
                      ),
                    ),
                    SizedBox(
                      width: compact ? 34 : 48,
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'VS',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                color: Color(0xffe9c67d),
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '⚔',
                              style: TextStyle(
                                color: Color(0xffe9c67d),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _HomeCombatant(
                        id: 'dren',
                        label: 'DREN · S1',
                        subtitle: 'RANDOM OPPONENT',
                        compact: compact,
                        enemy: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: compact ? 5 : 8),
            if (status.isNotEmpty)
              Text(
                status,
                key: const Key('battle-status'),
                style: const TextStyle(color: Color(0xff83dfa9), fontSize: 10),
              ),
            Text(
              'Rewarded duels remaining today: $rewardsLeft/10',
              style: const TextStyle(color: Color(0xff93a6bc), fontSize: 10),
            ),
            SizedBox(height: compact ? 5 : 7),
            _RuneButton(
              actionKey: const Key('start-practice-duel'),
              label: '⚔  START PRACTICE DUEL',
              onTap: onStart,
              gold: true,
            ),
            const SizedBox(height: 5),
            if (liveStatus != null)
              Text(
                liveStatus!,
                key: const Key('live-match-status'),
                style: const TextStyle(fontSize: 10, color: Color(0xffa6b9d0)),
              ),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _RuneButton(
                    actionKey: const Key('find-live-match'),
                    label: onLive == null ? 'SIGN IN FOR LIVE PVP' : deckLabel,
                    onTap: canLive ? onLive : null,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _RuneButton(
                    actionKey: const Key('test-flame'),
                    label: 'TEST FLAME',
                    onTap: onFlameDemo,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  String get deckLabel =>
      canLive ? 'FIND LIVE MATCH' : 'SAVE 3+ CARDS TO PLAY LIVE';
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

class _SeasonBanner extends StatelessWidget {
  const _SeasonBanner({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: compact ? 58 : 96,
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 14 : 22,
      vertical: compact ? 8 : 12,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff253550), Color(0xff101e37)],
      ),
      border: Border.all(color: const Color(0x66dfbe77)),
      borderRadius: BorderRadius.circular(15),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SEASON PREVIEW',
                style: TextStyle(
                  color: Color(0xffeac981),
                  fontSize: 8,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: compact ? 3 : 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  const TextSpan(
                    text: 'THE RUNE ',
                    children: [
                      TextSpan(
                        text: 'CIRCUIT',
                        style: TextStyle(color: Color(0xfff5d28b)),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: compact ? 17 : 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!compact)
                const Text(
                  'First championship • Coming with online accounts',
                  style: TextStyle(color: Color(0xffacbddd), fontSize: 9),
                ),
            ],
          ),
        ),
        Text(
          '♜',
          style: TextStyle(
            color: const Color(0xffe2c476),
            fontSize: compact ? 35 : 54,
          ),
        ),
      ],
    ),
  );
}

class _HomeCombatant extends StatelessWidget {
  const _HomeCombatant({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.compact,
    this.stage = 1,
    this.attack,
    this.crit,
    this.skillId,
    this.enemy = false,
  });
  final String id, label, subtitle;
  final bool compact, enemy;
  final int stage;
  final int? attack, crit;
  final String? skillId;
  @override
  Widget build(BuildContext context) {
    final hero = KardRuneCatalog.heroes.firstWhere((item) => item.id == id);
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff0b1529),
              border: Border.all(
                color: enemy
                    ? const Color(0x75ab636b)
                    : const Color(0x68bdac7a),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: enemy ? Image.asset(hero.cardAsset(hero.stages.first),fit:BoxFit.contain)
              : GestureDetector(onTap: () {
                  final skill = SkillCatalog.byId(skillId);
                  if(skill == null)return;
                  showDialog<void>(context:context,builder:(dialogContext)=>Dialog(
                    backgroundColor:const Color(0xff111e35),
                    child:Padding(padding:const EdgeInsets.all(16),child:Column(
                      mainAxisSize:MainAxisSize.min,children:[
                        Text(skill.name.toUpperCase(),style:TextStyle(color:skill.color,fontWeight:FontWeight.w900)),
                        Text(skill.description,textAlign:TextAlign.center),
                        Text('${skill.trigger} · ${skill.limit}',textAlign:TextAlign.center),
                        SkillPreviewButton(skill:skill),
                        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('CLOSE')),
                      ]))));
                },child:CharacterCardArt(asset:hero.cardAsset(hero.stages[stage-1]),
                  hp:CombatRules.hpForStage(stage),attack:attack,crit:crit,skillId:skillId)),
          ),
        ),
        SizedBox(height: compact ? 3 : 6),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: compact ? 11 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          subtitle,
          maxLines: 1,
          style: TextStyle(
            color: const Color(0xff93a5c1),
            fontSize: compact ? 7 : 8,
            letterSpacing: .7,
          ),
        ),
      ],
    );
  }
}

class _RuneButton extends StatelessWidget {
  const _RuneButton({
    this.actionKey,
    required this.label,
    required this.onTap,
    this.gold = false,
  });
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
            gradient: LinearGradient(
              colors: gold
                  ? const [Color(0xfff8dd9d), Color(0xffbc8a3b)]
                  : const [Color(0xff1e344f), Color(0xff13213a)],
            ),
            border: Border.all(
              color: gold ? const Color(0x9cf6dd9b) : const Color(0x66c4aa66),
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: gold ? const Color(0xff251a0c) : const Color(0xfff7dba5),
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
            Text('${owned.length}/27 owned · ${deck.length}/9 in deck',
              style:const TextStyle(color:Color(0xffaabbd2),fontSize:11)),
          ])),
          OutlinedButton.icon(key:const Key('collection-edit-deck'),
            onPressed:()=>_openDeck(context),
            icon:const Icon(Icons.style_outlined,size:16),label:const Text('EDIT DECK'),
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
            hintText:'Search hero or skill...',hintStyle:const TextStyle(color:Color(0xffb4c4d6)),
            contentPadding:const EdgeInsets.symmetric(vertical:11),
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)))),
        const SizedBox(height:6),
        Row(children:[
          for(final item in const [('owned','OWNED'),('all','ALL'),('missing','LOCKED')])
            Padding(padding:const EdgeInsets.only(right:5),child:ChoiceChip(
              label:Text(item.$2),selected:ownership==item.$1,showCheckmark:false,
              onSelected:(_)=>setState(()=>ownership=item.$1),
              visualDensity:VisualDensity.compact,
              labelStyle:const TextStyle(fontSize:9,color:Colors.white,fontWeight:FontWeight.bold),
              selectedColor:const Color(0xff795d2c),backgroundColor:const Color(0xff1b2c46))),
          const Spacer(),
          IconButton(key:const Key('collection-toggle-filters'),tooltip:'Advanced filters',
            onPressed:()=>setState(()=>expandedFilters=!expandedFilters),
            icon:Icon(expandedFilters?Icons.tune:Icons.filter_list,color:const Color(0xffffd892))),
        ]),
        if(expandedFilters)...[
          Row(children:[
            Expanded(child:_dropdown(stageFilter,const [
              ('all','ALL STAGES'),('1','STAGE 1'),('2','STAGE 2'),('3','STAGE 3')],
              (v)=>setState(()=>stageFilter=v))),
            const SizedBox(width:6),
            Expanded(child:_dropdown(rarity,const [
              ('all','ALL RARITIES'),('common','COMMON'),('uncommon','UNCOMMON'),
              ('rare','RARE'),('epic','EPIC'),('legendary','LEGENDARY'),('ultra','ULTRA')],
              (v)=>setState((){rarity=v;skillFilter='all';}))),
          ]),
          const SizedBox(height:5),
          _dropdown(skillFilter,[
            const ('all','ALL SKILLS'),
            for(final skill in SkillCatalog.skills)
              if(rarity=='all'||skill.rarity==rarity)(skill.id,skill.name.toUpperCase()),
          ],(v)=>setState(()=>skillFilter=v)),
        ],
        Row(children:[
          Expanded(child:_dropdown(sort,const [
            ('atk','ATK HIGH → LOW'),('crit','CRIT HIGH → LOW'),
            ('rarity','SKILL RARITY'),('stage','STAGE HIGH → LOW'),('name','NAME A–Z')],
            (v)=>setState(()=>sort=v))),
          const SizedBox(width:6),
          Text('${found.length} RESULTS',style:const TextStyle(fontSize:10,color:Color(0xffb9cadf))),
          IconButton(onPressed:reset,tooltip:'Reset filters',visualDensity:VisualDensity.compact,
            icon:const Icon(Icons.restart_alt,color:Color(0xffffd892),size:20)),
        ]),
        const SizedBox(height:4),
        Expanded(child:found.isEmpty?Center(child:TextButton(
          onPressed:reset,child:const Text('No cards found · RESET FILTERS')))
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
    builder: (dialogContext) => Dialog(
      backgroundColor: const Color(0xff101d36),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xffd5ad62)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: 430,
        height: 650,
        child: DeckBuilder(
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
                  Text('${skill.name.toUpperCase()} · ${skill.rarity.toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: skill.color, fontWeight: FontWeight.w900)),
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
          TextSpan(
            text: title == 'EVOCA' ? 'EVOCA ' : 'HERO ',
            children: [
              TextSpan(
                text: title == 'EVOCA' ? 'EROI' : 'SUMMON',
                style: const TextStyle(color: Color(0xfff5d28b)),
              ),
            ],
          ),
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(0, -.3),
                colors: [Color(0xff624966), Color(0xff152443)],
              ),
              border: Border.all(color: const Color(0x88e1bc71)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    KardRuneCatalog.heroes
                        .firstWhere((hero) => hero.id == 'dren')
                        .cardAsset(
                          KardRuneCatalog.heroes
                              .firstWhere((hero) => hero.id == 'dren')
                              .stages[2],
                        ),
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffd8b35f),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'FEATURED HERO',
                      style: TextStyle(
                        color: Color(0xff241b13),
                        fontSize: 8,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Column(
                    children: [
                      Text(
                        'EPIC · SHADOW',
                        style: TextStyle(
                          color: Color(0xffe9c880),
                          fontSize: 8,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'DREN',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'The darkness answers his call.',
                        style: TextStyle(
                          color: Color(0xffcad1e0),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
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
  const _SummonChoice({
    required this.eyebrow,
    required this.title,
    required this.symbol,
    required this.action,
    required this.enabled,
    required this.onTap,
    this.gold = false,
  });
  final String eyebrow, title, symbol, action;
  final bool enabled, gold;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: gold ? const Color(0xff283248) : const Color(0xff12233d),
      border: Border.all(
        color: gold ? const Color(0x79d8b769) : const Color(0x5c6887a0),
      ),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      color: Color(0xffe9c880),
                      fontSize: 8,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              symbol,
              style: const TextStyle(color: Color(0xffe1c07a), fontSize: 28),
            ),
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
