import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/pvp/live_match_coordinator.dart';
import 'package:idle_kardrune/repositories/pvp_repository.dart';
import 'package:idle_kardrune/services/api_client.dart';
import 'package:idle_kardrune/services/live_pvp_socket.dart';

class _Auth implements AuthTokenProvider {
  @override
  Future<String> idToken() async => 't';
}

class _Transport implements ApiTransport {
  final requests = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest r) async {
    requests.add(r);
    if (r.path.endsWith('live-ticket')) {
      return const ApiResponse(
        200,
        '{"url":"wss://pvp.test/connect","ticket":"abc","expiresAt":99}',
      );
    }
    if (r.path.endsWith('/deck')) {
      return const ApiResponse(200, '{"cards":["sam:1"]}');
    }
    return const ApiResponse(200, '{}');
  }
}

class _Socket implements PvpEventSocket {
  final controller = StreamController<PvpEvent>();
  final sent = <String>[];
  bool closed = false;
  @override
  Stream<PvpEvent> get events => controller.stream;
  @override
  void send(String value) => sent.add(value);
  @override
  Future<void> close() async {
    closed = true;
    await controller.close();
  }
}

const hand = HandEvent(
  round: 1,
  opponent: 'Rival',
  score: [0, 0],
  hand: [PvpCard(id: 'sam:1', hero: 'sam', stage: 1, attack: 40, crit: 4)],
  deckSize: 9,
  usedCount: 0,
  durationMs: 30000,
  deadline: 30000,
  matchId: 'm',
);

void main() {
  test('ticket opens socket and first hand opens arena', () async {
    final transport = _Transport(), socket = _Socket();
    final c = LiveMatchCoordinator(
      repository: PvpRepository(ApiClient(_Auth(), transport)),
      connect: (url, ticket) => socket,
    );
    await c.findMatch();
    expect(c.state, LiveMatchState.waiting);
    socket.controller.add(hand);
    await Future<void>.delayed(Duration.zero);
    expect(c.state, LiveMatchState.arena);
    expect(c.arena.hand?.opponent, 'Rival');
    expect(c.arena.seconds, 30);
    expect(c.play('sam:1'), isTrue);
    expect(jsonDecode(socket.sent.single), {'type': 'play', 'id': 'sam:1'});
    await c.close();
    expect(socket.closed, isTrue);
    expect(c.arena.hand, isNull);
    c.dispose();
  });
  test(
    'authoritative replay sends ready once and disconnect is visible',
    () async {
      final socket = _Socket();
      final c = LiveMatchCoordinator(
        repository: PvpRepository(ApiClient(_Auth(), _Transport())),
        connect: (url, ticket) => socket,
        hitDuration: Duration.zero,
      );
      await c.findMatch();
      socket.controller.add(hand);
      await Future<void>.delayed(Duration.zero);
      final result = RoundResultEvent({
        'winner': 0,
        'cards': [
          {'id': 'sam:1', 'hero': 'sam', 'stage': 1, 'attack': 40, 'crit': 4},
          {'id': 'dren:1', 'hero': 'dren', 'stage': 1, 'attack': 65, 'crit': 7},
        ],
        'log': [],
        'score': [1, 0],
      });
      socket.controller.add(result);
      socket.controller.add(result);
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      expect(
        socket.sent.where((v) => jsonDecode(v)['type'] == 'ready').length,
        1,
      );
      await socket.controller.close();
      await Future<void>.delayed(Duration.zero);
      expect(c.arena.popup, 'CONNECTION LOST');
      c.dispose();
    },
  );
  test('deck saves and reloads through existing endpoint', () async {
    final transport = _Transport();
    final c = LiveMatchCoordinator(
      repository: PvpRepository(ApiClient(_Auth(), transport)),
      connect: (url, ticket) => _Socket(),
    );
    await c.saveDeck(['sam:1']);
    final loaded = await c.loadDeck();
    expect(loaded, ['sam:1']);
    expect(
      transport.requests.any(
        (r) => r.method == 'PUT' && r.path == '/api/pvp/deck',
      ),
      isTrue,
    );
    c.dispose();
  });
}
