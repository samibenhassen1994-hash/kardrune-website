import '../../services/api_client.dart';

bool get freePullNotificationsGranted => false;
Future<bool> enableFreePullNotifications({ApiClient? api, String? uid}) async =>
    false;
Future<bool> refreshFreePullNotifications({
  ApiClient? api,
  String? uid,
}) async => false;
Future<bool> toggleFreePullNotifications({ApiClient? api, String? uid}) async =>
    false;
Future<void> disableFreePullNotifications({ApiClient? api}) async {}
Future<void> notificationAccountChanged(String uid) async {}
Future<void> showFreePullNotification() async {}
