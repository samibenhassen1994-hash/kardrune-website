import '../features/profile/cloud_account_controller.dart';
import '../models/player_save.dart';
import 'api_client.dart';
import 'firebase_auth_service.dart';
import 'local_save_service.dart';

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
  return CloudAccountController(
    auth: auth,
    api: ApiClient(auth, transport),
    local: local,
    onRemoteSave: onRemoteSave,
  );
}
