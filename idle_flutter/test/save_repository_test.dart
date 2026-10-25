import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/models/player_save.dart';
import 'package:idle_kardrune/repositories/save_repository.dart';
import 'package:idle_kardrune/services/local_save_service.dart';

class MemoryStorage implements KeyValueStorage {
  final values = <String, String>{};
  @override String? read(String key) => values[key];
  @override void write(String key, String value) => values[key] = value;
}

void main() {
  test('imports the legacy save key without deleting or rewriting it', () {
    final storage = MemoryStorage();
    storage.values[LocalSaveService.legacySaveKey] = jsonEncode(PlayerSave.initial().toJson());
    final service = LocalSaveService(storage);
    final loaded = service.load(nowMs: DateTime(2026, 10, 25).millisecondsSinceEpoch);
    expect(loaded.active, 'sam:1');
    expect(storage.values[LocalSaveService.legacySaveKey], isNotNull);
  });

  test('sync decisions match legacy conflict protection', () {
    expect(SaveRepository.decide('old', 'old', 1, null), SyncDecision.adopt);
    expect(SaveRepository.decide('new', 'old', 1, const SaveLink(1, 'old')), SyncDecision.upload);
    expect(SaveRepository.decide('old', 'remote', 2, const SaveLink(1, 'old')), SyncDecision.download);
    expect(SaveRepository.decide('new', 'remote', 2, const SaveLink(1, 'old')), SyncDecision.review);
    expect(SaveRepository.decide('old', null, 0, null), SyncDecision.review);
  });

  test('account switches never auto-upload an unlinked local save', () {
    expect(SaveRepository.decisionForAccount(local: 'local', remote: 'cloud', revision: 2,
      link: null, previousUid: 'one', currentUid: 'two'), SyncDecision.review);
  });
  test('temporary cloud failures back off to the legacy two minute cap', () {
    expect([1,2,3,4,5].map(SaveRepository.retryDelay), const [Duration(seconds:15),Duration(seconds:30),Duration(seconds:60),Duration(seconds:120),Duration(seconds:120)]);
  });
}
