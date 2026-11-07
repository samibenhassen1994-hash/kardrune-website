import 'dart:js_interop';
import 'package:web/web.dart' as web;
Future<bool> shareClan(String url) async {
 try { await web.window.navigator.share(web.ShareData(title: 'Rune Clans', url: url)).toDart; return true; } catch (_) { return false; }
}
