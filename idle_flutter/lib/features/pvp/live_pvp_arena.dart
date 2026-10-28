// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import '../../game/catalog.dart';
import '../../game/combat_rules.dart';
import '../../services/live_pvp_socket.dart';
import '../cards/card_stat_badges.dart';
import 'flame_battle_audio.dart';
import 'live_flame_battle.dart';

class ArenaViewController extends ChangeNotifier {
  ArenaViewController({this.hitDuration = const Duration(milliseconds: 650)});
  final Duration hitDuration;
  HandEvent? hand;
  List<int> score = [0, 0];
  final Set<String> used = {};
  String? lockedCard, popup, effect;
  PvpCard? playerCard, opponentCard;
  int playerHp = 240, opponentHp = 240, attackActor = -1;
  bool automatic = false;
  int seconds = 30, generation = 0;
  bool _replaying = false;
  bool battleStarted = false;
  int hitSerial = 0;
  int lastDamage = 0;
  bool lastCritical = false;
  String actionText = '';
  bool attackWindup = false;
  bool matchFinished = false;
  String matchWinner = 'draw';
  int roundsPlayed = 0;
  VoidCallback? onReady;
  Timer? _clock;

  void startHand(HandEvent value) {
    hand = value;
    score = [...value.score];
    lockedCard = popup = effect = null;
    playerCard = opponentCard = null;
    battleStarted = false;
    matchFinished = false;
    attackActor = -1;
    automatic = false;
    battleStarted = false;
    hitSerial = 0;
    lastDamage = 0;
    lastCritical = false;
    actionText = '';
    attackWindup = false;
    _replaying = false;
    seconds = (value.durationMs / 1000).ceil();
    generation++;
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (seconds == 0) return timer.cancel();
      seconds = value.deadline > 1000000000000
          ? ((value.deadline - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 30)
          : (seconds - 1).clamp(0, 30);
      notifyListeners();
    });
    notifyListeners();
  }

  bool select(String id) {
    if (hand == null || lockedCard != null || _replaying || used.contains(id) || !hand!.hand.any((c) => c.id == id)) return false;
    lock(id, automatic: false);
    return true;
  }

  void lock(String id, {required bool automatic}) {
    if (lockedCard != null && lockedCard != id) return;
    lockedCard = id;
    this.automatic = automatic;
    used.add(id);
    // Keep the server deadline visible while the opponent is choosing.
    notifyListeners();
  }

  Future<void> replay(Map<String, dynamic> json) async {
    if (_replaying) return;
    _replaying = true;
    _clock?.cancel();
    battleStarted = true;
    popup = 'BATTLE START';
    actionText = 'Prepare for combat';
    effect = null;
    notifyListeners();
    final token = generation;
    if (json['cards'] is List && (json['cards'] as List).length >= 2) {
      final cards = json['cards'] as List;
      playerCard = PvpCard.fromJson(Map<String, dynamic>.from(cards[0] as Map));
      opponentCard = PvpCard.fromJson(
        Map<String, dynamic>.from(cards[1] as Map),
      );
      playerHp = CombatRules.hpForStage(playerCard!.stage);
      opponentHp = CombatRules.hpForStage(opponentCard!.stage);
      attackActor = -1;
      effect = null;
      notifyListeners();
    }
    if (hitDuration > Duration.zero) {
      await Future<void>.delayed(const Duration(milliseconds: 550));
    }
    if (token != generation) return;
    popup = null;
    notifyListeners();
    for (final raw in (json['log'] as List? ?? const [])) {
      if (token != generation) return;
      final log = Map<String, dynamic>.from(raw as Map);
      attackActor = log['actor'] as int? ?? -1;
      actionText = attackActor == 0 ? 'YOU ATTACK → RIVAL' : 'RIVAL ATTACK → YOU';
      attackWindup = true;
      hitSerial++;
      notifyListeners();
      await Future<void>.delayed(hitDuration);
      if (token != generation) return;
      attackWindup = false;
      if (attackActor == 0) {
        opponentHp = log['hp'] as int;
      } else {
        playerHp = log['hp'] as int;
      }
      effect = log['critical'] == true
          ? 'CRITICAL!  -${log['damage']} HP'
          : '-${log['damage']} HP';
      lastDamage = log['damage'] as int;
      lastCritical = log['critical'] == true;
      notifyListeners();
      if (hitDuration > Duration.zero) await Future<void>.delayed(const Duration(milliseconds: 390));
    }
    if (token != generation) return;
    actionText = 'ROUND COMPLETE';
    popup = json['winner'] == 0
        ? 'ROUND WON'
        : json['winner'] == 1
        ? 'ROUND LOST'
        : 'ROUND DRAW';
    if (json['score'] is List) score = List<int>.from(json['score'] as List);
    roundsPlayed = (json['round'] as int?) ?? hand?.round ?? roundsPlayed;
    notifyListeners();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (token == generation) onReady?.call();
  }

  void finish(String winner, List<int> value, {bool rewarded = false}) {
    matchFinished = true;
    matchWinner = winner;
    score = [...value];
    roundsPlayed = hand?.round ?? roundsPlayed;
    _clock?.cancel();
    attackWindup = false;
    actionText = rewarded ? 'MATCH COMPLETE  ·  +100 SHARDS' : 'MATCH ENDED';
    popup = winner == 'you'
        ? 'VICTORY'
        : winner == 'opponent'
        ? 'DEFEAT'
        : 'DRAW';
    notifyListeners();
  }

  void resetMatch() {
    generation++;
    _clock?.cancel();
    hand = null;
    score = [0, 0];
    used.clear();
    lockedCard = popup = effect = null;
    playerCard = opponentCard = null;
    playerHp = opponentHp = 240;
    attackActor = -1;
    automatic = false;
    battleStarted = false;
    matchFinished = false;
    matchWinner = 'draw';
    roundsPlayed = 0;
    attackWindup = false;
    actionText = '';
    _replaying = false;
    lastDamage = 0;
    lastCritical = false;
    seconds = 30;
    notifyListeners();
  }

  void detachView() {
    _clock?.cancel();
    _clock = null;
  }

  void disconnect() {
    _clock?.cancel();
    popup = 'CONNECTION LOST';
    notifyListeners();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }
}

