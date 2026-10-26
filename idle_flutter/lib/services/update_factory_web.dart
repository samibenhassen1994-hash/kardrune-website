import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'app_update_controller.dart';

class _WebUpdateBridge implements AppUpdateBridge {
  _WebUpdateBridge() {
    _listener = ((web.Event event) => _updates.add(null)).toJS;
    web.window.addEventListener('kardrune-update-available', _listener);
  }
  final _updates = StreamController<void>.broadcast();
  late final web.EventListener _listener;
  @override
  Stream<void> get updates => _updates.stream;

  @override
  void applyUpdate() =>
      web.window.dispatchEvent(web.Event('kardrune-apply-update'));
}

AppUpdateController createDefaultUpdateController() =>
    AppUpdateController(_WebUpdateBridge());
