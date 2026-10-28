import 'flame_attack_style.dart';
import 'flame_battle_audio_stub.dart'
    if (dart.library.js_interop) 'flame_battle_audio_web.dart'
    as platform;

abstract interface class FlameBattleAudio {
  void unlock();
  void attack(FlameAttackStyle style);
  void impact(FlameAttackStyle style, {required bool critical});
  void pause();
  void dispose();
}

FlameBattleAudio createFlameBattleAudio() => platform.createFlameBattleAudio();
