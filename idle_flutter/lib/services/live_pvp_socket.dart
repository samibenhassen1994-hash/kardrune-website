import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class PvpCard {
  const PvpCard({
    required this.id,
    required this.hero,
    required this.stage,
    required this.attack,
    required this.crit,
  });
  final String id, hero;
  final int stage, attack, crit;
  factory PvpCard.fromJson(Map<String, dynamic> j) => PvpCard(
    id: j['id'] as String,
    hero: j['hero'] as String,
    stage: j['stage'] as int,
    attack: j['attack'] as int,
    crit: j['crit'] as int,
  );
}

sealed class PvpEvent {
  const PvpEvent();
  static PvpEvent decode(Map<String, dynamic> j) {
    switch (j['type']) {
      case 'ping':
        return const PingEvent();
      case 'waiting':
        return const WaitingEvent();
      case 'hand':
        return HandEvent(
          round: j['round'] as int,
          opponent: j['opponent'] as String,
          score: List<int>.from(j['score'] as List),
          hand: (j['hand'] as List)
              .map((v) => PvpCard.fromJson(Map<String, dynamic>.from(v as Map)))
              .toList(),
          deckSize: j['deckSize'] as int,
          usedCount: j['usedCount'] as int,
          durationMs: j['durationMs'] as int,
          deadline: j['deadline'] as int,
          matchId: j['matchId'] as String,
        );
      case 'locked':
        return LockedEvent(j['card'] as String, j['automatic'] == true);
      case 'opponent_locked':
        return const OpponentLockedEvent();
      case 'round_result':
        return RoundResultEvent(Map<String, dynamic>.from(j));
      case 'finished':
        return FinishedEvent(
          j['reason'] as String,
          j['winner'] as String,
          List<int>.from(j['score'] as List),
        );
      case 'error':
        return ErrorEvent(j['message'] as String);
      default:
        throw FormatException('Unknown PvP event ${j['type']}');
    }
  }
}

class PingEvent extends PvpEvent {
  const PingEvent();
}

class WaitingEvent extends PvpEvent {
  const WaitingEvent();
}

class OpponentLockedEvent extends PvpEvent {
  const OpponentLockedEvent();
}

class HandEvent extends PvpEvent {
  const HandEvent({
    required this.round,
    required this.opponent,
    required this.score,
    required this.hand,
    required this.deckSize,
    required this.usedCount,
    required this.durationMs,
    required this.deadline,
    required this.matchId,
  });
  final int round, deckSize, usedCount, durationMs, deadline;
  final String opponent, matchId;
  final List<int> score;
  final List<PvpCard> hand;
}

class LockedEvent extends PvpEvent {
  const LockedEvent(this.card, this.automatic);
  final String card;
  final bool automatic;
}

class RoundResultEvent extends PvpEvent {
  RoundResultEvent(this.json);
  final Map<String, dynamic> json;
}

class FinishedEvent extends PvpEvent {
  const FinishedEvent(this.reason, this.winner, this.score);
  final String reason, winner;
  final List<int> score;
}

class ErrorEvent extends PvpEvent {
  const ErrorEvent(this.message);
  final String message;
}

abstract interface class PvpSocketPort {
  void send(String value);
  Future<void> close();
}

abstract interface class PvpEventSocket implements PvpSocketPort {
  Stream<PvpEvent> get events;
}

class LivePvpSocket implements PvpEventSocket {
  LivePvpSocket._(this.channel);
  final WebSocketChannel channel;
  static Uri connectionUri(String url, String ticket) {
    final base = Uri.parse(url);
    return base.replace(
      path: '/connect',
      queryParameters: {...base.queryParameters, 'ticket': ticket},
    );
  }

  factory LivePvpSocket.connect(String url, String ticket) =>
      LivePvpSocket._(WebSocketChannel.connect(connectionUri(url, ticket)));
  @override
  Stream<PvpEvent> get events => channel.stream
      .where((value) => value is String)
      .map(
        (value) => PvpEvent.decode(
          Map<String, dynamic>.from(jsonDecode(value as String) as Map),
        ),
      );
  @override
  void send(String value) => channel.sink.add(value);
  @override
  Future<void> close() => channel.sink.close();
}
