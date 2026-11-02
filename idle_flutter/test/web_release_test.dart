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
    expect(index, contains('<meta name="apple-mobile-web-app-title" content="Idle KardRune">'));
    expect(index, contains('<link rel="manifest" href="/idle/manifest.json'));
    // The desktop frame is an actual Flutter host, not CSS-resized canvas.
    expect(index, contains('id="idle-game-frame"'));
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(
      bootstrap,
      contains("hostElement: document.getElementById('idle-game-frame')"),
    );
    expect(index, contains("url.searchParams.set('v', release)"));
    expect(index, contains('workerUrl(pendingRelease)'));
    expect(index, contains('kardrune-update-available'));
    expect(index, contains('kardrune-apply-update'));
    expect(index, contains('release-id.json'));
    expect(index, contains('visibilitychange'));
    final worker = File('web/kardrune_service_worker.js').readAsStringSync();
    expect(worker, contains('__KARDRUNE_PACKAGED_RELEASE__'));
    expect(worker, contains('background_deck.webp'));
    expect(worker, contains('background_fight_idlearena.webp'));
    expect(worker, contains("'release-id.json'"));
    expect(worker, contains('SKIP_WAITING'));
    expect(worker, contains("'./manifest.json'"));
    expect(manifest['name'], 'Idle KardRune');
    expect(manifest['short_name'], 'Idle KardRune');
    // Separate from the parent KardRune Android app and the website root.
    expect(manifest['id'], '/idle/');
    expect(manifest['start_url'], '/idle/');
    expect(manifest['scope'], '/idle/');
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
