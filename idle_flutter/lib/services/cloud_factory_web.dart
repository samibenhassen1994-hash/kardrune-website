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
  final auth = await FirebaseAuthService.initialize(
    ApiClient(_PublicOnlyAuth(), transport),
  );
  if (auth == null) return null;
  final mobileHandoff = isMobileArenaHandoff;
  if (mobileHandoff) {
    await auth.signOut();
    final code = await waitForMobileCode();
    final response = await ApiClient(
      _PublicOnlyAuth(),
      transport,
    ).postPublic('/api/mobile-auth/exchange', {'code': code});
    final token = response['customToken'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Invalid mobile authentication response');
    }
    await auth.auth.signInWithCustomToken(token);
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
  }
}
