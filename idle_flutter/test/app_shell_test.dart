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
        expect(find.byKey(const Key('find-live-match')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('CARDS').last);
        await tester.pump();
        expect(find.byKey(const Key('collection-scroll-grid')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('SUMMON').last);
        await tester.pump();
        expect(find.text('STANDARD SUMMON'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('PROFILE').last);
        await tester.pump();
        expect(find.byKey(const Key('account-section')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('cards collection and summon update the wallet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(KardRuneApp(random: () => 0));
    await tester.tap(find.text('CARDS').last);
    await tester.pump();
    expect(find.byKey(const Key('collection-scroll-grid')), findsOneWidget);
    expect(find.textContaining('1/27'), findsOneWidget);
    await tester.tap(find.text('SUMMON').last);
    await tester.pump();
    expect(find.text('1,500'), findsOneWidget);
    await tester.tap(find.textContaining('SUMMON 1'));
    await tester.pump();
    expect(find.text('1,200'), findsOneWidget);
  });
  testWidgets('arena routes signed-out players to Profile without rewards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(KardRuneApp(random: () => 0));
    await tester.tap(find.byKey(const Key('find-live-match')));
    await tester.pump();
    expect(find.byKey(const Key('account-section')), findsOneWidget);
    expect(find.text('1,500'), findsOneWidget);
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
    await tester.tap(find.textContaining('SUMMON 1'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('DUPLICATE CARD'), findsOneWidget);
    expect(find.byKey(const Key('summon-old-card')), findsOneWidget);
    expect(find.byKey(const Key('summon-new-card')), findsOneWidget);
    expect(find.byKey(const Key('summon-delta-atk')), findsOneWidget);
    expect(find.byKey(const Key('summon-delta-crit')), findsOneWidget);
    await tester.tap(find.text('KEEP CURRENT · +100'));
    await tester.pump();
    expect(find.text('1,300'), findsOneWidget);
  });
  testWidgets('duplicate arrows and pending save survive until choice', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _MemoryStorage(), service = LocalSaveService(storage);
    var index=0;
    const rolls=[0.0,0.0,0.0,0.8,0.0];
    await tester.pumpWidget(KardRuneApp(saveService: service,
      enableCloudBootstrap:false,random:()=>rolls[index++ % rolls.length]));
    await tester.tap(find.text('SUMMON').last);
    await tester.pump();
    await tester.tap(find.textContaining('SUMMON 1'));
    await tester.pumpAndSettle();
    expect(find.text('DUPLICATE CARD'), findsOneWidget);
    expect(service.load().pendingDuplicate,{
      'id':'sam:1','attack':1,'crit':0,'skillId':'C5','skillVersion':1,
    });
    expect(find.descendant(of:find.byKey(const Key('summon-delta-atk')),
      matching:find.byIcon(Icons.arrow_downward)),findsOneWidget);
    expect(find.descendant(of:find.byKey(const Key('summon-delta-crit')),
      matching:find.byIcon(Icons.arrow_downward)),findsOneWidget);
    expect(service.load().attacks['sam:1'],40);
    await tester.tap(find.byKey(const Key('summon-replace')));
    await tester.pumpAndSettle();
    expect(service.load().attacks['sam:1'],1);
    expect(service.load().crits['sam:1'],0);
    expect(service.load().skills['sam:1'],'C5');
    expect(service.load().pendingDuplicate,isNull);
  });

  testWidgets('unresolved duplicate is reopened after app restart', (tester) async {
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service=LocalSaveService(_MemoryStorage());
    service.save(PlayerSave.initial().copyWith(shards:1200,
      pendingDuplicate:{'id':'sam:1','attack':92,'crit':2}));
    await tester.pumpWidget(KardRuneApp(saveService:service,enableCloudBootstrap:false));
    await tester.pumpAndSettle();
    expect(find.text('DUPLICATE CARD'),findsOneWidget);
    await tester.tap(find.byKey(const Key('summon-keep')));
    await tester.pumpAndSettle();
    expect(service.load().shards,1300);
    expect(service.load().pendingDuplicate,isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(KardRuneApp(saveService:service,enableCloudBootstrap:false));
    await tester.pumpAndSettle();
    expect(find.text('DUPLICATE CARD'),findsNothing);
  });

  testWidgets('profile language toggle exposes Italian navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const KardRuneApp());
    await tester.tap(find.text('PROFILE').last);
    await tester.pump();
    await tester.tap(find.textContaining('ITALIANO'));
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
    await tester.tap(find.byKey(const Key('collection-edit-deck')));
    await tester.pump();
    expect(find.byKey(const Key('deck-slot')), findsNWidgets(9));
  });
  testWidgets('owned card image tap selects it and persists real statistics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _MemoryStorage(), service = LocalSaveService(storage);
    service.save(
      PlayerSave.initial().copyWith(
        owned: ['sam:1', 'sam:2'],
        attacks: {'sam:1': 40, 'sam:2': 73},
        crits: {'sam:1': 4, 'sam:2': 19},
      ),
    );

    await tester.pumpWidget(KardRuneApp(saveService: service));
    await tester.tap(find.text('CARDS').last);
    await tester.pump();
    expect(find.byKey(const Key('card-stats-sam:2')), findsOneWidget);
    final stats = find.byKey(const Key('card-stats-sam:2'));
    final frame = find.byKey(const Key('card-frame-sam:2'));
    expect(frame, findsOneWidget);
    expect(
      find.descendant(
        of: stats,
        matching: find.byKey(const Key('stat-badge-atk')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: stats,
        matching: find.byKey(const Key('stat-badge-crit')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: stats,
        matching: find.byKey(const Key('stat-badge-hp')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: stats, matching: find.text('340')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: stats, matching: find.text('73')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: stats, matching: find.text('19%')),
      findsOneWidget,
    );
    final frameRect = tester.getRect(frame);
    for (final badgeKey in const [
      Key('stat-badge-atk'),
      Key('stat-badge-crit'),
      Key('stat-badge-hp'),
    ]) {
      final badge = find.descendant(of: frame, matching: find.byKey(badgeKey));
      expect(frameRect.contains(tester.getCenter(badge)), isTrue);
    }

    await tester.tap(find.byKey(const Key('card-art-sam:2')));
    await tester.pump();
    expect(find.byKey(const Key('card-details-sam:2')), findsOneWidget);
    expect(find.text('ACTIVE CHAMPION'), findsOneWidget);
    expect(service.load().active, 'sam:2');
  });

  testWidgets('unowned card image tap opens preview without selecting it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _MemoryStorage(), service = LocalSaveService(storage);
    service.save(PlayerSave.initial());

    await tester.pumpWidget(KardRuneApp(saveService: service));
    await tester.tap(find.text('CARDS').last);
    await tester.pump();
    await tester.tap(find.text('ALL'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('card-art-sam:3')),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('collection-scroll-grid')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('card-art-sam:3')));
    await tester.pump();
    final details = find.byKey(const Key('card-details-sam:3'));
    expect(details, findsOneWidget);
    expect(find.text('NOT COLLECTED'), findsOneWidget);
    expect(
      find.descendant(of: details, matching: find.text('430')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: details, matching: find.text('—')),
      findsNWidgets(2),
    );
    expect(service.load().active, 'sam:1');
  });

  testWidgets('selected saved ATK and Stage persist when returning to Arena', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _MemoryStorage(), service = LocalSaveService(storage);
    service.save(
      PlayerSave.initial().copyWith(
        owned: ['sam:1', 'sam:2'],
        attacks: {'sam:1': 1, 'sam:2': 100},
        crits: {'sam:1': 4, 'sam:2': 19},
      ),
    );
    await tester.pumpWidget(
      KardRuneApp(saveService: service, random: () => .75),
    );
    await tester.tap(find.text('CARDS').last);
    await tester.pump();
    await tester.tap(find.byKey(const Key('card-art-sam:2')));
    await tester.pump();
    await tester.tap(find.text('CLOSE'));
    await tester.pump();
    await tester.tap(find.text('ARENA').last);
    await tester.pump();
    expect(service.load().active, 'sam:2');
    expect(service.load().attacks['sam:2'], 100);
  });

  testWidgets(
    'duplicate replacement refreshes and persists card ATK and CRIT',
    (tester) async {
      final storage = _MemoryStorage(), service = LocalSaveService(storage);
      service.save(PlayerSave.initial());
      await tester.pumpWidget(
        KardRuneApp(saveService: service, random: () => 0),
      );
      await tester.tap(find.text('SUMMON').last);
      await tester.pump();
      await tester.tap(find.textContaining('SUMMON 1'));
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(find.text('REPLACE'));
      await tester.pump();
      await tester.tap(find.text('CARDS').last);
      await tester.pump();
      expect(find.text('1'), findsWidgets);
      expect(find.text('0%'), findsWidgets);
      expect(service.load().attacks['sam:1'], 1);
      expect(service.load().crits['sam:1'], 0);
    },
  );
  testWidgets('runtime loads and displays the legacy save', (
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
    final saved = service.load(
      nowMs: DateTime(2026, 10, 25).millisecondsSinceEpoch,
    );
    expect(saved.name, 'Saved Hero');
    expect(saved.shards, 900);
    expect(saved.duels, 0);
    expect(saved.wins, 0);
    expect(saved.practiceCount, 0);
  });

  testWidgets('animation preference persists outside the game save', (
    tester,
  ) async {
    final storage = _MemoryStorage(), service = LocalSaveService(storage);
    await tester.pumpWidget(KardRuneApp(saveService: service));
    final gameSaveBefore = storage.values[LocalSaveService.legacySaveKey];
    await tester.tap(find.text('PROFILE').last);
    await tester.pump();
    await tester.tap(find.byKey(const Key('motion-reduced')));
    await tester.pump();
    expect(storage.values['idle-motion-preference-v1'], 'reduced');
    expect(find.byKey(const Key('motion-reduced-selected')), findsOneWidget);
    expect(storage.values[LocalSaveService.legacySaveKey], gameSaveBefore);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(KardRuneApp(saveService: service));
    await tester.tap(find.text('PROFILE').last);
    await tester.pump();
    expect(find.byKey(const Key('motion-reduced-selected')), findsOneWidget);
  });
}
