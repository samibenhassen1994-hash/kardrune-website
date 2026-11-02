import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/repositories/pvp_repository.dart';
import 'package:idle_kardrune/services/api_client.dart';
import 'package:idle_kardrune/services/local_save_service.dart';

class _Token implements AuthTokenProvider {
  _Token(this.uid);
  final String uid;
  @override
  Future<String> idToken() async => uid;
}

class _Cloud implements ApiTransport {
  final decks = <String, CloudDeck>{};
  bool offline = false;
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (offline) throw StateError('offline');
    final uid = request.headers['authorization']!.split(' ').last;
    final current = decks[uid] ?? const CloudDeck([], 0);
    if (request.method == 'GET') {
      return ApiResponse(
        200,
        jsonEncode({'cards': current.cards, 'revision': current.revision}),
      );
    }
    final body = jsonDecode(request.body!) as Map<String, dynamic>;
    if (body['revision'] != current.revision) {
      return ApiResponse(409, jsonEncode({'revision': current.revision}));
    }
    final next = CloudDeck(
      List<String>.from(body['cards'] as List),
      current.revision + 1,
    );
    decks[uid] = next;
    return ApiResponse(
      200,
      jsonEncode({'cards': next.cards, 'revision': next.revision}),
    );
  }
}

class _Storage implements KeyValueStorage {
  final data = <String, String>{};
  @override
  String? read(String key) => data[key];
  @override
  void write(String key, String value) => data[key] = value;
}

void main() {
  test(
    'A and B see the same ordered deck; stale revision cannot overwrite',
    () async {
      final cloud = _Cloud();
      final a = PvpRepository(ApiClient(_Token('same'), cloud));
      final b = PvpRepository(ApiClient(_Token('same'), cloud));
      final first = await a.loadDeck();
      final fromA = await a.saveDeck([
        'sam:1',
        'lira:1',
        'rhea:1',
      ], first.revision);
      final onB = await b.loadDeck();
      expect(onB.cards, fromA.cards);
      final fromB = await b.saveDeck([
        'rhea:1',
        'sam:1',
        'lira:1',
      ], onB.revision);
      expect((await a.loadDeck()).cards, fromB.cards);
      await expectLater(
        a.saveDeck(['sam:1'], fromA.revision),
        throwsA(isA<SaveConflict>()),
      );
      expect((await b.loadDeck()).cards, fromB.cards);
    },
  );

  test(
    'network errors and UID changes leave pending local drafts separate',
    () async {
      final cloud = _Cloud()..offline = true;
      final a = PvpRepository(ApiClient(_Token('a'), cloud));
      await expectLater(a.loadDeck(), throwsA(isA<StateError>()));
      final storage = LocalSaveService(_Storage());
      storage.savePendingDeck('a', ['sam:1'], 2);
      storage.savePendingDeck('b', ['rhea:1'], 4);
      expect(storage.loadPendingDeck('a')?.cards, ['sam:1']);
      expect(storage.loadPendingDeck('b')?.revision, 4);
      storage.clearPendingDeck('a');
      expect(storage.loadPendingDeck('a'), isNull);
      expect(storage.loadPendingDeck('b')?.cards, ['rhea:1']);
    },
  );
}
