import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../repositories/pvp_repository.dart';
import '../../services/live_pvp_socket.dart';
import 'live_pvp_arena.dart';
import 'pvp_controller.dart';

typedef PvpSocketConnector = PvpEventSocket Function(String url, String ticket);

enum LiveMatchState { idle, connecting, waiting, arena, error }

class LiveMatchCoordinator extends ChangeNotifier {
  LiveMatchCoordinator({
    required this.repository,
    required this.connect,
    Duration hitDuration = const Duration(milliseconds: 650),
  }) : arena = ArenaViewController(hitDuration: hitDuration) {
    arena.onReady = ready;
  }

  final PvpRepository repository;
  final PvpSocketConnector connect;
  final ArenaViewController arena;
  PvpEventSocket? _socket;
  PvpController? _protocol;
  StreamSubscription<PvpEvent>? _subscription;
  LiveMatchState state = LiveMatchState.idle;
  String message = 'Ready for a live match.';
  bool _closing = false;

  Future<List<String>> loadDeck() => repository.loadDeck();
  Future<void> saveDeck(List<String> cards) => repository.saveDeck(cards);

  Future<void> findMatch() async {
    await close();
    state = LiveMatchState.connecting;
    message = 'Requesting secure match ticket…';
    notifyListeners();
    try {
      final ticket = await repository.liveTicket();
      final socket = connect(ticket.url, ticket.ticket);
      _socket = socket;
      _protocol = PvpController(socket);
      _closing = false;
      _subscription = socket.events.listen(
        _handle,
        onError: (Object error) => _disconnected('Connection error.'),
        onDone: () {
          if (!_closing) _disconnected('Connection lost. Match forfeited.');
        },
      );
      state = LiveMatchState.waiting;
      message = 'Connected. Finding another player…';
      notifyListeners();
    } catch (error) {
      state = LiveMatchState.error;
      message = 'Unable to start live PvP: $error';
      notifyListeners();
    }
  }

  void _handle(PvpEvent event) {
    _protocol?.handle(event);
    switch (event) {
      case PingEvent():
        break;
      case WaitingEvent():
        state = LiveMatchState.waiting;
        message = 'Waiting for an opponent…';
      case HandEvent():
        arena.startHand(event);
        state = LiveMatchState.arena;
        message = 'Round ${event.round}';
      case LockedEvent():
        arena.lock(event.card, automatic: event.automatic);
      case OpponentLockedEvent():
        message = 'Opponent locked a card.';
      case RoundResultEvent():
        arena.replay(event.json);
      case FinishedEvent():
        arena.finish(event.winner, event.score);
      case ErrorEvent():
        message = event.message;
        state = LiveMatchState.error;
    }
    notifyListeners();
  }

  bool play(String id) => _protocol?.play(id) ?? false;
  void ready() => _protocol?.ready();

  void _disconnected(String value) {
    arena.disconnect();
    state = LiveMatchState.arena;
    message = value;
    notifyListeners();
  }

  Future<void> close() async {
    _closing = true;
    arena.resetMatch();
    state = LiveMatchState.idle;
    message = 'Ready for a live match.';
    notifyListeners();
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    _protocol?.reset();
    _protocol = null;
    if (socket != null) await socket.close();
  }

  @override
  void dispose() {
    _closing = true;
    _subscription?.cancel();
    _socket?.close();
    arena.dispose();
    super.dispose();
  }
}
