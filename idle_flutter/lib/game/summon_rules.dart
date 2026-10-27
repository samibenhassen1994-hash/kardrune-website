class DuplicateDecision {
  const DuplicateDecision(this.refund, this.useNewStats);
  final int refund;
  final bool useNewStats;
}

abstract final class SummonRules {
  static int cost(bool featured) => featured ? 600 : 300;
  static int stageFor(bool featured, double roll) => featured
      ? (roll < .60
            ? 1
            : roll < .90
            ? 2
            : 3)
      : (roll < .78
            ? 1
            : roll < .97
            ? 2
            : 3);
  static int heroIndex(bool featured, double rateUpRoll, double heroRoll) =>
      featured && rateUpRoll < .35
      ? 3
      : (heroRoll.clamp(0, .999999999) * 9).floor();
  static DuplicateDecision resolveDuplicate({required bool replace}) =>
      DuplicateDecision(replace ? 0 : 100, replace);
}
