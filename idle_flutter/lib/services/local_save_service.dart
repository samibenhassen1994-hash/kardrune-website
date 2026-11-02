import 'dart:convert';

import '../models/player_save.dart';

abstract interface class KeyValueStorage {
  String? read(String key);
  void write(String key, String value);
}

class LocalSaveService {
  LocalSaveService(this.storage);
  static const legacySaveKey = 'idle-kardrune-demo-v1',
      deckDraftKey = 'idle-pvp-deck-draft-v1',
      pendingDeckKey = 'idle-pvp-pending-deck-v1';
  final KeyValueStorage storage;
  PlayerSave load({int? nowMs}) {
    final raw = storage.read(legacySaveKey);
    if (raw == null) return PlayerSave.initial();
    try {
      final value = jsonDecode(raw);
      return PlayerSave.fromJson(
        value is Map<String, dynamic> ? value : null,
        nowMs: nowMs,
      );
    } catch (_) {
      return PlayerSave.initial();
    }
  }

  void save(PlayerSave value) =>
      storage.write(legacySaveKey, jsonEncode(value.toJson()));
  List<String> loadDeck() {
    try {
      final value = jsonDecode(storage.read(deckDraftKey) ?? '[]');
      return value is List
          ? value.map((e) => e.toString()).take(9).toList()
          : [];
    } catch (_) {
      return [];
    }
  }

  void saveDeck(List<String> cards) =>
      storage.write(deckDraftKey, jsonEncode(cards.take(9).toList()));

  ({List<String> cards, int revision})? loadPendingDeck(String uid) {
    try {
      final value = jsonDecode(
        storage.read('$pendingDeckKey:$uid') ?? '',
      ) as Map<String, dynamic>;
      if (value['uid'] != uid ||
          value['revision'] is! int ||
          value['cards'] is! List) {
        return null;
      }
      return (
        cards: List<String>.from(value['cards'] as List),
        revision: value['revision'] as int,
      );
    } catch (_) {
      return null;
    }
  }

  void savePendingDeck(String uid, List<String> cards, int revision) =>
      storage.write(
        '$pendingDeckKey:$uid',
        jsonEncode({'uid': uid, 'cards': cards, 'revision': revision}),
      );

  void clearPendingDeck(String uid) {
    if (loadPendingDeck(uid) != null) storage.write('$pendingDeckKey:$uid', '');
  }
}
