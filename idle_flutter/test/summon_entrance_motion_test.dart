import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/summon/summon_screen.dart';

void main() {
  testWidgets('full entrance keeps its duration with OS reduced motion', (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), disableAnimations: false),
      child: SummonScreen(header: const SizedBox(), shards: 1000, active: true,
        accountKey: 'guest', loadFreeStatus: () async => {'available': 2},
        onSummon: (_) async {}, onFreeSummon: () async {}),
    )));
    await tester.pump(const Duration(milliseconds: 100));
    final slide = tester.widget<SlideTransition>(find.descendant(of: find.byType(SummonScreen), matching: find.byType(SlideTransition)).first);
    expect(slide.position.value.dy, greaterThan(0));
    expect(slide.position.value.dy, lessThan(.35));
    await tester.pump(const Duration(milliseconds: 400));
    expect(slide.position.value, Offset.zero);
    await tester.pumpWidget(const SizedBox());
  });
}
