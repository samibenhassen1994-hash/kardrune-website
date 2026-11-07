import '../../services/local_save_service.dart';

/// Handles one-shot clan invitations, including an optional login redirect.
abstract final class ClanInvitePersistence {
  static const legacyKey = 'idle-clan-invite-v1';
  static const pendingKey = 'idle-clan-pending-invite-v2';
  static final RegExp _validCode = RegExp(r'^[a-f0-9-]{32,36}$');

  static String? read(KeyValueStorage? storage, {String? incoming}) {
    // Older releases never consumed this key, so ignore old stored invites.
    if ((storage?.read(legacyKey) ?? '').isNotEmpty) {
      storage?.write(legacyKey, '');
    }
    final candidate = incoming ?? storage?.read(pendingKey);
    if (candidate == null || !_validCode.hasMatch(candidate)) {
      if ((storage?.read(pendingKey) ?? '').isNotEmpty) {
        storage?.write(pendingKey, '');
      }
      return null;
    }
    if (incoming != null) storage?.write(pendingKey, incoming);
    return candidate;
  }

  /// Do not clear until the invite was handled, dismissed, or canceled.
  static void clear(KeyValueStorage? storage) {
    storage?.write(pendingKey, '');
  }
}
