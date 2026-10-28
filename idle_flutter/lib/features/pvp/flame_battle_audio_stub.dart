import 'flame_attack_style.dart';
import 'flame_battle_audio.dart';

FlameBattleAudio createFlameBattleAudio() => _SilentBattleAudio();

class _SilentBattleAudio implements FlameBattleAudio {
  @override
  void unlock() {}
  @override
  void attack(FlameAttackStyle style) {}
  @override
  void impact(FlameAttackStyle style, {required bool critical}) {}
  @override
  void pause() {}
  @override
  void dispose() {}
}
