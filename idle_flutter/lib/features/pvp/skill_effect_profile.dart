import 'package:flutter/material.dart';

import '../../game/skill_catalog.dart';

@immutable
class SkillEffectProfile {
  const SkillEffectProfile({
    required this.id,
    required this.family,
    required this.primary,
    required this.secondary,
    required this.particleCount,
    required this.ringCount,
    required this.spin,
    required this.drift,
    required this.variant,
  });

  final String id, family;
  final Color primary, secondary;
  final int particleCount, ringCount, variant;
  final double spin, drift;

  String get signature =>
      '$id:$family:${primary.toARGB32()}:${secondary.toARGB32()}:'
      '$particleCount:$ringCount:$spin:$drift:$variant';
}

SkillEffectProfile skillEffectProfileFor(String? id) {
  final index = SkillCatalog.skills.indexWhere((skill) => skill.id == id);
  if (index < 0) {
    return const SkillEffectProfile(
      id: 'unknown',
      family: 'power',
      primary: Color(0xffffd767),
      secondary: Colors.white,
      particleCount: 8,
      ringCount: 1,
      spin: 1,
      drift: 1,
      variant: 0,
    );
  }
  final skill = SkillCatalog.skills[index];
  final hue = (index * 47 + 18) % 360;
  return SkillEffectProfile(
    id: skill.id,
    family: skill.vfx,
    primary: HSVColor.fromAHSV(1, hue.toDouble(), .72, 1).toColor(),
    secondary: HSVColor.fromAHSV(
      1,
      ((hue + 58) % 360).toDouble(),
      .42,
      1,
    ).toColor(),
    particleCount: 6 + index % 10,
    ringCount: 1 + index % 4,
    spin: (index.isEven ? 1 : -1) * (1 + (index % 5) * .22),
    drift: .75 + (index % 7) * .13,
    variant: index,
  );
}
