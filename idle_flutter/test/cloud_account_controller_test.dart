import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:idle_kardrune/app.dart';
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
  final resetEmails = <String>[];
  final emailAttempts = <({String email, bool register})>[];
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
  }) async => emailAttempts.add((email: email, register: register));
  @override
  Future<void> sendPasswordReset(String email) async => resetEmails.add(email);
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

class _SequenceTransport implements ApiTransport {
  _SequenceTransport(this.responses);
  final List<ApiResponse> responses;
  final requests = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return responses.removeAt(0);
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

  test(
    'load after 409 refetches and applies the latest cloud snapshot',
    () async {
      final storage = _Storage(),
          local = LocalSaveService(storage),
          auth = _Auth();
      local.save(PlayerSave.initial().copyWith(shards: 2000));
      storage.values['idle-cloud-last-user-v1'] = 'old';
      final transport = _SequenceTransport([
        const ApiResponse(200, '{}'),
        const ApiResponse(200, '{"save":{"shards":100},"revision":1}'),
        const ApiResponse(409, '{"revision":2}'),
        const ApiResponse(200, '{"save":{"shards":900},"revision":2}'),
      ]);
      final controller = CloudAccountController(
        auth: auth,
        api: ApiClient(auth, transport),
        local: local,
      );
      controller.start();
      auth.emit(const CloudIdentity(uid: 'new'));
      await Future<void>.delayed(Duration.zero);
      await controller.settle;
      await controller.uploadLocal();
      await controller.loadCloud();
      expect(local.load().shards, 900);
      expect(controller.revision, 2);
      expect(
        transport.requests
            .where((request) => request.path == '/api/save')
            .length,
        3,
      );
      controller.dispose();
    },
  );

  test(
    'current Firebase identity and its first stream event reconcile once',
    () async {
      final storage = _Storage(),
          auth = _Auth()..identity = const CloudIdentity(uid: 'u1');
      final transport = _Transport();
      transport.responses = {
        'GET /api/me': const ApiResponse(200, '{}'),
        'GET /api/save': const ApiResponse(200, '{"save":null,"revision":0}'),
        'PUT /api/save': const ApiResponse(200, '{"revision":1}'),
      };
      final controller = CloudAccountController(
        auth: auth,
        api: ApiClient(auth, transport),
        local: LocalSaveService(storage),
      );
      controller.start();
      auth.emit(const CloudIdentity(uid: 'u1'));
      await controller.settle;
      expect(
        transport.requests.where((request) => request.path == '/api/me'),
        hasLength(1),
      );
      expect(
        transport.requests.where((request) => request.method == 'PUT'),
        hasLength(1),
      );
      controller.dispose();
    },
  );

  test('login and logout actions are delegated to Firebase adapter', () async {
    final auth = _Auth();
    final controller = CloudAccountController(
      auth: auth,
      api: ApiClient(auth, _Transport()),
      local: LocalSaveService(_Storage()),
    );
    await controller.signInGoogle();
    await controller.signInEmail(
      'hero@kardrune.com',
      'secret1',
      register: true,
    );
    await controller.sendPasswordReset('hero@kardrune.com');
    await controller.signOut();
    expect(auth.googleCalls, 1);
    expect(auth.emailAttempts.single, (
      email: 'hero@kardrune.com',
      register: true,
    ));
    expect(auth.resetEmails, ['hero@kardrune.com']);
    expect(auth.logoutCalls, 1);
    controller.dispose();
  });

