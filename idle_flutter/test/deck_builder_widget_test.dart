import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/cards/deck_builder.dart';

void main() {
  Widget app(ValueChanged<List<String>> saved) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 430,
        height: 500,
        child: DeckBuilder(
          owned: const ['sam:1', 'lira:1', 'dren:2'],
          initial: const [],
          onSave: saved,
        ),
      ),
    ),
  );
  testWidgets('shows nine slots and explicit add saves a valid deck', (
    tester,
  ) async {
    List<String>? result;
    await tester.pumpWidget(app((v) => result = v));
    expect(find.byKey(const Key('deck-slot')), findsNWidgets(9));
    final add = find.byKey(const Key('add-deck-card-sam:1'));
    final ownedScroll = find.descendant(
      of: find.byKey(const Key('deck-owned-scroll-grid')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(ownedScroll, const Offset(0, -180));
    await tester.pump();
    await tester.tap(add);
    await tester.pump();
    expect(find.byKey(const Key('slot-card-sam:1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-deck')));
    expect(result, ['sam:1']);
  });
  testWidgets('long-press drag follows pointer and drops into chosen slot', (
    tester,
  ) async {
    await tester.pumpWidget(app((_) {}));
    final source = find.byKey(const Key('inventory-lira:1')),
        target = find.byKey(const ValueKey('deck-slot-4'));
    final ownedScroll = find.descendant(
      of: find.byKey(const Key('deck-owned-scroll-grid')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(ownedScroll, const Offset(0, -100));
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    expect(find.byKey(const Key('deck-drag-feedback')), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: target,
        matching: find.byKey(const Key('slot-card-lira:1')),
      ),
      findsOneWidget,
    );
  });
  testWidgets('invalid drop returns without duplicating the card', (
    tester,
  ) async {
    await tester.pumpWidget(app((_) {}));
    final ownedScroll = find.descendant(
      of: find.byKey(const Key('deck-owned-scroll-grid')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(ownedScroll, const Offset(0, -280));
    await tester.pump();
    final source = find.byKey(const Key('inventory-dren:2'));
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(-200, -200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('slot-card-dren:2')), findsNothing);
    expect(find.byKey(const Key('inventory-dren:2')), findsOneWidget);
  });
}
