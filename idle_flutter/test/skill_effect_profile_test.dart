import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/pvp/skill_effect_profile.dart';
import 'package:idle_kardrune/game/skill_catalog.dart';

void main() {
  test('all skills resolve to distinct visual animation profiles', () {
    final profiles = SkillCatalog.skills
        .map((skill) => skillEffectProfileFor(skill.id))
        .toList();
    expect(profiles.map((profile) => profile.signature).toSet(), hasLength(30));
    expect(profiles.every((profile) => profile.particleCount >= 6), isTrue);
  });

  test('unknown skill uses a stable safe fallback', () {
    final profile = skillEffectProfileFor('missing');
    expect(profile.id, 'unknown');
    expect(profile.family, 'power');
  });
}
