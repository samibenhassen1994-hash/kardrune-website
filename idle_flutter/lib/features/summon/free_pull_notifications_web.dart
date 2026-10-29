import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../services/api_client.dart';

@JS('kardrunePushSubscribe')
external JSPromise<JSString> _subscribe(JSString uid);
@JS('kardrunePushUnsubscribe')
external JSPromise<JSString> _unsubscribe();
@JS('kardrunePushStatus')
external JSPromise<JSString> _status(JSString uid);
@JS('kardrunePushCommit')
external void _commit(JSString uid);
@JS('kardrunePushAccountChanged')
external JSPromise<JSAny?> _accountChanged(JSString uid);

bool _notificationsEnabled = false;
bool get freePullNotificationsGranted => _notificationsEnabled;
const _guestOptInKey = 'idle-free-pull-local-notifications';

Future<bool> refreshFreePullNotifications({ApiClient? api, String? uid}) async {
  if (api == null || uid == null) {
    _notificationsEnabled =
        web.Notification.permission == 'granted' &&
        web.window.localStorage.getItem(_guestOptInKey) == '1';
    return _notificationsEnabled;
  }
  try {
    final browser = jsonDecode(
      (await _status(uid.toJS).toDart).toDart,
    ) as Map<String, dynamic>;
    final remote = await api.get('/api/notifications/preferences');
    final prefs = remote['preferences'];
    _notificationsEnabled =
        browser['active'] == true && prefs is Map && prefs['free_pull'] == true;
  } catch (_) {
    _notificationsEnabled = false;
  }
  return _notificationsEnabled;
}

Future<bool> enableFreePullNotifications({ApiClient? api, String? uid}) async {
  if (api == null || uid == null) {
    if (web.Notification.permission != 'granted') {
      _notificationsEnabled =
          (await web.Notification.requestPermission().toDart).toDart ==
          'granted';
    } else {
      _notificationsEnabled = true;
    }
    if (_notificationsEnabled) {
      web.window.localStorage.setItem(_guestOptInKey, '1');
    }
    return _notificationsEnabled;
  }
  final response = jsonDecode(
    (await _subscribe(uid.toJS).toDart).toDart,
  ) as Map<String, dynamic>;
  if (response['error'] != null) throw StateError(response['error'].toString());
  if (response['subscription'] is! Map) return false;
  try {
    await api.post('/api/notifications/subscription', {
      'subscription': response['subscription'],
    });
    await api.request('/api/notifications/preferences', 'PUT', {
      'topic': 'free_pull',
      'enabled': true,
    });
    _commit(uid.toJS);
    _notificationsEnabled = true;
    return true;
  } catch (_) {
    final endpoint = (response['subscription'] as Map)['endpoint'];
    if (endpoint is String) {
      try {
        await api.request('/api/notifications/subscription', 'DELETE', {
          'endpoint': endpoint,
        });
      } catch (_) {}
    }
    try {
      await _unsubscribe().toDart;
    } catch (_) {}
    _notificationsEnabled = false;
    rethrow;
  }
}

Future<void> disableFreePullNotifications({ApiClient? api}) async {
  Object? failure;
  if (api != null) {
    try {
      await api.request('/api/notifications/preferences', 'PUT', {
        'topic': 'free_pull',
        'enabled': false,
      });
    } catch (error) {
      failure = error;
    }
  }
  Map<String, dynamic> response = {};
  try {
    response = jsonDecode(
      (await _unsubscribe().toDart).toDart,
    ) as Map<String, dynamic>;
  } catch (error) {
    failure ??= error;
  }
  if (api != null && response['endpoint'] is String) {
    try {
      await api.request('/api/notifications/subscription', 'DELETE', {
        'endpoint': response['endpoint'],
      });
    } catch (error) {
      failure ??= error;
    }
  }
  _notificationsEnabled = false;
  if (api == null) web.window.localStorage.removeItem(_guestOptInKey);
  if (failure != null) throw failure;
}

Future<bool> toggleFreePullNotifications({ApiClient? api, String? uid}) async {
  final active = await refreshFreePullNotifications(api: api, uid: uid);
  if (active) {
    await disableFreePullNotifications(api: api);
    return false;
  }
  return enableFreePullNotifications(api: api, uid: uid);
}

Future<void> notificationAccountChanged(String uid) async {
  await _accountChanged(uid.toJS).toDart;
  _notificationsEnabled = false;
}

Future<void> showFreePullNotification() async {
  if (!freePullNotificationsGranted) return;
  try {
    final registration = await web.window.navigator.serviceWorker.ready.toDart;
    await registration
        .showNotification(
          'KardRune · Free Summon',
          web.NotificationOptions(body: 'A free Standard Summon is ready.'),
        )
        .toDart;
  } catch (_) {}
}
