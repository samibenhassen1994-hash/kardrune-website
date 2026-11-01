import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/game/card_stat_limits.dart';

void main() {
  test('stage limits match the authoritative balance', () {
    expect(CardStatLimits.forStage(1), const CardStatRange(25, 50, 0, 8));
    expect(CardStatLimits.forStage(2), const CardStatRange(40, 75, 4, 16));
    expect(CardStatLimits.forStage(3), const CardStatRange(60, 100, 8, 25));
  });

  test('effective values clamp historical highs and lows per stage', () {
    expect(CardStatLimits.effective(1, 99, 25), (attack: 50, crit: 8));
    expect(CardStatLimits.effective(2, 1, 0), (attack: 40, crit: 4));
    expect(CardStatLimits.effective(3, 101, 30), (attack: 100, crit: 25));
  });
}
