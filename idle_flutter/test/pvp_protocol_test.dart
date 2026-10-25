import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/pvp/pvp_controller.dart';
import 'package:idle_kardrune/services/live_pvp_socket.dart';

class FakeSocket implements PvpSocketPort {
  final sent = <String>[];
  @override
  void send(String value) => sent.add(value);
  @override
  Future<void> close() async {}
}

void main() {
  test('decodes the existing hand event without changing fields', () {
    final e = PvpEvent.decode({
      'type': 'hand',
      'round': 2,
      'opponent': 'Rival',
      'score': [1, 0],
      'hand': [
        {'id': 'sam:1', 'hero': 'sam', 'stage': 1, 'attack': 40, 'crit': 4},
      ],
      'deckSize': 9,
      'usedCount': 1,
      'durationMs': 30000,
      'deadline': 1000,
      'matchId': 'm',
    });
    expect(e, isA<HandEvent>());
    final h = e as HandEvent;
    expect(h.round, 2);
    expect(h.durationMs, 30000);
    expect(h.hand.single.id, 'sam:1');
  });
  test('controller responds to ping and sends only one play per round', () {
    final socket = FakeSocket(), controller = PvpController(socket);
    controller.handle(const PingEvent());
    expect(jsonDecode(socket.sent.single), {'type': 'pong'});
    controller.handle(
      const HandEvent(
        round: 1,
        opponent: 'R',
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
    expect(controller.play('sam:1'), isTrue);
    expect(controller.play('sam:1'), isFalse);
    expect(jsonDecode(socket.sent.last), {'type': 'play', 'id': 'sam:1'});
  });
  test(
    'ready uses the unchanged server message and reset permits a new match',
    () {
      final socket = FakeSocket(), controller = PvpController(socket);
      controller.ready();
      expect(jsonDecode(socket.sent.last), {'type': 'ready'});
      controller.reset();
      expect(controller.round, 0);
      expect(controller.hand, isEmpty);
    },
  );
  test('ticket is appended to the existing Worker URL', () {
    expect(
      LivePvpSocket.connectionUri(
        'wss://pvp.example/connect',
        'abc',
      ).toString(),
      'wss://pvp.example/connect?ticket=abc',
    );
  });
}
