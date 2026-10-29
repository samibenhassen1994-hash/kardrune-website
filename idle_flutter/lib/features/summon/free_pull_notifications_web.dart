import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../services/api_client.dart';

@JS('kardrunePushSubscribe')
external JSPromise<JSString> _subscribe(JSString uid);
@JS('kardrunePushUnsubscribe')
external JSPromise<JSString> _unsubscribe();
@JS('kardrunePushAccountChanged')
external void _accountChanged(JSString uid);

bool get freePullNotificationsGranted => web.Notification.permission == 'granted';

Future<bool> enableFreePullNotifications({ApiClient? api,String? uid}) async {
  if(api == null || uid == null) {
    if(freePullNotificationsGranted) return true;
    return (await web.Notification.requestPermission().toDart).toDart == 'granted';
  }
  final response=jsonDecode((await _subscribe(uid.toJS).toDart).toDart) as Map<String,dynamic>;
  if(response['error'] != null) throw StateError(response['error'].toString());
  if(response['subscription'] is! Map) return false;
  await api.post('/api/notifications/subscription',{'subscription':response['subscription']});
  await api.request('/api/notifications/preferences','PUT',{'topic':'free_pull','enabled':true});
  return true;
}
Future<void> disableFreePullNotifications({ApiClient? api}) async {
  if(api != null) await api.request('/api/notifications/preferences','PUT',{'topic':'free_pull','enabled':false});
  final response=jsonDecode((await _unsubscribe().toDart).toDart) as Map<String,dynamic>;
  if(api != null && response['endpoint'] is String) await api.request('/api/notifications/subscription','DELETE',{'endpoint':response['endpoint']});
}
void notificationAccountChanged(String uid)=>_accountChanged(uid.toJS);

Future<void> showFreePullNotification() async {
  if(!freePullNotificationsGranted) return;
  try {
    final registration=await web.window.navigator.serviceWorker.ready.toDart;
    await registration.showNotification('KardRune · Free Summon',
      web.NotificationOptions(body:'A free Standard Summon is ready.')).toDart;
  }catch(_){}
}
