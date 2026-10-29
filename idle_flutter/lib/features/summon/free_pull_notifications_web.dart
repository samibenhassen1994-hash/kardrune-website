import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get freePullNotificationsGranted =>
    web.Notification.permission == 'granted';

Future<bool> enableFreePullNotifications() async {
  if (freePullNotificationsGranted) return true;
  return (await web.Notification.requestPermission().toDart).toDart ==
      'granted';
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
    return;
  } catch (_) {}
  try {
    web.Notification(
      'KardRune · Free Summon',
      web.NotificationOptions(body: 'A free Standard Summon is ready.'),
    );
  } catch (_) {}
}
