import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/profile/cloud_account_controller.dart';
import 'package:idle_kardrune/models/player_save.dart';
import 'package:idle_kardrune/services/api_client.dart';
import 'package:idle_kardrune/services/local_save_service.dart';

class _Storage implements KeyValueStorage {
  final values = <String, String>{};
  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String value) => values[key] = value;
}

class _Auth implements CloudAuthPort {
  final stream = StreamController<CloudIdentity?>.broadcast();
  CloudIdentity? identity;
  int googleCalls = 0, logoutCalls = 0;
  @override
  CloudIdentity? get currentIdentity => identity;
  @override
  Stream<CloudIdentity?> get accountChanges => stream.stream;
  @override
  Future<String> idToken() async => 'token';
  @override
  Future<void> signInGoogle() async {
    googleCalls++;
  }

  @override
  Future<void> signInEmail(
    String email,
    String password, {
    required bool register,
  }) async {}
  @override
  Future<void> signOutAccount() async {
    logoutCalls++;
  }

  void emit(CloudIdentity? value) {
    identity = value;
    stream.add(value);
  }
}

class _Transport implements ApiTransport {
  final requests = <ApiRequest>[];
  Map<String, ApiResponse> responses = {};
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return responses['${request.method} ${request.path}'] ??
        const ApiResponse(500, '{}');
  }
}

void main() {
  test(
    'first account creates cloud backup without changing save schema',
    () async {
      final storage = _Storage(),
          local = LocalSaveService(storage),
          auth = _Auth(),
          transport = _Transport();
      local.save(PlayerSave.initial().copyWith(shards: 1777));
      transport.responses = {
        'GET /api/me': const ApiResponse(
          200,
          '{"player":{"display_name":"Rune"}}',
        ),
        'GET /api/save': const ApiResponse(200, '{"save":null,"revision":0}'),
        'PUT /api/save': const ApiResponse(200, '{"revision":1}'),
      };
      final controller = CloudAccountController(
        auth: auth,
        api: ApiClient(auth, transport),
        local: local,
      );
      controller.start();
      auth.emit(
        const CloudIdentity(uid: 'u1', email: 'a@b.it', displayName: 'Rune'),
      );
      await Future<void>.delayed(Duration.zero);
      await controller.settle;
      expect(controller.state, CloudAccountState.synced);
      final put = transport.requests.singleWhere((r) => r.method == 'PUT');
      expect((jsonDecode(put.body!)['save'] as Map)['shards'], 1777);
      expect(storage.values['idle-cloud-last-user-v1'], 'u1');
      controller.dispose();
    },
  );

  test('409 and account switch require explicit review', () async {
    final storage = _Storage(),
        local = LocalSaveService(storage),
        auth = _Auth(),
        transport = _Transport();
    local.save(PlayerSave.initial().copyWith(shards: 2000));
    storage.values['idle-cloud-last-user-v1'] = 'old';
    transport.responses = {
      'GET /api/me': const ApiResponse(
        200,
        '{"player":{"display_name":"New"}}',
      ),
      'GET /api/save': const ApiResponse(
        200,
        '{"save":{"shards":100},"revision":3}',
      ),
      'PUT /api/save': const ApiResponse(409, '{"revision":4}'),
    };
    final controller = CloudAccountController(
      auth: auth,
      api: ApiClient(auth, transport),
      local: local,
    );
    controller.start();
    auth.emit(const CloudIdentity(uid: 'new', email: 'new@b.it'));
    await Future<void>.delayed(Duration.zero);
    await controller.settle;
    expect(controller.state, CloudAccountState.review);
    expect(local.load().shards, 2000);
    await controller.uploadLocal();
    expect(controller.state, CloudAccountState.review);
    expect(controller.message, contains('changed'));
    controller.dispose();
  });

  test('login and logout actions are delegated to Firebase adapter', () async {
    final auth = _Auth();
    final controller = CloudAccountController(
      auth: auth,
      api: ApiClient(auth, _Transport()),
      local: LocalSaveService(_Storage()),
    );
    await controller.signInGoogle();
    await controller.signOut();
    expect(auth.googleCalls, 1);
    expect(auth.logoutCalls, 1);
    controller.dispose();
  });
}
