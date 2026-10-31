import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/game/combat_rules.dart';

void main() {
  test('HP attack critical and legacy values match JavaScript', () {
    expect([1, 2, 3].map(CombatRules.hpForStage), [240, 340, 430]);
    expect(CombatRules.rollAttack(1, () => 0), 25);
    expect(CombatRules.rollAttack(2, () => .999999), 75);
    expect(CombatRules.rollCrit(3, () => .999999), 25);
    expect(CombatRules.legacyAttack('sam:1'), 58);
    expect(CombatRules.legacyCrit('sam:1'), 13);
  });

  test('critical damage is double and HP is clamped', () {
    var battle = CombatRules.newBattle(
      const Combatant(id: 'sam', name: 'Sam', stage: 3, attack: 100, crit: 25),
      const Combatant(id: 'lira', name: 'Lira', stage: 3, attack: 60, crit: 8),
      () => 0,
    );
    battle = CombatRules.nextTurn(battle, () => 0);
    expect(battle.lastHit?.damage, 200);
    expect(battle.enemy.hp, 230);
    battle = CombatRules.nextTurn(battle, () => .9);
    battle = CombatRules.nextTurn(battle, () => 0);
    expect(battle.enemy.hp, 30);
    battle = CombatRules.nextTurn(battle, () => .9);
    battle = CombatRules.nextTurn(battle, () => 0);
    expect(battle.enemy.hp, 0);
    expect(battle.status, BattleStatus.finished);
  });
}
