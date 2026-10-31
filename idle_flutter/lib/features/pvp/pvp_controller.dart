import 'dart:convert';

import '../../services/live_pvp_socket.dart';

class PvpController {
  PvpController(this.socket);
  final PvpSocketPort socket;
  int round = 0;
  List<PvpCard> hand = [];
  bool locked = false;
  String? matchId;
  void handle(PvpEvent event) {
    switch (event) {
      case PingEvent():
        socket.send(jsonEncode({'type': 'pong'}));
      case HandEvent():
        round = event.round;
        hand = event.hand;
        matchId = event.matchId;
        locked = false;
      case LockedEvent():
        locked = true;
      case WaitingEvent() ||
          DiceEvent() ||
          OpponentLockedEvent() ||
          RoundResultEvent() ||
          FinishedEvent() ||
          ErrorEvent():
        break;
    }
  }

  bool play(String id) {
    if (locked || !hand.any((c) => c.id == id)) return false;
    locked = true;
    socket.send(jsonEncode({'type': 'play', 'id': id}));
    return true;
  }

  void ready() => socket.send(jsonEncode({'type': 'ready'}));
  void reset() {
    round = 0;
    hand = [];
    locked = false;
    matchId = null;
  }
}
