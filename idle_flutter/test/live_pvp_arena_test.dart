import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/pvp/live_pvp_arena.dart';
import 'package:idle_kardrune/services/live_pvp_socket.dart';

const cards = [
  PvpCard(id: 'sam:1', hero: 'sam', stage: 1, attack: 40, crit: 4),
  PvpCard(id: 'lira:1', hero: 'lira', stage: 1, attack: 46, crit: 5),
  PvpCard(id: 'dren:1', hero: 'dren', stage: 1, attack: 65, crit: 7),
];
void main() {
  testWidgets('three cards physically deal from deck and timer is visible', (
    tester,
  ) async {
    final c = ArenaViewController();
    await tester.pumpWidget(
      MaterialApp(
        home: LivePvpArena(controller: c, onPlay: (_) {}, onReady: () {}),
      ),
    );
    c.startHand(
      const HandEvent(
        round: 1,
        opponent: 'Rival',
        score: [0, 0],
        hand: cards,
        deckSize: 9,
        usedCount: 0,
        durationMs: 30000,
        deadline: 30000,
        matchId: 'm',
      ),
    );
    await tester.pump();
    expect(find.text('30'), findsOneWidget);
    expect(find.byKey(const Key('deck-pile')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(const Key('hand-card')), findsNWidgets(3));
    expect(find.text('40'), findsOneWidget);
    expect(find.text('4%'), findsOneWidget);
    expect(find.text('240'), findsNWidgets(3));
    expect(find.byKey(const Key('battle-card-frame-sam:1')), findsOneWidget);
  });
  testWidgets('tap selects once and automatic lock is explained', (
    tester,
  ) async {
    final c = ArenaViewController();
    final played = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: LivePvpArena(controller: c, onPlay: played.add, onReady: () {}),
      ),
    );
    c.startHand(
      const HandEvent(
        round: 1,
        opponent: 'R',
        score: [0, 0],
        hand: cards,
        deckSize: 3,
        usedCount: 0,
        durationMs: 30000,
        deadline: 30000,
        matchId: 'm',
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.byKey(const ValueKey('hand-sam:1')));
    await tester.pump();
    expect(played, ['sam:1']);
    c.lock('sam:1', automatic: true);
    await tester.pump();
    expect(find.text('TIME EXPIRED — RANDOM CARD SELECTED'), findsOneWidget);
  });
  testWidgets('critical replay shows damage then popup and ready', (
    tester,
  ) async {
    final c = ArenaViewController(
      hitDuration: const Duration(milliseconds: 100),
    );
    var ready = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LivePvpArena(
          controller: c,
          onPlay: (_) {},
          onReady: () => ready++,
        ),
      ),
    );
    c.startHand(
      const HandEvent(
        round: 1,
        opponent: 'R',
        score: [0, 0],
        hand: cards,
        deckSize: 3,
        usedCount: 0,
        durationMs: 30000,
        deadline: 30000,
        matchId: 'm',
      ),
    );
    c.replay({
      'winner': 0,
      'cards': [
        {'id': 'sam:1', 'hero': 'sam', 'stage': 1, 'attack': 40, 'crit': 4},
        {'id': 'dren:1', 'hero': 'dren', 'stage': 1, 'attack': 65, 'crit': 7},
      ],
      'log': [
        {'actor': 0, 'damage': 80, 'critical': true, 'hp': 160},
      ],
      'score': [1, 0],
    });
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('CRITICAL!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('ROUND WON'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(ready, 1);
  });
  testWidgets('new match clears every previous visual state', (tester) async {
    final c = ArenaViewController();
    await tester.pumpWidget(
      MaterialApp(
        home: LivePvpArena(controller: c, onPlay: (_) {}, onReady: () {}),
      ),
    );
    c.lock('sam:1', automatic: true);
    c.finish('you', [3, 1]);
    c.resetMatch();
    await tester.pump();
    expect(find.text('TIME EXPIRED — RANDOM CARD SELECTED'), findsNothing);
    expect(find.textContaining('VICTORY'), findsNothing);
    expect(c.used, isEmpty);
    expect(c.score, [0, 0]);
  });

  testWidgets('drag selects a card and replay uses authoritative hp', (
    tester,
  ) async {
    final c = ArenaViewController(
      hitDuration: const Duration(milliseconds: 50),
    );
    final played = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: LivePvpArena(controller: c, onPlay: played.add, onReady: () {}),
      ),
    );
    c.startHand(
      const HandEvent(
        round: 1,
        opponent: 'R',
        score: [0, 0],
        hand: cards,
        deckSize: 3,
        usedCount: 0,
        durationMs: 30000,
        deadline: 30000,
        matchId: 'm',
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.drag(
      find.byKey(const ValueKey('hand-lira:1')),
      const Offset(0, -260),
    );
    await tester.pump();
    expect(played, ['lira:1']);
    final replay = c.replay({
      'winner': 1,
      'cards': [
        {'id': 'lira:1', 'hero': 'lira', 'stage': 1, 'attack': 46, 'crit': 5},
        {'id': 'dren:1', 'hero': 'dren', 'stage': 1, 'attack': 65, 'crit': 7},
      ],
      'log': [
        {'actor': 1, 'damage': 65, 'critical': false, 'hp': 175},
      ],
      'score': [0, 1],
    });
    await tester.pump(const Duration(milliseconds: 70));
    expect(find.text('175 HP'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await replay;
  });

  test(
    'late replay is cancelled by a second match and disconnect is final',
    () async {
      final c = ArenaViewController(
        hitDuration: const Duration(milliseconds: 20),
      );
      c.startHand(
        const HandEvent(
          round: 1,
          opponent: 'R',
          score: [0, 0],
          hand: cards,
          deckSize: 3,
          usedCount: 0,
          durationMs: 30000,
          deadline: 30000,
          matchId: 'one',
        ),
      );
      final late = c.replay({
        'winner': 0,
        'log': [
          {'actor': 0, 'damage': 80, 'critical': true, 'hp': 160},
        ],
        'score': [1, 0],
      });
      c.resetMatch();
      c.startHand(
        const HandEvent(
          round: 1,
          opponent: 'N',
          score: [0, 0],
          hand: cards,
          deckSize: 3,
          usedCount: 0,
          durationMs: 30000,
          deadline: 30000,
          matchId: 'two',
        ),
      );
      await late;
      expect(c.popup, isNull);
      c.disconnect();
      expect(c.popup, 'CONNECTION LOST');
      c.dispose();
    },
  );

  test('duplicate round results only advance ready once', () async {
    final c = ArenaViewController(hitDuration: const Duration(milliseconds: 1));
    var ready = 0;
    c.onReady = () => ready++;
    c.startHand(
      const HandEvent(
        round: 1,
        opponent: 'R',
        score: [0, 0],
        hand: cards,
        deckSize: 3,
        usedCount: 0,
        durationMs: 30000,
        deadline: 30000,
        matchId: 'same',
      ),
    );
    final result = {
      'winner': 0,
      'log': <Object>[],
      'score': [1, 0],
    };
    await Future.wait([c.replay(result), c.replay(result)]);
    expect(ready, 1);
    c.dispose();
  });

  testWidgets(
    'each replay resets HP from card stage and renders original art',
    (tester) async {
      final c = ArenaViewController(hitDuration: Duration.zero);
      await tester.pumpWidget(
        MaterialApp(
          home: LivePvpArena(controller: c, onPlay: (_) {}, onReady: () {}),
        ),
      );
      c.startHand(
        const HandEvent(
          round: 1,
          opponent: 'R',
          score: [0, 0],
          hand: cards,
          deckSize: 3,
          usedCount: 0,
          durationMs: 30000,
          deadline: 30000,
          matchId: 'm',
        ),
      );
      var replay = c.replay({
        'winner': 2,
        'cards': [
          {'id': 'sam:2', 'hero': 'sam', 'stage': 2, 'attack': 40, 'crit': 4},
          {'id': 'dren:3', 'hero': 'dren', 'stage': 3, 'attack': 65, 'crit': 7},
        ],
        'log': <Object>[],
        'score': [0, 0],
      });
      await tester.pump();
      expect(c.playerHp, 340);
      expect(c.opponentHp, 430);
      expect(find.byKey(const ValueKey('card-art-dren:3')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await replay;

      c.startHand(
        const HandEvent(
          round: 2,
          opponent: 'R',
          score: [0, 0],
          hand: cards,
          deckSize: 3,
          usedCount: 0,
          durationMs: 30000,
          deadline: 30000,
          matchId: 'm',
        ),
      );
      replay = c.replay({
        'winner': 2,
        'cards': [
          {'id': 'sam:1', 'hero': 'sam', 'stage': 1, 'attack': 40, 'crit': 4},
          {'id': 'dren:2', 'hero': 'dren', 'stage': 2, 'attack': 65, 'crit': 7},
        ],
        'log': <Object>[],
        'score': [0, 0],
      });
      await tester.pump();
      expect(c.playerHp, 240);
      expect(c.opponentHp, 340);
      await tester.pump(const Duration(seconds: 2));
      await replay;
    },
  );
}