class LivePvpArena extends StatefulWidget {
  const LivePvpArena({
    super.key,
    required this.controller,
    required this.onPlay,
    required this.onReady,
    this.audio,
    this.playerName = 'Runebearer',
    this.playerAvatar = 'player',
    this.onSurrender,
    this.onComplete,
  });
  final ArenaViewController controller;
  final ValueChanged<String> onPlay;
  final VoidCallback onReady;
  final FlameBattleAudio? audio;
  final String playerName, playerAvatar;
  final VoidCallback? onSurrender;
  final VoidCallback? onComplete;
  @override
  State<LivePvpArena> createState() => _LivePvpArenaState();
}

class _LivePvpArenaState extends State<LivePvpArena> {
  late final FlameBattleAudio _audio = widget.audio ?? createFlameBattleAudio();
  int dealt = 0, seenGeneration = -1;
  final _deals = <Timer>[];
  @override
  void initState() {
    super.initState();
    widget.controller.onReady = widget.onReady;
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    if (seenGeneration != widget.controller.generation &&
        widget.controller.hand != null) {
      seenGeneration = widget.controller.generation;
      dealt = 0;
      for (final timer in _deals) {
        timer.cancel();
      }
      _deals.clear();
      final reduced = MediaQuery.disableAnimationsOf(context);
      for (var i = 0; i < widget.controller.hand!.hand.length; i++) {
        _deals.add(
          Timer(
            reduced ? Duration.zero : Duration(milliseconds: 250 * (i + 1)),
            () {
              if (mounted && seenGeneration == widget.controller.generation) {
                setState(() => dealt = i + 1);
              }
            },
          ),
        );
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final timer in _deals) {
      timer.cancel();
    }
    widget.controller.removeListener(_changed);
    widget.controller.detachView();
    if (widget.audio == null) _audio.dispose();
    super.dispose();
  }

  void _play(String id) {
    _audio.unlock();
    if (widget.controller.select(id)) widget.onPlay(id);
  }

  void _inspect(PvpCard card) {
    _audio.unlock();
    final hero = KardRuneCatalog.heroes.firstWhere((item) => item.id == card.hero);
    showDialog<void>(context: context, builder: (dialogContext) => Dialog(
      backgroundColor: const Color(0xff111e35),
      shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xffd5ae61)),
        borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
        Text(hero.name.toUpperCase(), style: const TextStyle(color: Color(0xffffd993),
          fontSize: 18, fontWeight: FontWeight.w900)),
        Text(hero.element.toUpperCase(), style: const TextStyle(color: Color(0xffb7cceb), fontSize: 11)),
        const SizedBox(height: 10),
        _BattleCard(card: card, selected: false, width: 220, height: 290),
        const SizedBox(height: 12),
        Text('STAGE ${card.stage}  ·  ATK ${card.attack}  ·  CRIT ${card.crit}%  ·  HP ${CombatRules.hpForStage(card.stage)}',
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CLOSE')),
          if (widget.controller.lockedCard == null) TextButton(
            onPressed: () { Navigator.pop(dialogContext); _play(card.id); },
            child: const Text('PLAY CARD')),
        ]),
      ]))));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final cards = c.hand?.hand ?? const <PvpCard>[];
    final battle = c.battleStarted && c.playerCard != null && c.opponentCard != null;
    final choosing = c.hand != null && c.lockedCard == null && !c.battleStarted;
    final handCards = cards.where((card) => !c.used.contains(card.id)).toList();
    return Scaffold(
      backgroundColor: const Color(0xff091225),
      body: SafeArea(child: LayoutBuilder(builder: (context, bounds) => Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xff203959), Color(0xff091225), Color(0xff1a1232)])),
        child: Column(children: [
          Container(key: const Key('pvp-round-header'),
            padding: EdgeInsets.symmetric(horizontal: 9, vertical: bounds.maxHeight < 620 ? 5 : 8),
            decoration: const BoxDecoration(color: Color(0xff121e33),
              border: Border(bottom: BorderSide(color: Color(0xffdfb76c)))),
            child: Row(children: [
                Expanded(child: _profileIdentity(
                  label: 'TU', name: c.hand?.playerName ?? widget.playerName,
                  avatar: c.hand?.playerAvatar ?? widget.playerAvatar,
                  imageKey: const Key('player-avatar'), accent: const Color(0xff4ba8ff),
                  compact: bounds.maxWidth < 360 || bounds.maxHeight < 620)),
                SizedBox(width: bounds.maxWidth < 360 ? 94 : 104,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    FittedBox(fit: BoxFit.scaleDown, child: Text(
                      'ROUND ${c.hand?.round ?? 1} / 3',
                      key: const Key('round-counter'),
                      style: const TextStyle(color: Color(0xffffe0a1),
                        fontSize: 13, fontWeight: FontWeight.w900))),
                    const SizedBox(height: 5),
                    Row(key: const Key('round-score'),
                      mainAxisAlignment: MainAxisAlignment.center, children: [
                      _roundWin(c.score[0], const Color(0xff4ba8ff)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Text('VS', style: TextStyle(color: Color(0xffffd993),
                          fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w900))),
                      _roundWin(c.score[1], const Color(0xffff6c6c)),
                    ]),
                  ])),
                Expanded(child: _profileIdentity(
                  label: 'RIVALE', name: c.hand?.opponent ?? 'SEARCHING',
                  avatar: c.hand?.opponentAvatar ?? 'player',
                  imageKey: const Key('opponent-avatar'),
                  accent: const Color(0xffff6c6c),
                  compact: bounds.maxWidth < 360 || bounds.maxHeight < 620,
                  reverse: true)),
            ])),
          Container(key: const Key('pvp-timer'), margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xff162941),
              border: Border.all(color: c.seconds <= 10 && choosing ? Colors.redAccent : const Color(0xffd7b26e)),
              borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              const Icon(Icons.timer_outlined, color: Color(0xffffd993)),
              const SizedBox(width: 8),
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(choosing ? 'CHOOSE YOUR CARD' : battle ? 'BATTLE IN PROGRESS' : c.lockedCard != null ? 'WAITING FOR RIVAL' : 'READY',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
              const SizedBox(width: 8),
              if (widget.onSurrender != null && !c.matchFinished) ...[
                GestureDetector(
                  key: const Key('surrender-live-arena'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onSurrender,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xff49212b),
                      border: Border.all(color: const Color(0xffff7777)),
                      borderRadius: BorderRadius.circular(7)),
                    child: const Text('ARRENDITI', style: TextStyle(
                      color: Color(0xffffc7c7), fontSize: 10,
                      fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(c.seconds.toString() + 's', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            ])),
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                color: const Color(0xaa0c172c), borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xff496183))))),
              if (!battle && !c.matchFinished) Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _slot('RIVAL CARD', 'Opponent selects secretly', const Color(0xff9c718c), const Key('opponent-play-zone')),
                const Text('VS', style: TextStyle(color: Color(0xffffd993), fontSize: 26, fontFamily: 'Georgia')),
                DragTarget<String>(key: const Key('play-zone'),
                  onWillAcceptWithDetails: (_) => choosing,
                  onAcceptWithDetails: (details) => _play(details.data),
                  builder: (context, candidate, rejected) {
                    final selected = c.lockedCard == null ? null : cards.where((card) => card.id == c.lockedCard).firstOrNull;
                    if (selected != null) {
                      return Container(key: const Key('player-play-zone'), height: bounds.maxHeight < 620 ? 90 : 104,
                        alignment: Alignment.center,
                        child: _BattleCard(card: selected, selected: true, width: 70, height: 98));
                    }
                    return _slot('YOUR CARD SLOT', 'DRAG A CARD HERE',
                      candidate.isNotEmpty ? Colors.greenAccent : const Color(0xffd5ae61),
                      const Key('player-play-zone'));
                  }),
              ]),
              if (battle && !c.matchFinished) Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('BATTLE ARENA', style: TextStyle(color: Color(0xffffd993), fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 5),
                Text(c.actionText, key: const Key('pvp-attack-direction'), textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xffffe2a4), fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                SizedBox(height: bounds.maxHeight < 620 ? 165 : 250,
                  child: LiveFlameBattleStage(key: ValueKey('live-battle-${c.generation}'),
                    controller: c, audio: _audio)),
              ]),
              if (c.matchFinished) Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(c.matchWinner == 'you' ? 'VICTORY' : c.matchWinner == 'opponent' ? 'DEFEAT' : 'DRAW',
                  key: const Key('pvp-final-result'), style: const TextStyle(color: Color(0xffffd993), fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text('FINAL SCORE  ${c.score[0]} - ${c.score[1]}', key: const Key('pvp-final-score'),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${c.roundsPlayed} / 3 ROUNDS PLAYED', style: const TextStyle(color: Color(0xffb7cceb), fontSize: 14)),
                const SizedBox(height: 8),
                Text(c.actionText, style: const TextStyle(color: Color(0xffffd993), fontSize: 13)),
                const SizedBox(height: 24),
                ElevatedButton(key: const Key('pvp-complete'), onPressed: widget.onComplete,
                  child: const Text('COMPLETE', style: TextStyle(fontWeight: FontWeight.bold))),
              ]),
              if (!c.matchFinished && c.popup != null) Container(key: const Key('battle-announcement'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(color: const Color(0xf009172d), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffffd993), width: 2)),
                child: Text(c.popup!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xffffd993)))),
            ]))),
          if (!c.matchFinished) Container(padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
            decoration: const BoxDecoration(color: Color(0xff111f34),
              border: Border(top: BorderSide(color: Color(0xffd5ae61)))),
            child: Column(children: [
              Row(children: [
                const Text('HAND', style: TextStyle(color: Color(0xffffd993), fontSize: 11, fontWeight: FontWeight.w900)),
                const Spacer(),
                const Icon(Icons.layers_outlined, key: Key('deck-pile'), size: 16),
                const SizedBox(width: 3),
                Text((c.hand == null ? 0 : c.hand!.deckSize - c.used.length).toString() + ' LEFT',
                  key: const Key('deck-remaining'), style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 8),
                Text('USED ' + c.used.length.toString(), key: const Key('discard-count'),
                  style: const TextStyle(fontSize: 11)),
              ]),
              const SizedBox(height: 7),
              SizedBox(height: bounds.maxHeight < 620 ? 95 : 124,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  SizedBox(width: 46, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.inventory_2_outlined, color: Color(0xffd5ae61)),
                    Text('${c.used.length}', key: const Key('discard-count-pile'),
                      style: const TextStyle(color: Color(0xffffd993), fontWeight: FontWeight.bold)),
                    const Text('USED', style: TextStyle(fontSize: 9)),
                  ])),
                  for (var index = 0; index < handCards.length; index++) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(key: const Key('hand-card'),
                      onTap: () => _inspect(handCards[index]),
                      child: Draggable<String>(
                        data: handCards[index].id, maxSimultaneousDrags: choosing ? 1 : 0,
                        feedback: Material(color: Colors.transparent,
                          child: _BattleCard(card: handCards[index], selected: true)),
                        childWhenDragging: Opacity(opacity: .3, child: _BattleCard(card: handCards[index], selected: false,
                          width: bounds.maxHeight < 620 ? 65 : 88, height: bounds.maxHeight < 620 ? 90 : 122)),
                        child: AnimatedSlide(duration: reduced ? Duration.zero : const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                          offset: index < dealt ? Offset.zero : const Offset(1.5, -.9),
                          child: AnimatedOpacity(duration: reduced ? Duration.zero : const Duration(milliseconds: 300),
                            opacity: index < dealt ? 1 : 0,
                            child: _BattleCard(key: ValueKey('hand-${handCards[index].id}'),
                              card: handCards[index], selected: false,
                              width: bounds.maxHeight < 620 ? 65 : 88,
                              height: bounds.maxHeight < 620 ? 90 : 122))))))),
                  if (handCards.isEmpty) const Expanded(child: Center(child: Text('CARD LOCKED / DISCARDED'))),
                  SizedBox(width: 46, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.layers_outlined, key: Key('deck-pile-bottom'),
                      color: Color(0xffd5ae61), size: 30),
                    Text('${c.hand == null ? 0 : (c.hand!.deckSize - c.used.length).clamp(0, 99)}',
                      style: const TextStyle(color: Color(0xffffd993), fontWeight: FontWeight.bold)),
                    const Text('DECK', style: TextStyle(fontSize: 9)),
                  ])),
                ])),
              if (c.automatic) const Text('TIME EXPIRED — RANDOM CARD SELECTED',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
              Text(c.used.isEmpty ? 'Each card can be used only once' : 'USED: ' + c.used.join(' · '),
                key: const Key('used-card'), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xffadbbce), fontSize: 10)),
            ])),
        ]),
      ))),
    );
  }
  Widget _slot(String title, String detail, Color accent, Key key) => Container(
    key: key, height: MediaQuery.sizeOf(context).height < 620 ? 90 : 104, width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(color: const Color(0xff182940),
      border: Border.all(color: accent, width: 2), borderRadius: BorderRadius.circular(13)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.add_circle_outline, color: Color(0xffffd993), size: 24),
      const SizedBox(height: 4),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
      Text(detail, style: const TextStyle(color: Color(0xffb3c7dd), fontSize: 11)),
    ]));

  Widget _roundWin(int wins, Color accent) => Container(
    width: 25, height: 30, alignment: Alignment.center,
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .18),
      border: Border.all(color: accent, width: 1.5),
      borderRadius: BorderRadius.circular(7),
      boxShadow: [BoxShadow(color: accent.withValues(alpha: .2), blurRadius: 8)]),
    child: Text('$wins', style: TextStyle(color: accent,
      fontSize: 17, fontWeight: FontWeight.w900)));

  Widget _profileIdentity({required String label, required String name,
    required String avatar, required Key imageKey, required Color accent,
    required bool compact, bool reverse = false}) {
    final safeAvatar = const ['player', 'guard', 'vassal', 'king'].contains(avatar)
        ? avatar : 'player';
    final size = compact ? 44.0 : 56.0;
    final portrait = Container(key: imageKey, width: size, height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: LinearGradient(colors: [accent, const Color(0xffffd993), accent]),
        border: Border.all(color: accent, width: 2),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: .55), blurRadius: 9)]),
      child: Container(decoration: BoxDecoration(shape: BoxShape.circle,
        border: Border.all(color: const Color(0xff101b31), width: 2),
        image: DecorationImage(image: AssetImage(
          'assets/idle/avatars/avatar_$safeAvatar.webp'), fit: BoxFit.cover))));
    final identity = Expanded(child: Column(
      crossAxisAlignment: reverse ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: accent,
        fontSize: 9, fontWeight: FontWeight.w900)),
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
        textAlign: reverse ? TextAlign.right : TextAlign.left,
        style: const TextStyle(color: Color(0xffffe4a3), fontSize: 11,
          fontWeight: FontWeight.w900)),
    ]));
    return Row(children: reverse
      ? [identity, const SizedBox(width: 4), portrait]
      : [portrait, const SizedBox(width: 4), identity]);
  }

}

