import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/pvp/arena_landing.dart';
import 'package:idle_kardrune/localization/kr_localizations.dart';

void main() {
  for (final size in const [Size(320, 568), Size(390, 844), Size(500, 725), Size(600, 900)]) {
    testWidgets('Arena label and reward stay within one painted CTA at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: KrLocaleScope(
        language: KrLanguage.italian,
        child: Scaffold(body: ArenaLanding(
          header: const SizedBox.shrink(),
          hint: '',
          searching: false,
          onStart: () {},
          rewardRemaining: 7,
        )),
      )));
      final button = tester.getRect(find.byKey(const Key('find-live-match')));
      final anchor = tester.getRect(find.byKey(const Key('arena-painted-cta-anchor')));
      final title = tester.getRect(find.text('INIZIA PARTITA'));
      final quota = tester.getRect(find.byKey(const Key('pvp-rewards-remaining')));
      expect((title.center.dx - button.center.dx).abs(), lessThan(1));
      expect((title.center.dy - button.center.dy).abs(), lessThan(1));
      expect(button.top, greaterThanOrEqualTo(anchor.top));
      expect(quota.top, greaterThanOrEqualTo(button.bottom - 1));
      expect(quota.bottom, lessThanOrEqualTo(anchor.bottom + 1));
      expect(anchor.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('PvP quota is translated and placed under Start Match', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: KrLocaleScope(
      language: KrLanguage.italian,
      child: Scaffold(body: ArenaLanding(
        header: const SizedBox.shrink(),
        hint: '',
        searching: false,
        onStart: () {},
        rewardRemaining: 7,
        rewardLimit: 10,
      )),
    )));
    expect(find.byKey(const Key('find-live-match')), findsOneWidget);
    // The translated title and swords stay centered on the illustrated
    // button, with the swords above it on mobile screens.
    final button = tester.getRect(find.byKey(const Key('find-live-match')));
    final swords = tester.getRect(find.byType(DuelingSwords));
    final title = tester.getRect(find.text('INIZIA PARTITA'));
    expect((title.center.dx - button.center.dx).abs(), lessThan(1));
    expect((title.center.dy - button.center.dy).abs(), lessThan(1));
    expect((swords.center.dx - button.center.dx).abs(), lessThan(1));
    expect(swords.bottom, lessThan(button.top));
    expect(find.text('Ricompense PvP rimaste (24 ore): 7/10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
