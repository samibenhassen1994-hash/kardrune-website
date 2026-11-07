import 'dart:async';

import '../features/profile/cloud_account_controller.dart';
import '../models/player_save.dart';
import 'api_client.dart';
import 'firebase_auth_service.dart';
import 'local_save_service.dart';
import 'mobile_auth_bridge_web.dart';

class _PublicOnlyAuth implements AuthTokenProvider {
  @override
  Future<String> idToken() => throw const ApiFailure(401, 'Sign in first');
}

Future<CloudAccountController?> createDefaultCloudController(
  LocalSaveService local,
  void Function(PlayerSave) onRemoteSave,
) async {
  const apiOrigin = String.fromEnvironment('IDLE_API_ORIGIN');
  final transport = HttpApiTransport(apiOrigin: apiOrigin);
  final mobileHandoff = isMobileArenaHandoff;
  FirebaseAuthService? auth;
  try {
    auth = await FirebaseAuthService.initialize(
      ApiClient(_PublicOnlyAuth(), transport),
    );
  } catch (_) {
    if (mobileHandoff) markMobileAuthFailure('network_failed');
    rethrow;
  }
  if (auth == null) {
    if (mobileHandoff) markMobileAuthFailure('firebase_failed');
    return null;
  }
  if (mobileHandoff) {
    try {
      await auth.signOut();
    } catch (_) {
      markMobileAuthFailure('firebase_failed');
      rethrow;
    }
    late final String code;
    try {
      code = await waitForMobileCode();
    } on TimeoutException {
      markMobileAuthFailure('handoff_timeout');
      rethrow;
    }
    late final Map<String, Object?> response;
    try {
      response = await ApiClient(
        _PublicOnlyAuth(),
        transport,
      ).postPublic('/api/mobile-auth/exchange', {'code': code});
    } catch (_) {
      markMobileAuthFailure('firebase_failed');
      rethrow;
    }
    final token = response['customToken'];
    if (token is! String || token.isEmpty) {
      markMobileAuthFailure('firebase_failed');
      throw const FormatException('Invalid mobile authentication response');
    }
    try {
      await auth.auth.signInWithCustomToken(token);
    } catch (_) {
      markMobileAuthFailure('firebase_failed');
      rethrow;
    }
  }
  return CloudAccountController(
    auth: auth,
    api: ApiClient(auth, transport),
    local: local,
    onRemoteSave: onRemoteSave,
    mobileHandoff: mobileHandoff,
  );
}

Future<void> completeMobileBootstrap(CloudAccountController controller) async {
  if (!isMobileArenaHandoff) return;
  await controller.settle;
  if (controller.state == CloudAccountState.synced ||
      controller.state == CloudAccountState.review) {
    markMobileAuthComplete();
  } else if (controller.state == CloudAccountState.error) {
    markMobileAuthFailure('sync_failed');
  }
}
