import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/app.dart';
import 'package:idle_kardrune/models/player_save.dart';
import 'package:idle_kardrune/features/pvp/live_match_coordinator.dart';
import 'package:idle_kardrune/features/pvp/live_pvp_arena.dart';
import 'package:idle_kardrune/repositories/pvp_repository.dart';
import 'package:idle_kardrune/services/api_client.dart';
import 'package:idle_kardrune/services/live_pvp_socket.dart';
import 'package:idle_kardrune/services/local_save_service.dart';

class _Storage implements KeyValueStorage {
  final values = <String, String>{};
  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String value) => values[key] = value;
}

class _Auth implements AuthTokenProvider {
  @override
  Future<String> idToken() async => 't';
}

class _Transport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest r) async => r.path.endsWith('live-ticket')
      ? const ApiResponse(
          200,
          '{"url":"wss://p/connect","ticket":"x","expiresAt":1}',
        )
      : const ApiResponse(200, '{}');
}

class _Socket implements PvpEventSocket {
  final stream = StreamController<PvpEvent>();
  @override
  Stream<PvpEvent> get events => stream.stream;
  @override
  void send(String value) {}
  @override
  Future<void> close() => stream.close();
}

void main() {
  testWidgets('Find Live Match opens arena automatically on server hand', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _Storage(),
        local = LocalSaveService(storage),
        socket = _Socket();
    local.save(PlayerSave.initial().copyWith(
      owned: ['sam:1', 'lira:1', 'rhea:1'],
      attacks: {'sam:1': 40, 'lira:1': 46, 'rhea:1': 50},
      crits: {'sam:1': 4, 'lira:1': 5, 'rhea:1': 6},
    ));
    local.saveDeck(['sam:1', 'lira:1', 'rhea:1']);
    final match = LiveMatchCoordinator(
      repository: PvpRepository(ApiClient(_Auth(), _Transport())),
      connect: (url, ticket) => socket,
    );
    await tester.pumpWidget(
      KardRuneApp(saveService: local, liveMatchCoordinator: match),
    );
    final liveButton = find.byKey(const Key('find-live-match'));
    expect(tester.widget<GestureDetector>(liveButton).onTap, isNotNull);
    await tester.tap(liveButton);
    await tester.pumpAndSettle();
    socket.stream.add(
      const HandEvent(
        round: 1,
        opponent: 'Rival',
        score: [0, 0],
        hand: [
          PvpCard(id: 'sam:1', hero: 'sam', stage: 1, attack: 40, crit: 4),
        ],
        deckSize: 1,
        usedCount: 0,
        durationMs: 30000,
        deadline: 1,
        matchId: 'm',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LivePvpArena), findsOneWidget);
    expect(find.text('⚔ Rival'), findsOneWidget);
    expect(find.byKey(const Key('pvp-round-header')), findsOneWidget);
    expect(find.text('ROUND 1 / 3'), findsOneWidget);
    expect(find.byKey(const Key('round-score')), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-live-arena')));
    await tester.pumpAndSettle();
    expect(find.byType(LivePvpArena), findsNothing);
  });
}
