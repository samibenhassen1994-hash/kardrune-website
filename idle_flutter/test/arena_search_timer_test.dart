import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/pvp/arena_landing.dart';

void main() {
  testWidgets('search timer resets on cancellation and restart and stops offscreen', (tester) async {
    var now = DateTime(2026, 1, 1);
    Future<void> show(bool searching) => tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 390, height: 844, child: ArenaLanding(
        header: const SizedBox.shrink(), onStart: () {}, onCancel: () {},
        hint: '', searching: searching, now: () => now,
      ))),
    ));
    await show(false);
    expect(find.byKey(const Key('pvp-search-elapsed')), findsNothing);
    await show(true);
    expect(find.text('00:00'), findsOneWidget);
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:03'), findsOneWidget);
    await show(false);
    expect(find.byKey(const Key('pvp-search-elapsed')), findsNothing);
    await show(true);
    expect(find.text('00:00'), findsOneWidget);
    await show(false);
  });
}
