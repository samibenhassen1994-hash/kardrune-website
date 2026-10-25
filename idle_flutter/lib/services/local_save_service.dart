import 'dart:convert';
import '../models/player_save.dart';

abstract interface class KeyValueStorage { String? read(String key); void write(String key, String value); }

class LocalSaveService {
  LocalSaveService(this.storage);
  static const legacySaveKey='idle-kardrune-demo-v1', deckDraftKey='idle-pvp-deck-draft-v1';
  final KeyValueStorage storage;
  PlayerSave load({int? nowMs}) { final raw=storage.read(legacySaveKey); if(raw==null)return PlayerSave.initial(); try { final value=jsonDecode(raw); return PlayerSave.fromJson(value is Map<String,dynamic>?value:null,nowMs:nowMs); } catch (_) { return PlayerSave.initial(); } }
  void save(PlayerSave value)=>storage.write(legacySaveKey,jsonEncode(value.toJson()));
}
