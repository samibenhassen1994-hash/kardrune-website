@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:idle_kardrune/services/mobile_auth_bridge_web.dart';

void main() {
  tearDown(clearMobileAuthSignals);

  test('mobile handoff exposes a safe Firebase failure to Android', () {
    markMobileAuthFailure('firebase_failed');

    expect(
      web.window.localStorage.getItem('kardrune-mobile-auth-error'),
      'firebase_failed',
    );
    expect(
      web.window.localStorage.getItem('kardrune-mobile-auth-complete'),
      isNull,
    );
  });

  test(
    'clearing handoff signals removes status without touching save data',
    () {
      web.window.localStorage.setItem('idle-save', 'preserved');
      markMobileAuthFailure('network_failed');

      clearMobileAuthSignals();

      expect(
        web.window.localStorage.getItem('kardrune-mobile-auth-error'),
        isNull,
      );
      expect(web.window.localStorage.getItem('idle-save'), 'preserved');
      web.window.localStorage.removeItem('idle-save');
    },
  );
}
