import '../services/api_client.dart';

class LiveTicket {
  const LiveTicket(this.url, this.ticket, this.expiresAt);
  final String url, ticket;
  final int expiresAt;
}

class CloudDeck {
  const CloudDeck(this.cards, this.revision);
  final List<String> cards;
  final int revision;
}

class PvpRepository {
  PvpRepository(this.api);
  final ApiClient api;
  Future<Map<String, dynamic>> status() => api.get('/api/pvp/status');
  Future<Map<String, dynamic>> join() => api.post('/api/pvp/join');
  Future<Map<String, dynamic>> leave() => api.post('/api/pvp/leave');
  Future<CloudDeck> saveDeck(List<String> cards, int revision) async {
    final value = await api.request('/api/pvp/deck', 'PUT', {
      'cards': cards,
      'revision': revision,
    });
    return _deck(value);
  }

  Future<CloudDeck> loadDeck() async => _deck(await api.get('/api/pvp/deck'));

  CloudDeck _deck(Map<String, dynamic> value) {
    final cards = value['cards'], revision = value['revision'];
    if (cards is! List || revision is! int || revision < 0) {
      throw const FormatException('Invalid cloud deck response');
    }
    return CloudDeck(List<String>.from(cards), revision);
  }

  Future<LiveTicket> liveTicket() async {
    final j = await api.post('/api/pvp/live-ticket');
    return LiveTicket(
      j['url'] as String,
      j['ticket'] as String,
      j['expiresAt'] as int,
    );
  }
}
