import 'dart:convert';

import 'package:idle_kardrune/game/summon_rules.dart';
import 'package:idle_kardrune/models/player_save.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/forge/forge_screen.dart';
import 'package:idle_kardrune/services/api_client.dart';
import 'package:idle_kardrune/services/local_save_service.dart';
import 'package:idle_kardrune/localization/kr_localizations.dart';

class Token implements AuthTokenProvider {
  @override
  Future<String> idToken() async => 'test';
}

class Store implements KeyValueStorage {
  final data = <String, String>{};
  @override
  String? read(String k) => data[k];
  @override
  void write(String k, String v) {
    data[k] = v;
  }
}

class Transport implements ApiTransport {
  final requests = <ApiRequest>[];
  bool failOnce = false;
  bool manyCards = false;
  bool skillPending = false;
  final proposal = <String, dynamic>{
    'pendingSkill': true,
    'requestId': '00000000000000000000000000000001',
    'cardId': 'sam:1',
    'success': true,
    'before': {'attack': 48, 'crit': 7, 'skillId': 'C1'},
    'after': {'attack': 48, 'crit': 7, 'skillId': 'C2'},
  };
  int attack = 48, keys = 2;
  Map<String, dynamic> state() => {
    'revision': 1,
    'pendingSkill': skillPending ? proposal : null,
    'keys': {'green': keys, 'blue': 0, 'red': 0},
    'chances': {'green': 35, 'blue': 55, 'red': 75},
    'caps': {
      '1': {
        'attack': [25, 50],
        'crit': [0, 8],
      },
    },
    'cards': [
      {'id': 'sam:1', 'attack': attack, 'crit': 7, 'skillId': 'C1'},
      if (manyCards)
        for (final hero in ['lira', 'rhea', 'dren', 'tor'])
          {'id': '$hero:1', 'attack': 40, 'crit': 7, 'skillId': 'C1'},
    ],
  };
  @override
  Future<ApiResponse> send(ApiRequest r) async {
    requests.add(r);
    if (r.method == 'POST') {
      final body = jsonDecode(r.body!) as Map;
      if (body['action'] == 'decision') {
        skillPending = false;
        return ApiResponse(200, jsonEncode(state()));
      }

      if (failOnce) {
        failOnce = false;
        throw Exception('connection lost');
      }
      return ApiResponse(
        200,
        jsonEncode({
          ...state(),
          'result': {
            'success': true,
            'before': {'attack': 48, 'crit': 7, 'skillId': 'C1'},
            'after': {'attack': 50, 'crit': 7, 'skillId': 'C1'},
          },
        }),
      );
    }
    return ApiResponse(200, jsonEncode(state()));
  }
}

