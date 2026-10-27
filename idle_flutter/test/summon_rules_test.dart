import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/game/summon_rules.dart';

void main() {
  test('standard and featured thresholds match JavaScript', () {
    expect(SummonRules.stageFor(false, 0.779999), 1);
    expect(SummonRules.stageFor(false, 0.78), 2);
    expect(SummonRules.stageFor(false, 0.97), 3);
    expect(SummonRules.stageFor(true, 0.599999), 1);
    expect(SummonRules.stageFor(true, 0.60), 2);
    expect(SummonRules.stageFor(true, 0.90), 3);
    expect(SummonRules.cost(false), 300);
    expect(SummonRules.cost(true), 600);
    expect(SummonRules.heroIndex(true, 0.349, 0.9), 3);
    expect(SummonRules.heroIndex(true, 0.35, 0.999), 8);
  });
  test('duplicate decisions preserve stats and refund rules', () {
    expect(SummonRules.resolveDuplicate(replace: false).refund, 100);
    expect(SummonRules.resolveDuplicate(replace: true).refund, 0);
    expect(SummonRules.resolveDuplicate(replace: true).useNewStats, isTrue);
  });
}
