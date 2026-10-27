import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/services/api_client.dart';

class Token implements AuthTokenProvider {
  @override
  Future<String> idToken() async => 'firebase-token';
}

class RecordingTransport implements ApiTransport {
  ApiRequest? last;
  ApiResponse response = const ApiResponse(200, '{"revision":2,"saved":true}');
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    last = request;
    return response;
  }
}

void main() {
  test(
    'save PUT preserves endpoint bearer token revision and JSON save',
    () async {
      final transport = RecordingTransport(),
          client = ApiClient(Token(), transport);
      await client.putSave({'name': 'Runebearer'}, 1);
      expect(transport.last?.path, '/api/save');
      expect(transport.last?.method, 'PUT');
      expect(transport.last?.headers['authorization'], 'Bearer firebase-token');
      expect(
        transport.last?.body,
        '{"save":{"name":"Runebearer"},"revision":1}',
      );
    },
  );
  test('revision conflict is surfaced with server revision', () async {
    final transport = RecordingTransport()
      ..response = const ApiResponse(
        409,
        '{"error":"Save conflict","revision":7}',
      );
    final client = ApiClient(Token(), transport);
    await expectLater(
      client.putSave({'name': 'Runebearer'}, 1),
      throwsA(isA<SaveConflict>().having((e) => e.revision, 'revision', 7)),
    );
  });
  test('PvP paths stay under the existing API contract', () async {
    final transport = RecordingTransport(),
        client = ApiClient(Token(), transport);
    await client.post('/api/pvp/live-ticket');
    expect(transport.last?.path, '/api/pvp/live-ticket');
  });
  test('Firebase config request is public and unauthenticated', () async {
    final transport = RecordingTransport(),
        client = ApiClient(Token(), transport);
    await client.getPublic('/api/config');
    expect(transport.last?.headers.containsKey('authorization'), isFalse);
  });

  test('HTTP transport keeps same-origin API paths by default', () {
    final transport = HttpApiTransport();
    expect(transport.resolve('/api/config').toString(), '/api/config');
  });

  test('HTTP transport supports an explicit local API origin', () {
    final transport = HttpApiTransport(apiOrigin: 'http://127.0.0.1:8080');
    expect(
      transport.resolve('/api/config'),
      Uri.parse('http://127.0.0.1:8080/api/config'),
    );
  });
}