void main() {
  test('free duplicate keeps zero refund after save reload', () {
    final save = PlayerSave.fromJson({
      'owned': ['sam:1'],
      'pendingDuplicate': {
        'id': 'sam:1',
        'attack': 40,
        'crit': 4,
        'free': true,
      },
    });
    expect(save.pendingDuplicate?['free'], true);
    expect(
      SummonRules.resolveDuplicate(
        replace: false,
        free: save.pendingDuplicate?['free'] == true,
      ).refund,
      0,
    );
    expect(SummonRules.resolveDuplicate(replace: false).refund, 100);
  });

  testWidgets('Forge card arrows paginate a two-column grid', (t) async {
    final transport = Transport()..manyCards = true;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeScreen(
            active: true,
            api: ApiClient(Token(), transport),
            uid: 'a',
            storage: Store(),
            onLogin: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(find.byKey(const Key('forge-card-grid')));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );
    expect(find.text('1 / 2'), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('forge-next')));
    await t.tap(find.byKey(const Key('forge-next')));
    await t.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await t.tap(find.byKey(const Key('forge-prev')));
    await t.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('Forge fits without vertical scrolling at $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(bottom: 68),
              child: ForgeScreen(
                header: const SizedBox(height: 68),
                active: true,
                api: ApiClient(Token(), Transport()..manyCards = true),
                uid: 'a',
                onLogin: () {},
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsNothing);
      final initial = t.getRect(find.byKey(const Key('forge-upgrade-card')));
      await t.tap(find.widgetWithText(ChoiceChip, 'SKILL'));
      await t.pumpAndSettle();
      expect(t.getRect(find.byKey(const Key('forge-upgrade-card'))), initial);

      expect(t.takeException(), isNull);
      expect(
        t.getBottomRight(find.byKey(const Key('forge-start'))).dy,
        lessThanOrEqualTo(size.height - 68),
      );
      for (final scroll in t.stateList<ScrollableState>(
        find.byType(Scrollable),
      )) {
        expect(scroll.position.maxScrollExtent, 0);
      }
    });
  }
  for (final accept in [true, false]) {
    testWidgets(
      'resumed skill proposal can be ${accept ? 'accepted' : 'rejected'}',
      (t) async {
        final transport = Transport()..skillPending = true;
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ForgeScreen(
                active: true,
                api: ApiClient(Token(), transport),
                uid: 'a',
                onLogin: () {},
                onSave: (_) {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byKey(const Key('forge-accept')), findsOneWidget);
        expect(find.byKey(const Key('forge-reject')), findsOneWidget);
        await t.tap(find.byKey(Key(accept ? 'forge-accept' : 'forge-reject')));
        await t.pumpAndSettle();
        expect(transport.skillPending, false);
        expect(find.byKey(const Key('forge-start')), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
  for (final lang in KrLanguage.values) {
    testWidgets('Forge 320px selection and server result ${lang.code}', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final transport = Transport();
      var applied = false;
      await t.pumpWidget(
        MaterialApp(
          builder: (c, w) => KrLocaleScope(language: lang, child: w!),
          home: Scaffold(
            body: ForgeScreen(
              active: true,
              api: ApiClient(Token(), transport),
              uid: 'a',
              storage: Store(),
              onLogin: () {},
              onSave: (_) => applied = true,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final start = find.byKey(const Key('forge-start'));
      await t.ensureVisible(start);
      await t.tap(start);
      await t.pumpAndSettle();
      expect(applied, true);
      expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('cap and empty inventory disable attempts', (t) async {
    final transport = Transport()..attack = 50;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeScreen(
            active: true,
            api: ApiClient(Token(), transport),
            uid: 'a',
            onLogin: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      t.widget<FilledButton>(find.byKey(const Key('forge-start'))).onPressed,
      isNull,
    );
  });
  testWidgets('zero keys disables start and cannot submit', (t) async {
    final transport = Transport()..keys = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeScreen(
            active: true,
            api: ApiClient(Token(), transport),
            uid: 'a',
            onLogin: () {},
            onSave: (_) {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      t.widget<FilledButton>(find.byKey(const Key('forge-start'))).onPressed,
      isNull,
    );
    expect(transport.requests.where((r) => r.method == 'POST'), isEmpty);
  });
  testWidgets('network retry reuses persisted request after reopening', (
    t,
  ) async {
    final transport = Transport()..failOnce = true;
    final storage = Store();
    Widget screen(int key) => MaterialApp(
      home: Scaffold(
        body: ForgeScreen(
          key: ValueKey(key),
          active: true,
          api: ApiClient(Token(), transport),
          uid: 'a',
          storage: storage,
          onLogin: () {},
          onSave: (_) {},
        ),
      ),
    );
    await t.pumpWidget(screen(0));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('forge-start')));
    await t.tap(find.byKey(const Key('forge-start')));
    await t.pumpAndSettle();
    await t.pumpWidget(screen(1));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('forge-start')));
    await t.tap(find.byKey(const Key('forge-start')));
    await t.pumpAndSettle();
    final posts = transport.requests.where((r) => r.method == 'POST').toList();
    expect(posts, hasLength(2));
    expect(posts[0].body, posts[1].body);
    expect(storage.read('idle-forge-pending-v1:a'), 'null');
  });
}
