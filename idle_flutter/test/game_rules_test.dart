import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/game/game_rules.dart';

void main() {
  test('training chance and rewards preserve JS boundaries', () {
    expect(GameRules.practiceWinChance(42, 1), 0.64);
    expect(GameRules.practiceWinChance(-100, 1), 0.05);
    expect(GameRules.practiceWinChance(1000, 3), 0.90);
    final now = DateTime(2026, 10, 25, 12).millisecondsSinceEpoch;
    final result = GameRules.resolvePractice(
      const DailyRewardState(day: '2026-10-25', count: 9), 42, 1, 0.63, now);
    expect(result.win, isTrue);
    expect(result.reward, 100);
    expect(result.daily.count, 10);
    expect(GameRules.resolvePractice(result.daily, 42, 1, 0.9, now).reward, 0);
  });
}