class LiveFlameBattleStage extends StatefulWidget {
  const LiveFlameBattleStage({super.key, required this.controller, required this.audio});
  final ArenaViewController controller;
  final FlameBattleAudio audio;
  @override
  State<LiveFlameBattleStage> createState() => _LiveFlameBattleStageState();
}

class _LiveFlameBattleStageState extends State<LiveFlameBattleStage> {
  final playerPose = ValueNotifier<LiveCardPose>(liveCardRest);
  final rivalPose = ValueNotifier<LiveCardPose>(liveCardRest);
  late final LiveFlameBattleGame game;
  int seenStrike = 0;
  bool seenImpact = false;

  @override
  void initState() {
    super.initState();
    game = LiveFlameBattleGame(audio: widget.audio, onPose: (player, rival) {
      playerPose.value = player;
      rivalPose.value = rival;
    });
    widget.controller.addListener(_changed);
  }

  void _changed() {
    final c = widget.controller;
    if (c.hitSerial != seenStrike && c.attackWindup) {
      seenStrike = c.hitSerial;
      seenImpact = false;
      final card = c.attackActor == 0 ? c.playerCard : c.opponentCard;
      if (card != null) game.strike(c.attackActor, card);
    } else if (seenStrike == c.hitSerial && !c.attackWindup &&
        !seenImpact && c.effect != null && c.attackActor >= 0) {
      seenImpact = true;
      final card = c.attackActor == 0 ? c.playerCard : c.opponentCard;
      if (card != null) game.impact(c.attackActor, card, c.lastDamage, c.lastCritical);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    game.dispose();
    playerPose.dispose();
    rivalPose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final cardWidth = MediaQuery.sizeOf(context).width < 360 ? 104.0 : 135.0;
    final cardHeight = MediaQuery.sizeOf(context).height < 620 ? 112.0 :
      MediaQuery.sizeOf(context).height < 900 ? 128.0 : 175.0;
    Widget fighter(PvpCard card, int hp, String side, ValueNotifier<LiveCardPose> pose) =>
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(side == 'you' ? 'YOU' : 'RIVAL', style: const TextStyle(
          color: Color(0xffd9e4f2), fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        ValueListenableBuilder<LiveCardPose>(valueListenable: pose,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(value.x, value.y),
            child: Transform.rotate(angle: value.angle, child: child)),
          child: RepaintBoundary(child: _BattleCard(card: card, selected: false,
            width: cardWidth, height: cardHeight, hp: hp))),
        const SizedBox(height: 5),
        Text('$hp HP', key: Key('pvp-$side-hp'), style: const TextStyle(
          color: Color(0xff88c9ff), fontWeight: FontWeight.w900)),
      ]));
    return Stack(children: [
      Row(children: [
        fighter(c.playerCard!, c.playerHp, 'you', playerPose),
        const SizedBox(width: 24, child: Center(child: Text('VS', style: TextStyle(
          color: Color(0xffffd993), fontWeight: FontWeight.w900)))),
        fighter(c.opponentCard!, c.opponentHp, 'rival', rivalPose),
      ]),
      Positioned.fill(child: IgnorePointer(child: RepaintBoundary(
        child: GameWidget(game: game)))),
    ]);
  }
}

class _BattleCard extends StatelessWidget {
  const _BattleCard({super.key, required this.card, required this.selected, this.width = 88, this.height = 122, this.hp});
  final PvpCard card;
  final bool selected;
  final double width, height;
  final int? hp;
  String get asset {
    final hero = KardRuneCatalog.heroes.firstWhere(
      (item) => item.id == card.hero,
    );
    final index = (card.stage - 1).clamp(0, hero.stages.length - 1);
    return hero.cardAsset(hero.stages[index]);
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: selected ? 1.08 : 1,
    duration: const Duration(milliseconds: 150),
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff382867), Color(0xff171b34)],
        ),
        border: Border.all(
          color: selected ? Colors.greenAccent : Colors.amber,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: CharacterCardArt(
        key: ValueKey('battle-card-frame-${card.id}'),
        asset: asset,
        artKey: ValueKey('card-art-${card.id}'),
        hp: hp ?? CombatRules.hpForStage(card.stage),
        attack: card.attack,
        crit: card.crit,
        compact: true,
        imageCacheWidth: 320,
      ),
    ),
  );
}