  testWidgets('Profile exposes auth actions at 320x568 without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _Storage(), auth = _Auth(), transport = _Transport();
    transport.responses = {
      'GET /api/me': const ApiResponse(
        200,
        '{"player":{"display_name":"Rune"}}',
      ),
      'GET /api/save': const ApiResponse(200, '{"save":null,"revision":0}'),
      'PUT /api/save': const ApiResponse(200, '{"revision":1}'),
    };
    final cloud = CloudAccountController(
      auth: auth,
      api: ApiClient(auth, transport),
      local: LocalSaveService(storage),
    );
    await tester.pumpWidget(
      KardRuneApp(
        saveService: LocalSaveService(storage),
        cloudController: cloud,
      ),
    );
    await tester.tap(find.text('PROFILE').last);
    await tester.pump();
    expect(find.byKey(const Key('cloud-google')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('cloud-google')));
    expect(auth.googleCalls, 1);
    auth.emit(const CloudIdentity(uid: 'u', email: 'u@test.it'));
    await tester.pump();
    await cloud.settle;
    await tester.pump();
    expect(find.byKey(const Key('cloud-logout')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Profile always exposes Account state when cloud init is unavailable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const KardRuneApp(enableCloudBootstrap: false));
      await tester.tap(find.text('PROFILE').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-section')), findsOneWidget);
      expect(find.byKey(const Key('cloud-retry')), findsOneWidget);
    },
  );

  testWidgets('email dialog offers registration and password recovery', (
    tester,
  ) async {
    final storage = _Storage(), auth = _Auth(), transport = _Transport();
    final cloud = CloudAccountController(
      auth: auth,
      api: ApiClient(auth, transport),
      local: LocalSaveService(storage),
    );
    await tester.pumpWidget(
      KardRuneApp(
        saveService: LocalSaveService(storage),
        cloudController: cloud,
      ),
    );
    await tester.tap(find.text('PROFILE').last);
    await tester.pump();
    await tester.tap(find.byKey(const Key('cloud-email')));
    await tester.pump();
    expect(find.byKey(const Key('cloud-register-mode')), findsOneWidget);
    expect(find.byKey(const Key('cloud-forgot-password')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('cloud-email-field')),
      'hero@kardrune.com',
    );
    await tester.tap(find.byKey(const Key('cloud-forgot-password')));
    await tester.pump();
    expect(auth.resetEmails, ['hero@kardrune.com']);
  });

  test(
    'PvP reward reloads revision after 409 and credits exactly once',
    () async {
      final auth = _Auth()..identity = const CloudIdentity(uid: 'winner');
      final transport = _SequenceTransport([
        const ApiResponse(409, '{"revision":2}'),
        const ApiResponse(200, '{"revision":2,"save":{"shards":100}}'),
        const ApiResponse(
          200,
          '{"revision":3,"reward":100,"save":{"shards":200}}',
        ),
      ]);
      final local = LocalSaveService(_Storage());
      final cloud =
          CloudAccountController(
              auth: auth,
              api: ApiClient(auth, transport),
              local: local,
            )
            ..identity = auth.identity
            ..state = CloudAccountState.synced
            ..revision = 1;

      expect(
        await cloud.claimPvpReward(
          '00000000-0000-0000-0000-000000000001',
          retryDelay: Duration.zero,
        ),
        isTrue,
      );
      expect(transport.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /api/pvp/reward',
        'GET /api/save',
        'POST /api/pvp/reward',
      ]);
      expect(cloud.revision, 3);
      expect(local.load().shards, 200);
      cloud.dispose();
    },
  );

  test('PvP reward retries while Worker history is still pending', () async {
    final auth = _Auth()..identity = const CloudIdentity(uid: 'winner');
    final transport = _SequenceTransport([
      const ApiResponse(404, '{"error":"Match result pending"}'),
      const ApiResponse(
        200,
        '{"revision":2,"reward":100,"save":{"shards":1600}}',
      ),
    ]);
    final cloud =
        CloudAccountController(
            auth: auth,
            api: ApiClient(auth, transport),
            local: LocalSaveService(_Storage()),
          )
          ..identity = auth.identity
          ..state = CloudAccountState.synced
          ..revision = 1;

    expect(
      await cloud.claimPvpReward(
        '00000000-0000-0000-0000-000000000002',
        retryDelay: Duration.zero,
      ),
      isTrue,
    );
    expect(
      transport.requests.where((r) => r.path == '/api/pvp/reward'),
      hasLength(2),
    );
    cloud.dispose();
  });

  test('reconnect discovers and claims an eligible missed win', () async {
    final auth = _Auth()..identity = const CloudIdentity(uid: 'winner');
    final transport = _SequenceTransport([
      const ApiResponse(
        200,
        '{"matchIds":["00000000-0000-0000-0000-000000000003"]}',
      ),
      const ApiResponse(
        200,
        '{"revision":2,"reward":100,"save":{"shards":1600}}',
      ),
      const ApiResponse(200, '{"matchIds":[]}'),
    ]);
    final local = LocalSaveService(_Storage());
    final cloud =
        CloudAccountController(
            auth: auth,
            api: ApiClient(auth, transport),
            local: local,
          )
          ..identity = auth.identity
          ..state = CloudAccountState.synced
          ..revision = 1;

    expect(await cloud.recoverPvpRewards(retryDelay: Duration.zero), 1);
    expect(await cloud.recoverPvpRewards(retryDelay: Duration.zero), 0);
    expect(local.load().shards, 1600);
    cloud.dispose();
  });
}
