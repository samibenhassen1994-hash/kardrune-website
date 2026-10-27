import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/game/combat_rules.dart';
import 'package:idle_kardrune/game/game_rules.dart';
import 'package:idle_kardrune/game/summon_rules.dart';

void main() {
  test('Dart rules match shared JavaScript parity fixtures', () {
    final data = jsonDecode(File('test/fixtures/rules_parity.json').readAsStringSync()) as Map<String, dynamic>;
    for (final value in data['practice'] as List) {
      final row = value as Map<String, dynamic>;
      expect(GameRules.practiceWinChance(row['power'] as num, row['stage'] as int), row['chance']);
    }
    for (final value in data['legacy'] as List) {
      final row = value as Map<String, dynamic>;
      expect(CombatRules.legacyAttack(row['id'] as String), row['attack']);
      expect(CombatRules.legacyCrit(row['id'] as String), row['crit']);
    }
    for (final value in data['summon'] as List) {
      final row = value as Map<String, dynamic>;
      expect(SummonRules.stageFor(row['featured'] as bool, row['roll'] as double), row['stage']);
    }
  });
}
