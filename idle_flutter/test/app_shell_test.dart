import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/app.dart';
import 'package:idle_kardrune/models/player_save.dart';
import 'package:idle_kardrune/services/local_save_service.dart';

class _MemoryStorage implements KeyValueStorage {
  final values = <String, String>{};
  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String value) => values[key] = value;
}

void main() {
  for (final size in const [
    Size(320, 568),
    Size(375, 667),
    Size(390, 844),
    Size(393, 852),
    Size(430, 932),
  ]) {
    testWidgets(
      'main screens fit ${size.width.toInt()}x${size.height.toInt()} without overflow',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const KardRuneApp());
        await tester.pump();
        expect(find.text('TOURNAMENT'), findsWidgets);
        expect(find.text('TOURNAMENT'), findsWidgets);
        expect(tester.takeException(), isNull);
        for (final label in ['CARDS', 'SUMMON', 'PROFILE']) {
          await tester.tap(find.text(label).last);
          await tester.pump();
          expect(find.text(label), findsWidgets);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
  testWidgets('cards are paginated and summon updates the wallet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(KardRuneApp(random: () => 0));
    await tester.tap(find.text('CARDS').last);
    await tester.pump();
    expect(find.text('1 / 7'), findsOneWidget);
    await tester.tap(find.text('SUMMON').last);
    await tester.pump();
    expect(find.text('1,500'), findsOneWidget);
    await tester.tap(find.text('STANDARD · 300'));
    await tester.pump();
    expect(find.text('1,200'), findsOneWidget);
  });
  testWidgets('training resolves a duel and grants the exact win reward', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(KardRuneApp(random: () => 0));
    await tester.tap(find.byKey(const Key('start-practice-duel')));
    await tester.pump();
    expect(find.text('VICTORY · +100 SHARDS'), findsOneWidget);
    expect(find.text('1,600'), findsOneWidget);
    expect(find.text('Rewarded duels remaining today: 9/10'), findsOneWidget);
  });
  testWidgets('duplicate pull requires keep or replace and keep refunds 100', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(KardRuneApp(random: () => 0));
    await tester.tap(find.text('SUMMON').last);
    await tester.pump();
    await tester.tap(find.text('STANDARD · 300'));
    await tester.pump();
    expect(find.text('DUPLICATE CARD'), findsOneWidget);
    await tester.tap(find.text('KEEP CURRENT · +100'));
    await tester.pump();
    expect(find.text('1,300'), findsOneWidget);
  });
  testWidgets('profile language toggle exposes Italian navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const KardRuneApp());
    await tester.tap(find.text('PROFILE').last);
    await tester.pump();
    await tester.tap(find.text('ITALIANO'));
    await tester.pump();
    expect(find.text('CARTE'), findsOneWidget);
  });
  testWidgets('Cards opens the integrated nine-slot deck builder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const KardRuneApp());
    await tester.tap(find.text('CARDS').last);
    await tester.pump();
    await tester.tap(find.text('DECK BUILDER'));
    await tester.pump();
    expect(find.byKey(const Key('deck-slot')), findsNWidgets(9));
  });
  testWidgets('runtime loads legacy save and persists exact practice result', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    final service = LocalSaveService(storage);
    service.save(
      PlayerSave.initial().copyWith(name: 'Saved Hero', shards: 900),
    );
    await tester.pumpWidget(
      KardRuneApp(
        random: () => .99,
        saveService: service,
        nowMs: () => DateTime(2026, 10, 25).millisecondsSinceEpoch,
      ),
    );
    await tester.tap(find.text('PROFILE').last);
    await tester.pump();
    expect(find.text('Saved Hero'), findsOneWidget);
    await tester.tap(find.text('TOURNAMENT').last);
    await tester.pump();
    await tester.tap(find.byKey(const Key('start-practice-duel')));
    await tester.pump();
    expect(find.text('DEFEAT · +35 SHARDS'), findsOneWidget);
    final saved = service.load(
      nowMs: DateTime(2026, 10, 25).millisecondsSinceEpoch,
    );
    expect(saved.shards, 935);
    expect(saved.duels, 1);
    expect(saved.wins, 0);
    expect(saved.practiceCount, 1);
  });
}
