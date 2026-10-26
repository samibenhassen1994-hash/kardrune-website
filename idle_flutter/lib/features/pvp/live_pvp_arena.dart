import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/live_pvp_socket.dart';

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
  VoidCallback? onReady;
  Timer? _clock;

  void startHand(HandEvent value) {
    hand = value;
    score = [...value.score];
    lockedCard = popup = effect = null;
    automatic = false;
    _replaying = false;
    seconds = (value.durationMs / 1000).ceil();
    generation++;
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (seconds == 0) return timer.cancel();
      seconds--;
      notifyListeners();
    });
    notifyListeners();
  }

  bool select(String id) {
    if (lockedCard != null) return false;
    lock(id, automatic: false);
    return true;
  }

  void lock(String id, {required bool automatic}) {
    if (lockedCard != null && lockedCard != id) return;
    lockedCard = id;
    this.automatic = automatic;
    used.add(id);
    notifyListeners();
  }

  Future<void> replay(Map<String, dynamic> json) async {
    if (_replaying) return;
    _replaying = true;
    final token = generation;
    if (json['cards'] is List && (json['cards'] as List).length >= 2) {
      final cards = json['cards'] as List;
      playerCard = PvpCard.fromJson(Map<String, dynamic>.from(cards[0] as Map));
      opponentCard = PvpCard.fromJson(
        Map<String, dynamic>.from(cards[1] as Map),
      );
      notifyListeners();
    }
    for (final raw in (json['log'] as List? ?? const [])) {
      await Future<void>.delayed(hitDuration);
      if (token != generation) return;
      final log = Map<String, dynamic>.from(raw as Map);
      attackActor = log['actor'] as int? ?? -1;
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
      for (var i = 0; i < widget.controller.hand!.hand.length; i++) {
        _deals.add(
          Timer(Duration(milliseconds: 250 * (i + 1)), () {
            if (mounted && seenGeneration == widget.controller.generation) {
              setState(() => dealt = i + 1);
            }
          }),
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
    final cards = c.hand?.hand ?? const <PvpCard>[];
    return Scaffold(
      backgroundColor: const Color(0xff090d19),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _ArenaPainter())),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '${c.hand?.opponent ?? 'SEARCHING'}   ${c.score[0]} — ${c.score[1]}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 72,
              child: Container(
                key: const Key('deck-pile'),
                width: 48,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xff2c2350),
                  border: Border.all(color: Colors.amber, width: 2),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.layers, color: Colors.white70),
              ),
            ),
            Align(
              alignment: const Alignment(0, -.25),
              child: DragTarget<String>(
                key: const Key('play-zone'),
                onAcceptWithDetails: (details) => _play(details.data),
                builder: (context, candidate, rejected) => Container(
                  width: 150,
                  height: 138,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: candidate.isEmpty
                          ? Colors.white24
                          : Colors.greenAccent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: c.opponentCard == null
                      ? const Text(
                          'PLAY CARD',
                          style: TextStyle(color: Colors.white54),
                        )
                      : AnimatedSlide(
                          offset: c.attackActor == 1
                              ? const Offset(0, .18)
                              : Offset.zero,
                          duration: c.hitDuration,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _BattleCard(
                                card: c.opponentCard!,
                                selected: false,
                              ),
                              Text(
                                '${c.opponentHp} HP',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            for (var i = 0; i < cards.length; i++)
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                alignment: i < dealt
                    ? Alignment(-0.7 + i * 0.7, .78)
                    : const Alignment(.88, .72),
                child: i < dealt
                    ? GestureDetector(
                        key: const Key('hand-card'),
                        onTap: () => _play(cards[i].id),
                        child: Draggable<String>(
                          data: cards[i].id,
                          feedback: Material(
                            color: Colors.transparent,
                            child: _BattleCard(card: cards[i], selected: true),
                          ),
                          childWhenDragging: Opacity(
                            opacity: .25,
                            child: _BattleCard(card: cards[i], selected: false),
                          ),
                          child: _BattleCard(
                            key: ValueKey('hand-${cards[i].id}'),
                            card: cards[i],
                            selected: c.lockedCard == cards[i].id,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            Align(
              alignment: const Alignment(0, .35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.playerCard != null)
                    AnimatedSlide(
                      offset: c.attackActor == 0
                          ? const Offset(0, -.18)
                          : Offset.zero,
                      duration: c.hitDuration,
                      child: Text(
                        '${c.playerHp} HP',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  Text(
                    '${c.seconds}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (c.automatic)
              const Align(
                alignment: Alignment(0, .52),
                child: Text(
                  'TIME EXPIRED — RANDOM CARD SELECTED',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ),
            if (c.effect != null)
              Align(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(c.effect),
                  tween: Tween(begin: .5, end: 1.15),
                  duration: const Duration(milliseconds: 350),
                  builder: (_, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Text(
                    c.effect!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            if (c.popup != null)
              Align(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    border: Border.all(color: Colors.amber, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    c.popup!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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

class _BattleCard extends StatelessWidget {
  const _BattleCard({super.key, required this.card, required this.selected});
  final PvpCard card;
  final bool selected;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: selected ? 1.08 : 1,
    duration: const Duration(milliseconds: 150),
    child: Container(
      width: 78,
      height: 108,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(card.hero, style: const TextStyle(color: Colors.white)),
          Text(
            'ATK ${card.attack}',
            style: const TextStyle(color: Colors.amber),
          ),
        ],
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
