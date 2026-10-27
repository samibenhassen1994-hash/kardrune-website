import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/services/app_update_controller.dart';

class _Bridge implements AppUpdateBridge {
  final controller = StreamController<void>.broadcast();
  int applies = 0;
  @override
  Stream<void> get updates => controller.stream;
  @override
  void applyUpdate() => applies++;
}

void main() {
  test('update is announced and cannot reload during a match', () async {
    final bridge = _Bridge(), controller = AppUpdateController(bridge)..start();
    bridge.controller.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(controller.available, isTrue);
    controller.setMatchActive(true);
    controller.apply();
    expect(bridge.applies, 0);
    expect(controller.gate.updatePending, isTrue);
    controller.setMatchActive(false);
    expect(bridge.applies, 1);
    controller.dispose();
    await bridge.controller.close();
  });
}
