import 'package:flutter/material.dart';
import '../../game/skill_catalog.dart';

class CharacterCardArt extends StatelessWidget {
  const CharacterCardArt({
    super.key,
    required this.asset,
    required this.hp,
    this.attack,
    this.crit,
    this.artKey,
    this.statsKey,
    this.compact = false,
    this.imageOpacity = 1,
    this.imageCacheWidth,
    this.skillId,
  });

  final String asset;
  final int hp;
  final int? attack, crit;
  final Key? artKey;
  final Key? statsKey;
  final bool compact;
  final double imageOpacity;
  // Optional: decode small in-arena cards at their displayed resolution.
  final int? imageCacheWidth;
  final String? skillId;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: .75,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: imageOpacity,
            child: Image.asset(asset, key: artKey, fit: BoxFit.contain,
              cacheWidth: imageCacheWidth),
          ),
          Positioned(
            left: compact ? 2 : 4,
            right: compact ? 2 : 4,
            top: compact ? 2 : 4,
            child: IgnorePointer(
              child: CardStatBadges(
                key: statsKey,
                hp: hp,
                attack: attack,
                crit: crit,
                compact: compact,
              ),
            ),
          ),
          if (SkillCatalog.byId(skillId) case final skill?)
            CardSkillOverlay(skill: skill, compact: compact),
        ],
      ),
    ),
  );
}


/// Shared placement for skill ribbons inside all card artwork (collection,
/// summon duplicates, deck editor, PvP). Never place SkillRarityBadge in an
/// unconstrained Align/FractionallySizedBox: it can cover the entire card.
class CardSkillOverlay extends StatelessWidget {
  const CardSkillOverlay({super.key, required this.skill, this.compact = false});
  final SkillDefinition skill;
  final bool compact;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 4,
    right: 4,
    bottom: compact ? 14 : 37,
    child: IgnorePointer(
      child: SizedBox(
        height: compact ? 13 : 18,
        child: Center(
          child: FractionallySizedBox(
            widthFactor: compact ? .65 : .60,
            child: SkillRarityBadge(skill: skill, compact: compact),
          ),
        ),
      ),
    ),
  );
}

/// A legible fantasy plate with rarity-colored enamel and a luminous rim.
/// Purely presentational: the parent card stays responsible for inspection taps.
class SkillRarityBadge extends StatelessWidget {
  const SkillRarityBadge({super.key, required this.skill, this.compact = false});
  final SkillDefinition skill;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = skill.color;
    final ultra = skill.rarity == 'ultra';
    final radius = BorderRadius.circular(compact ? 5 : 8);
    final gradient = ultra
        ? const LinearGradient(colors: [
            Color(0xfff24d8b), Color(0xffffca48), Color(0xff49e6ae),
            Color(0xff54a9ff), Color(0xffbe75ff),
          ])
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, .23)!,
              color,
              Color.lerp(color, const Color(0xff071222), .57)!,
            ],
          );
    return Semantics(
      label: '${skill.name}, ${skill.rarity}',
      child: Container(
        height: compact ? 13 : 18,
        padding: EdgeInsets.all(compact ? 1 : 1.5),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: .65),
                blurRadius: compact ? 5 : 10, spreadRadius: compact ? 0 : 1),
            const BoxShadow(color: Color(0x99000000), blurRadius: 5,
                offset: Offset(0, 2)),
          ],
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 3 : 5, vertical: 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 4 : 6),
            gradient: LinearGradient(colors: [
              Color.lerp(color, const Color(0xff101328), .43)!,
              Color.lerp(color, const Color(0xff07101b), .72)!,
            ]),
            border: Border.all(color: Colors.white.withValues(alpha: .60),
                width: .6),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                skill.name.toUpperCase(),
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 8 : 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: compact ? .1 : .35,
                  shadows: [
                    Shadow(color: color, blurRadius: 6),
                    const Shadow(color: Color(0xff000000), blurRadius: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CardStatBadges extends StatelessWidget {
  const CardStatBadges({
    super.key,
    required this.hp,
    this.attack,
    this.crit,
    this.compact = false,
  });

  final int hp;
  final int? attack, crit;
  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final preferred = compact ? 21.0 : 35.0;
      final size = constraints.maxWidth.isFinite
          ? (constraints.maxWidth / 3.2).clamp(7.0, preferred).toDouble()
          : preferred;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge(
            key: const Key('stat-badge-atk'),
            semantics: 'ATK ${attack ?? '—'}',
            value: '${attack ?? '—'}',
            colors: const [Color(0xffff6e78), Color(0xff9f1935)],
            size: size,
          ),
          _badge(
            key: const Key('stat-badge-crit'),
            semantics: 'CRIT ${crit == null ? '—' : '$crit%'}',
            value: crit == null ? '—' : '$crit%',
            colors: const [Color(0xffb474dc), Color(0xff4e276f)],
            size: size,
            wide: true,
          ),
          _badge(
            key: const Key('stat-badge-hp'),
            semantics: 'HP $hp',
            value: '$hp',
            colors: const [Color(0xff4d9ee9), Color(0xff12457d)],
            size: size,
          ),
        ],
      );
    },
  );

  Widget _badge({
    required Key key,
    required String semantics,
    required String value,
    required List<Color> colors,
    required double size,
    bool wide = false,
  }) {
    return Semantics(
      label: semantics,
      child: Container(
        key: key,
        width: wide ? size * 1.18 : size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: wide ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: wide ? BorderRadius.circular(size / 2) : null,
          gradient: RadialGradient(
            center: const Alignment(-.25, -.35),
            colors: colors,
          ),
          border: Border.all(
            color: const Color(0xfff7e7c2),
            width: compact ? 1 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xaa030817),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 8 : 12,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
