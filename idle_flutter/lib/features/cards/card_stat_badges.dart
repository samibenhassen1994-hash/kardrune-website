import 'package:flutter/material.dart';

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
        ],
      ),
    ),
  );
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
