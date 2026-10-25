import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/services/app_update_gate.dart';

void main() {
  test('PWA metadata is KardRune-specific and base-href buildable', () {
    final index = File('web/index.html').readAsStringSync();
    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(index, contains('<base href="\$FLUTTER_BASE_HREF">'));
    expect(
      index,
      contains(
        'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no',
      ),
    );
    expect(index, contains('<title>Idle KardRune</title>'));
    expect(index, contains("register('kardrune_service_worker.js'"));
    final worker = File('web/kardrune_service_worker.js').readAsStringSync();
    expect(worker, contains("idle-kardrune-v1"));
    expect(worker, contains("'./manifest.json'"));
    expect(manifest['name'], 'Idle KardRune');
    expect(manifest['short_name'], 'KardRune');
    expect(manifest['start_url'], '.');
    expect(manifest['scope'], '.');
    expect(manifest['theme_color'], '#090D19');
  });

  test('app update waits until a live match has ended', () {
    final gate = AppUpdateGate();
    var reloads = 0;
    gate.setMatchActive(true);
    gate.requestReload(() => reloads++);
    expect(reloads, 0);
    expect(gate.updatePending, isTrue);
    gate.setMatchActive(false);
    expect(reloads, 1);
    expect(gate.updatePending, isFalse);
  });
}
