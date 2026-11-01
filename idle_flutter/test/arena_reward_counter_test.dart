import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/pvp/arena_landing.dart';
import 'package:idle_kardrune/localization/kr_localizations.dart';

void main() {
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
    expect(find.text('Ricompense PvP rimaste (24 ore): 7/10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
