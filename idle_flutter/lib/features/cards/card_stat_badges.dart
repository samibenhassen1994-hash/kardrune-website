import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _badge(
        key: const Key('stat-badge-atk'),
        semantics: 'ATK ${attack ?? '—'}',
        value: '${attack ?? '—'}',
        colors: const [Color(0xffff6e78), Color(0xff9f1935)],
      ),
      _badge(
        key: const Key('stat-badge-crit'),
        semantics: 'CRIT ${crit == null ? '—' : '$crit%'}',
        value: crit == null ? '—' : '$crit%',
        colors: const [Color(0xffb474dc), Color(0xff4e276f)],
        wide: true,
      ),
      _badge(
        key: const Key('stat-badge-hp'),
        semantics: 'HP $hp',
        value: '$hp',
        colors: const [Color(0xff4d9ee9), Color(0xff12457d)],
      ),
    ],
  );

  Widget _badge({
    required Key key,
    required String semantics,
    required String value,
    required List<Color> colors,
    bool wide = false,
  }) {
    final size = compact ? 21.0 : 35.0;
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
