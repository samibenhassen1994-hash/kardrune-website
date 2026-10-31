class CardStatRange {
  const CardStatRange(
    this.minAttack,
    this.maxAttack,
    this.minCrit,
    this.maxCrit,
  );

  final int minAttack, maxAttack, minCrit, maxCrit;

  @override
  bool operator ==(Object other) =>
      other is CardStatRange &&
      minAttack == other.minAttack &&
      maxAttack == other.maxAttack &&
      minCrit == other.minCrit &&
      maxCrit == other.maxCrit;

  @override
  int get hashCode => Object.hash(minAttack, maxAttack, minCrit, maxCrit);
}

abstract final class CardStatLimits {
  static const _ranges = <int, CardStatRange>{
    1: CardStatRange(25, 50, 0, 8),
    2: CardStatRange(40, 75, 4, 16),
    3: CardStatRange(60, 100, 8, 25),
  };

  static CardStatRange forStage(int stage) {
    final range = _ranges[stage];
    if (range == null) throw RangeError.range(stage, 1, 3, 'stage');
    return range;
  }

  static ({int attack, int crit}) effective(int stage, int attack, int crit) {
    final range = forStage(stage);
    return (
      attack: attack.clamp(range.minAttack, range.maxAttack),
      crit: crit.clamp(range.minCrit, range.maxCrit),
    );
  }

  static int rollAttack(int stage, double value) {
    final range = forStage(stage);
    return range.minAttack +
        (_unit(value) * (range.maxAttack - range.minAttack + 1)).floor();
  }

  static int rollCrit(int stage, double value) {
    final range = forStage(stage);
    return range.minCrit +
        (_unit(value) * (range.maxCrit - range.minCrit + 1)).floor();
  }

  static double _unit(double value) =>
      (value.isFinite ? value : 0.0).clamp(0.0, .999999999).toDouble();
}
