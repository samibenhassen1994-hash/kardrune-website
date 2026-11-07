import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/clans/clan_invite_persistence.dart';
import 'package:idle_kardrune/services/local_save_service.dart';

class _MemoryStorage implements KeyValueStorage {
  final values = <String, String>{};
  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String value) => values[key] = value;
}

void main() {
  const invite = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const nextInvite = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  test('normal launch ignores a stale invite saved by previous versions', () {
    final storage = _MemoryStorage()
      ..write(ClanInvitePersistence.legacyKey, invite);
    expect(ClanInvitePersistence.read(storage), isNull);
    expect(storage.read(ClanInvitePersistence.legacyKey), isEmpty);
  });

  test('new invitation survives login redirect and is cleared on dismiss', () {
    final storage = _MemoryStorage();
    expect(ClanInvitePersistence.read(storage, incoming: invite), invite);
    expect(ClanInvitePersistence.read(storage), invite);
    ClanInvitePersistence.clear(storage);
    expect(ClanInvitePersistence.read(storage), isNull);
  });

  test('later different invite can still be opened after a dismissal', () {
    final storage = _MemoryStorage();
    ClanInvitePersistence.read(storage, incoming: invite);
    ClanInvitePersistence.clear(storage);
    expect(
      ClanInvitePersistence.read(storage, incoming: nextInvite),
      nextInvite,
    );
  });

  test('invalid invite is ignored and pending state is cleared', () {
    final storage = _MemoryStorage()
      ..write(ClanInvitePersistence.pendingKey, invite);
    expect(
      ClanInvitePersistence.read(storage, incoming: 'invalid'),
      isNull,
    );
    expect(storage.read(ClanInvitePersistence.pendingKey), isEmpty);
  });

  test('legacy data never reopens after a fresh invitation is handled', () {
    final storage = _MemoryStorage()
      ..write(ClanInvitePersistence.legacyKey, invite);
    expect(
      ClanInvitePersistence.read(storage, incoming: nextInvite),
      nextInvite,
    );
    ClanInvitePersistence.clear(storage);
    expect(ClanInvitePersistence.read(storage), isNull);
  });
}
