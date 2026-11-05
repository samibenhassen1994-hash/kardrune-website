import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/summon/summon_result.dart';
import 'package:idle_kardrune/features/summon/summon_video.dart';
void main() {
  for (final allowVideo in [false, true]) {
    testWidgets('reduced motion video opt-in: $allowVideo', (tester) async {
      var completed = 0;
      await tester.pumpWidget(MaterialApp(home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true, size: Size(390, 844)),
        child: SummonResult(
          allowVideoWithReducedMotion: allowVideo,
          heroName: 'Tor', stage: 1, asset: 'assets/idle/tutorial/cards.webp', hp: 240, newAttack: 25, newCrit: 0,
          onKeep: () {}, onReplace: () {}, onContinue: () {},
          onVideoComplete: () => completed++,
        ),
      )));
      expect(find.byType(SummonVideo), allowVideo ? findsOneWidget : findsNothing);
      expect(completed, 1);
      await tester.pump();
      expect(find.byType(SummonVideo), findsNothing);
      expect(completed, 1);
    });
  }
}
