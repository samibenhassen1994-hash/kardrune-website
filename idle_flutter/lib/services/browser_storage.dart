import 'package:web/web.dart' as web;

import 'local_save_service.dart';

class BrowserStorage implements KeyValueStorage {
  const BrowserStorage();
  @override
  String? read(String key) => web.window.localStorage.getItem(key);
  @override
  void write(String key, String value) =>
      web.window.localStorage.setItem(key, value);
}
