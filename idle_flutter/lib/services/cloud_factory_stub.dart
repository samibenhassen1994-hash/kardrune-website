import '../features/profile/cloud_account_controller.dart';
import '../models/player_save.dart';
import 'local_save_service.dart';

Future<CloudAccountController?> createDefaultCloudController(
  LocalSaveService local,
  void Function(PlayerSave) onRemoteSave,
) async => null;
