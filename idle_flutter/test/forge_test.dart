import 'dart:convert';

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
  int attack = 48, keys = 2;
  Map<String, dynamic> state() => {
    'revision': 1,
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
