import '../services/api_client.dart';

class LiveTicket {
  const LiveTicket(this.url, this.ticket, this.expiresAt);
  final String url, ticket;
  final int expiresAt;
}

class PvpRepository {
  PvpRepository(this.api);
  final ApiClient api;
  Future<Map<String, dynamic>> status() => api.get('/api/pvp/status');
  Future<Map<String, dynamic>> join() => api.post('/api/pvp/join');
  Future<Map<String, dynamic>> leave() => api.post('/api/pvp/leave');
  Future<void> saveDeck(List<String> cards) async {
    await api.request('/api/pvp/deck', 'PUT', {'cards': cards});
  }

  Future<List<String>> loadDeck() async {
    final value = await api.get('/api/pvp/deck');
    return value['cards'] is List
        ? List<String>.from(value['cards'] as List)
        : <String>[];
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
