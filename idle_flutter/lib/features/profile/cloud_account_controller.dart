import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/player_save.dart';
import '../../repositories/save_repository.dart';
import '../../services/api_client.dart';
import '../../services/local_save_service.dart';

class CloudIdentity {
  const CloudIdentity({required this.uid, this.email, this.displayName});
  final String uid;
  final String? email, displayName;
}

abstract interface class CloudAuthPort implements AuthTokenProvider {
  CloudIdentity? get currentIdentity;
  Stream<CloudIdentity?> get accountChanges;
  Future<void> signInGoogle();
  Future<void> signInEmail(
    String email,
    String password, {
    required bool register,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> signOutAccount();
}

enum CloudAccountState { signedOut, loading, synced, review, error }

class CloudAccountController extends ChangeNotifier {
  CloudAccountController({
    required this.auth,
    required this.api,
    required this.local,
    this.onRemoteSave,
  });
  static const lastUserKey = 'idle-cloud-last-user-v1';
  static const guestBackupPrefix = 'idle-guest-before-cloud-v1:';

  final CloudAuthPort auth;
  final ApiClient api;
  final LocalSaveService local;
  final ValueChanged<PlayerSave>? onRemoteSave;
  StreamSubscription<CloudIdentity?>? _subscription;
  Future<void> _settle = Future.value();
  Timer? _syncTimer;
  String? _observedUid;
  bool _hasObservedAccount = false;
  CloudIdentity? identity;
  CloudAccountState state = CloudAccountState.signedOut;
  String message = 'Local save';
  int revision = 0;
  Map<String, Object?>? remoteSave;

  Future<void> get settle => _settle;
  String get _linkKey => 'idle-cloud-sync-v1:${identity!.uid}';
  String? get _guestBackupKey {
    final uid = identity?.uid ?? local.storage.read(lastUserKey);
    return uid == null ? null : '$guestBackupPrefix$uid';
  }
  bool get hasGuestBackup => _guestBackupKey != null &&
      local.storage.read(_guestBackupKey!) != null;

  void start() {
    _subscription ??= auth.accountChanges.listen((account) {
      _enqueueAccount(account);
    });
    _enqueueAccount(auth.currentIdentity);
  }

  void _enqueueAccount(CloudIdentity? account) {
    final uid = account?.uid;
    if (_hasObservedAccount && uid == _observedUid) return;
    _hasObservedAccount = true;
    _observedUid = uid;
    _settle = _settle.then((_) => _handleAccount(account));
  }

  Future<void> _handleAccount(CloudIdentity? account) async {
    _syncTimer?.cancel();
    identity = account;
    if (account == null) {
      state = CloudAccountState.signedOut;
      message = 'Local save · sign in to enable cloud backup';
      notifyListeners();
      return;
    }
    state = CloudAccountState.loading;
    message = 'Checking cloud save…';
    notifyListeners();
    try {
      await api.get('/api/me');
      final response = await api.get('/api/save');
      if (identity?.uid != account.uid) return;
      revision = response['revision'] is int ? response['revision'] as int : 0;
      remoteSave = response['save'] is Map
          ? Map<String, Object?>.from(response['save'] as Map)
          : null;
      final previousUid = local.storage.read(lastUserKey);
      final link = _readLink();
      final localJson = jsonEncode(local.load().toJson());
      final remoteJson = remoteSave == null ? null : jsonEncode(remoteSave);
      if (previousUid != null && previousUid != account.uid && link == null) {
        _review(
          'Different account on this device. Choose local or cloud progress.',
        );
      } else if (remoteSave == null && revision == 0) {
        if ((previousUid != null && previousUid != account.uid) ||
            (link?.revision ?? 0) > 0) {
          _review(
            'No cloud save for this account. Review before importing this device.',
          );
        } else {
          await _upload(auto: true);
        }
      } else {
        final decision = SaveRepository.decisionForAccount(
          local: localJson,
          remote: remoteJson,
          revision: revision,
          link: link,
          previousUid: previousUid,
          currentUid: account.uid,
        );
        switch (decision) {
          case SyncDecision.adopt:
          case SyncDecision.synced:
            _writeLink(revision, localJson);
            state = CloudAccountState.synced;
            message = 'Cloud backup active · revision $revision';
          case SyncDecision.upload:
            await _upload(auto: true);
          case SyncDecision.download:
            _review(
              'Newer cloud progress found. Review before replacing this device.',
            );
          case SyncDecision.review:
            _review(
              'Local and cloud progress differ. Choose which progress to keep.',
            );
        }
      }
      local.storage.write(lastUserKey, account.uid);
      notifyListeners();
    } catch (error) {
      state = CloudAccountState.error;
      message = _errorText(error);
      notifyListeners();
    }
  }

  SaveLink? _readLink() {
    try {
      final value = jsonDecode(local.storage.read(_linkKey) ?? 'null');
      return value is Map &&
              value['revision'] is int &&
              value['snapshot'] is String
          ? SaveLink(value['revision'] as int, value['snapshot'] as String)
          : null;
    } catch (_) {
      return null;
    }
  }

  void _writeLink(int nextRevision, String snapshot) => local.storage.write(
    _linkKey,
    jsonEncode({
      'revision': nextRevision,
      'snapshot': snapshot,
      'enabled': true,
    }),
  );

  void _review(String value) {
    state = CloudAccountState.review;
    message = value;
  }

  Future<void> _upload({required bool auto}) async {
    try {
      final save = local.load();
      if (revision == 0 && _guestBackupKey != null && !hasGuestBackup) {
        local.storage.write(_guestBackupKey!, jsonEncode(save.toJson()));
      }
      final response = await api.putSave(save.toJson(), revision);
      revision = response['revision'] is int
          ? response['revision'] as int
          : revision + 1;
      final canonical = response['save'] is Map
          ? PlayerSave.fromJson(Map<String, Object?>.from(response['save'] as Map))
          : save;
      if (response['save'] is Map) {
        local.save(canonical);
        onRemoteSave?.call(canonical);
      }
      final snapshot = jsonEncode(canonical.toJson());
      _writeLink(revision, snapshot);
      remoteSave = canonical.toJson();
      state = CloudAccountState.synced;
      message = hasGuestBackup
          ? 'Cloud saved · offline snapshot retained on this device'
          : 'Saved automatically · revision $revision';
      notifyListeners();
    } on SaveConflict catch (error) {
      revision = error.revision;
      _review(
        'Cloud progress changed on another device. Review saves before continuing.',
      );
      notifyListeners();
    } catch (error) {
      state = auto ? CloudAccountState.error : CloudAccountState.review;
      message = _errorText(error);
      notifyListeners();
    }
  }

  Future<void> uploadLocal() => _upload(auto: false);

  Future<bool> prepareServerMutation() async {
    _syncTimer?.cancel();
    if (identity == null || state != CloudAccountState.synced) return false;
    final snapshot = jsonEncode(local.load().toJson());
    if (_readLink()?.snapshot != snapshot) await _upload(auto: true);
    return identity != null && state == CloudAccountState.synced;
  }

  Future<void> restoreGuestBackup() async {
    final key = _guestBackupKey;
    if (key == null) return;
    final raw = local.storage.read(key);
    if (raw == null) return;
    await auth.signOutAccount();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final save = PlayerSave.fromJson(Map<String, Object?>.from(decoded));
    local.save(save);
    onRemoteSave?.call(save);
    state = CloudAccountState.signedOut;
    message = 'Offline snapshot restored. Cloud account signed out.';
    notifyListeners();
  }

  void applyServerSave(Map<String, dynamic> response) {
    final raw = response['save'];
    if (identity == null || raw is! Map || response['revision'] is! int) return;
    final save = PlayerSave.fromJson(Map<String, Object?>.from(raw));
    revision = response['revision'] as int;
    remoteSave = save.toJson();
    local.save(save);
    onRemoteSave?.call(save);
    _writeLink(revision, jsonEncode(save.toJson()));
    state = CloudAccountState.synced;
    message = 'Cloud progress saved · revision $revision';
    notifyListeners();
  }

  Future<void> loadCloud() async {
    try {
      final response = await api.get('/api/save');
      revision = response['revision'] is int
          ? response['revision'] as int
          : revision;
      remoteSave = response['save'] is Map
          ? Map<String, Object?>.from(response['save'] as Map)
          : null;
    } catch (error) {
      _review(_errorText(error));
      notifyListeners();
      return;
    }
    if (remoteSave == null) {
      _review('No cloud backup is available.');
      notifyListeners();
      return;
    }
    final save = PlayerSave.fromJson(remoteSave);
    local.save(save);
    onRemoteSave?.call(save);
    _writeLink(revision, jsonEncode(save.toJson()));
    state = CloudAccountState.synced;
    message = 'Cloud progress loaded · revision $revision';
    notifyListeners();
  }

  void localChanged({bool important = false}) {
    if (state != CloudAccountState.synced || identity == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(
      important
          ? const Duration(milliseconds: 250)
          : const Duration(seconds: 5),
      () {
        _settle = _upload(auto: true);
      },
    );
  }

  Future<bool> _authAction(Future<void> Function() action) async {
    state = CloudAccountState.loading;
    message = 'Contacting Firebase…';
    notifyListeners();
    try {
      await action();
      message = 'Authentication complete. Loading account…';
      notifyListeners();
      return true;
    } catch (_) {
      state = CloudAccountState.error;
      message = 'Authentication failed. Check your details and try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInGoogle() => _authAction(auth.signInGoogle);
  Future<bool> signInEmail(
    String email,
    String password, {
    required bool register,
  }) =>
      _authAction(() => auth.signInEmail(email, password, register: register));
  Future<bool> sendPasswordReset(String email) async {
    final sent = await _authAction(() => auth.sendPasswordReset(email));
    if (sent) {
      state = CloudAccountState.signedOut;
      message = 'Password reset email sent.';
      notifyListeners();
    }
    return sent;
  }

  Future<bool> signOut() => _authAction(auth.signOutAccount);

  String _errorText(Object error) => error is ApiFailure
      ? error.message
      : 'Cloud unavailable. Local progress is safe.';

  @override
  void dispose() {
    _syncTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
