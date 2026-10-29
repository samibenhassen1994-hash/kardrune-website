import '../../services/api_client.dart';
bool get freePullNotificationsGranted => false;
Future<bool> enableFreePullNotifications({ApiClient? api,String? uid}) async => false;
Future<void> disableFreePullNotifications({ApiClient? api}) async {}
void notificationAccountChanged(String uid) {}
Future<void> showFreePullNotification() async {}
