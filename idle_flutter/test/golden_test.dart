import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/app.dart';
import 'package:idle_kardrune/features/pvp/live_pvp_arena.dart';
import 'package:idle_kardrune/services/live_pvp_socket.dart';

void main() {
  for (final target in const {
    'tournament': null,
    'cards': 'CARDS',
    'summon': 'SUMMON',
    'profile': 'PROFILE',
  }.entries) {
    testWidgets('mobile ${target.key} visual candidate', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const KardRuneApp(enableCloudBootstrap: false));
      await tester.pumpAndSettle();
      if (target.value != null) {
        await tester.tap(find.text(target.value!).last);
        await tester.pumpAndSettle();
      }
      if (target.key == 'cards' || target.key == 'profile') {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${target.key}_390x844.png'),
      );
    });
  }

  testWidgets('mobile realtime arena visual candidate', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ArenaViewController();
    await tester.pumpWidget(
      MaterialApp(
        home: LivePvpArena(
          controller: controller,
          onPlay: (_) {},
          onReady: () {},
        ),
      ),
    );
    controller.startHand(
      const HandEvent(
        round: 1,
        opponent: 'Rival',
        score: [0, 0],
        hand: [
          PvpCard(id: 'sam:1', hero: 'sam', stage: 1, attack: 40, crit: 4),
          PvpCard(id: 'lira:1', hero: 'lira', stage: 1, attack: 46, crit: 5),
          PvpCard(id: 'rhea:1', hero: 'rhea', stage: 1, attack: 38, crit: 6),
        ],
        deckSize: 9,
        usedCount: 0,
        durationMs: 30000,
        deadline: 30000,
        matchId: 'visual',
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/pvp_arena_390x844.png'),
    );
    controller.dispose();
  });
}
