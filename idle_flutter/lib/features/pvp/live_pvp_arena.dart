import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/catalog.dart';
import '../../game/combat_rules.dart';
import '../../services/live_pvp_socket.dart';
import '../cards/card_stat_badges.dart';

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
  VoidCallback? onReady;
  Timer? _clock;

  void startHand(HandEvent value) {
    hand = value;
    score = [...value.score];
    lockedCard = popup = effect = null;
    playerCard = opponentCard = null;
    battleStarted = false;
    attackActor = -1;
    automatic = false;
    battleStarted = false;
    hitSerial = 0;
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
    _clock?.cancel();
    notifyListeners();
  }

  Future<void> replay(Map<String, dynamic> json) async {
    if (_replaying) return;
    _replaying = true;
    _clock?.cancel();
    battleStarted = true;
    popup = 'BATTLE START';
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
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (token != generation) return;
    popup = null;
    notifyListeners();
    for (final raw in (json['log'] as List? ?? const [])) {
      await Future<void>.delayed(hitDuration);
      if (token != generation) return;
      final log = Map<String, dynamic>.from(raw as Map);
      attackActor = log['actor'] as int? ?? -1;
      hitSerial++;
      if (attackActor == 0) {
        opponentHp = log['hp'] as int;
      } else {
        playerHp = log['hp'] as int;
      }
      effect = log['critical'] == true ? 'CRITICAL!' : '-${log['damage']} HP';
      notifyListeners();
    }
    if (token != generation) return;
    popup = json['winner'] == 0
        ? 'ROUND WON'
        : json['winner'] == 1
        ? 'ROUND LOST'
        : 'ROUND DRAW';
    if (json['score'] is List) score = List<int>.from(json['score'] as List);
    notifyListeners();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (token == generation) onReady?.call();
  }

  void finish(String winner, List<int> value) {
    score = [...value];
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
    _replaying = false;
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
  });
  final ArenaViewController controller;
  final ValueChanged<String> onPlay;
  final VoidCallback onReady;
  @override
  State<LivePvpArena> createState() => _LivePvpArenaState();
}

