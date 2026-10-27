import 'browser_storage.dart';
import 'local_save_service.dart';

LocalSaveService createDefaultLocalSave() =>
    LocalSaveService(const BrowserStorage());
