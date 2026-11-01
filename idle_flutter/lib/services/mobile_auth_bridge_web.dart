import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const _readyKey = 'kardrune-mobile-auth-ready';
const _completeKey = 'kardrune-mobile-auth-complete';

bool get isMobileArenaHandoff =>
    Uri.parse(web.window.location.href).queryParameters['embedded'] ==
    'android';

Future<String> waitForMobileCode() async {
  final completer = Completer<String>();
  web.window.localStorage.removeItem(_completeKey);
  web.window.localStorage.removeItem(_readyKey);
  late final web.EventListener listener;
  listener = ((web.Event event) {
    final message = event as web.MessageEvent;
    if (message.origin != web.window.location.origin ||
        message.source != web.window) {
      return;
    }
    final data = message.data.dartify();
    if (data is! Map ||
        data['kind'] != 'kardrune-mobile-auth' ||
        data['code'] is! String) {
      return;
    }
    final code = data['code'] as String;
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(code)) {
      return;
    }
    if (!completer.isCompleted) completer.complete(code);
  }).toJS;
  web.window.addEventListener('message', listener);
  web.window.localStorage.setItem(_readyKey, '1');
  try {
    return await completer.future.timeout(const Duration(seconds: 30));
  } finally {
    web.window.localStorage.removeItem(_readyKey);
    web.window.removeEventListener('message', listener);
  }
}

void markMobileAuthComplete() =>
    web.window.localStorage.setItem(_completeKey, '1');
