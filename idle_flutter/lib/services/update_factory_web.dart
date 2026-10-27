import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'app_update_controller.dart';

class _WebUpdateBridge implements DisposableAppUpdateBridge {
  _WebUpdateBridge() {
    _listener = ((web.Event event) => _updates.add(null)).toJS;
    web.window.addEventListener('kardrune-update-available', _listener);
    // In standalone Safari the version event can precede Flutter startup.
    scheduleMicrotask(() {
      if (!_updates.isClosed &&
          web.document.documentElement?.getAttribute('data-kardrune-update') == 'true') {
        _updates.add(null);
      }
    });
  }
  final _updates = StreamController<void>.broadcast();
  late final web.EventListener _listener;
  @override
  Stream<void> get updates => _updates.stream;

  @override
  void applyUpdate() =>
      web.window.dispatchEvent(web.Event('kardrune-apply-update'));

  @override
  void disposeBridge() {
    web.window.removeEventListener('kardrune-update-available', _listener);
    _updates.close();
  }
}

AppUpdateController createDefaultUpdateController() =>
    AppUpdateController(_WebUpdateBridge());
