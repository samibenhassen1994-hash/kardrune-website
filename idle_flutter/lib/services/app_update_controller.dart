import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_update_gate.dart';

abstract interface class AppUpdateBridge {
  Stream<void> get updates;
  void applyUpdate();
}

class AppUpdateController extends ChangeNotifier {
  AppUpdateController(this.bridge, {AppUpdateGate? gate})
    : gate = gate ?? AppUpdateGate();
  final AppUpdateBridge bridge;
  final AppUpdateGate gate;
  StreamSubscription<void>? _subscription;
  bool available = false;

  void start() {
    _subscription ??= bridge.updates.listen((_) {
      available = true;
      notifyListeners();
    });
  }

  void setMatchActive(bool active) => gate.setMatchActive(active);

  void apply() {
    gate.requestReload(() {
      available = false;
      bridge.applyUpdate();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
