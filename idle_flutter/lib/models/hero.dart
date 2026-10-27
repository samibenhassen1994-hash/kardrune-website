class HeroDefinition {
  const HeroDefinition({
    required this.id,
    required this.name,
    required this.element,
    required this.power,
    required this.stages,
    required this.loops,
  });

  final String id;
  final String name;
  final String element;
  final int power;
  final List<String> stages;
  final List<String> loops;

  String cardAsset(String path) => 'assets/idle/cards/$path';

  String? animationAsset(int stageIndex) {
    final path = loops[stageIndex];
    return path.isEmpty ? null : 'assets/idle/animations/$path';
  }
}
