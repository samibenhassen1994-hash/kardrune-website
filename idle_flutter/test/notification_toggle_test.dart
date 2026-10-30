import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/summon/notification_toggle.dart';

void main() {
  test('permission is resolved before authenticated remote state', () async {
    final calls = <String>[];

    final enabled = await toggleNotificationState(
      ensurePermission: () async {
        calls.add('permission');
        return true;
      },
      refresh: () async {
        calls.add('refresh');
        return false;
      },
      disable: () async => calls.add('disable'),
      enable: () async {
        calls.add('enable');
        return true;
      },
    );

    expect(enabled, isTrue);
    expect(calls, ['permission', 'refresh', 'enable']);
  });

  test('denied permission avoids all remote notification requests', () async {
    final calls = <String>[];

    final enabled = await toggleNotificationState(
      ensurePermission: () async => false,
      refresh: () async {
        calls.add('refresh');
        return false;
      },
      disable: () async => calls.add('disable'),
      enable: () async {
        calls.add('enable');
        return true;
      },
    );

    expect(enabled, isFalse);
    expect(calls, isEmpty);
  });
}