class _LivePvpArenaState extends State<LivePvpArena> {
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
    super.dispose();
  }

  void _play(String id) {
    if (widget.controller.select(id)) widget.onPlay(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final motionDuration = reduced ? Duration.zero : c.hitDuration;
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
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Color(0xff121e33),
              border: Border(bottom: BorderSide(color: Color(0xffdfb76c)))),
            child: Column(children: [
              Row(children: [
                const Text('⚔ LIVE RUNE CLASH', style: TextStyle(color: Color(0xffffd993), fontSize: 16, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('ROUND ' + (c.hand?.round ?? 1).toString() + ' / 3',
                  key: const Key('round-counter'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 5),
              Text('YOU  ' + c.score[0].toString() + '    •  FIRST TO 2  •    ' + c.score[1].toString() + '  RIVAL',
                key: const Key('round-score'), style: const TextStyle(color: Color(0xffd7e5f2), fontWeight: FontWeight.w800)),
            ])),
          Container(key: const Key('pvp-timer'), margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xff162941),
              border: Border.all(color: c.seconds <= 10 && choosing ? Colors.redAccent : const Color(0xffd7b26e)),
              borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              const Icon(Icons.timer_outlined, color: Color(0xffffd993)),
              const SizedBox(width: 8),
              Text(choosing ? 'CHOOSE YOUR CARD' : battle ? 'BATTLE IN PROGRESS' : c.lockedCard != null ? 'WAITING FOR RIVAL' : 'READY',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(c.seconds.toString() + 's', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            ])),
          Text('⚔ ' + (c.hand?.opponent ?? 'SEARCHING'), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xffc6d7ed))),
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                color: const Color(0xaa0c172c), borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xff496183))))),
              if (!battle) Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _slot('RIVAL CARD', 'Opponent selects secretly', const Color(0xff9c718c), const Key('opponent-play-zone')),
                const Text('VS', style: TextStyle(color: Color(0xffffd993), fontSize: 26, fontFamily: 'Georgia')),
                DragTarget<String>(key: const Key('play-zone'),
                  onWillAcceptWithDetails: (_) => choosing,
                  onAcceptWithDetails: (details) => _play(details.data),
                  builder: (context, candidate, rejected) => _slot(
                    c.lockedCard == null ? 'YOUR CARD SLOT' : 'CARD LOCKED',
                    c.lockedCard == null ? 'DRAG HERE OR TAP A CARD' : 'Waiting for opponent',
                    candidate.isNotEmpty ? Colors.greenAccent : const Color(0xffd5ae61),
                    const Key('player-play-zone'))),
              ]),
              if (battle) Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('BATTLE ARENA', style: TextStyle(color: Color(0xffffd993), fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  Expanded(child: _fighter(c.playerCard!, c.playerHp, c.attackActor == 0, c.hitSerial, motionDuration, 'you')),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('VS', style: TextStyle(fontSize: 23, color: Color(0xffffd993), fontWeight: FontWeight.bold))),
                  Expanded(child: _fighter(c.opponentCard!, c.opponentHp, c.attackActor == 1, c.hitSerial, motionDuration, 'rival')),
                ]),
                const SizedBox(height: 12),
                if (c.effect != null) AnimatedSwitcher(duration: motionDuration,
                  child: Text(c.effect!, key: ValueKey(c.hitSerial), style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900,
                    color: c.effect == 'CRITICAL!' ? const Color(0xffffd56c) : const Color(0xffff8787)))),
              ]),
              if (c.popup != null) Container(key: const Key('battle-announcement'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(color: const Color(0xf009172d), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffffd993), width: 2)),
                child: Text(c.popup!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xffffd993)))),
            ]))),
          Container(padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
            decoration: const BoxDecoration(color: Color(0xff111f34),
              border: Border(top: BorderSide(color: Color(0xffd5ae61)))),
            child: Column(children: [
              Row(children: [
                const Text('YOUR HAND', style: TextStyle(color: Color(0xffffd993), fontWeight: FontWeight.w900)),
                const Spacer(),
                const Icon(Icons.layers_outlined, key: Key('deck-pile'), size: 16),
                const SizedBox(width: 3),
                Text((c.hand == null ? 0 : c.hand!.deckSize - c.used.length).toString() + ' LEFT',
                  key: const Key('deck-remaining')),
                const SizedBox(width: 12),
                Text('DISCARDED ' + c.used.length.toString(), key: const Key('discard-count')),
              ]),
              const SizedBox(height: 7),
              SizedBox(height: bounds.maxHeight < 620 ? 95 : 124,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  for (final card in handCards) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(key: const Key('hand-card'),
                      onTap: choosing ? () => _play(card.id) : null,
                      child: Draggable<String>(
                        data: card.id, maxSimultaneousDrags: choosing ? 1 : 0,
                        feedback: Material(color: Colors.transparent,
                          child: _BattleCard(card: card, selected: true)),
                        childWhenDragging: Opacity(opacity: .3, child: _BattleCard(card: card, selected: false)),
                        child: _BattleCard(key: ValueKey('hand-' + card.id), card: card, selected: false))))),
                  if (handCards.isEmpty) const Expanded(child: Center(child: Text('CARD LOCKED / DISCARDED'))),
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
    key: key, height: 104, width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(color: const Color(0xff182940),
      border: Border.all(color: accent, width: 2), borderRadius: BorderRadius.circular(13)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.add_circle_outline, color: Color(0xffffd993), size: 24),
      const SizedBox(height: 4),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
      Text(detail, style: const TextStyle(color: Color(0xffb3c7dd), fontSize: 11)),
    ]));

  Widget _fighter(PvpCard card, int hp, bool attacking, int serial, Duration duration, String side) =>
    AnimatedSlide(key: ValueKey(side + serial.toString()),
      offset: attacking ? Offset(side == 'you' ? .12 : -.12, 0) : Offset.zero,
      duration: duration, curve: Curves.easeOutBack,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(side == 'you' ? 'YOU' : 'RIVAL',
          style: const TextStyle(color: Color(0xffd9e4f2), fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _BattleCard(card: card, selected: false, width: 140, height: 188, hp: hp),
        const SizedBox(height: 6),
        Text(hp.toString() + ' HP', key: Key('pvp-' + side + '-hp'),
          style: const TextStyle(color: Color(0xff88c9ff), fontSize: 13, fontWeight: FontWeight.w900)),
      ]));

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
      ),
    ),
  );
}

class _ArenaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xff263052), Color(0xff090d19)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * .48),
        width: size.width * .88,
        height: size.height * .32,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: .06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
