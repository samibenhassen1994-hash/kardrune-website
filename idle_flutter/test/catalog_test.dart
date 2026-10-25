import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/game/catalog.dart';

void main() {
  test('catalog preserves every legacy hero and media path', () {
    final heroes = KardRuneCatalog.heroes;

    expect(
      heroes.map((hero) => '${hero.id}:${hero.name}:${hero.element}:${hero.power}'),
      [
        'sam:Sam:Light:42',
        'lira:Lira:Arcane:46',
        'rhea:Rhea:Nature:38',
        'dren:Dren:Shadow:65',
        'tor:Tor:Frost:62',
        'aria:Aria:Fire:79',
        'kael:Kael:Unknown:48',
        'neris:Neris:Unknown:48',
        'nyra:Nyra:Unknown:48',
      ],
    );
    expect(heroes.every((hero) => hero.stages.length == 3), isTrue);
    expect(heroes.every((hero) => hero.loops.length == 3), isTrue);
    expect(heroes.first.stages, [
      'young_sam/young_sam_stage_1.webp',
      'young_sam/sam_of_aster_stage_2.webp',
      'young_sam/Sam_Last_Guardian_stage_3.webp',
    ]);
    expect(heroes.first.loops, ['', 'sam_stage_2_loop_.mp4', 'sam_stage_3_loop.mp4']);
    expect(
      heroes.last.stages.map(heroes.last.cardAsset),
      [
        'assets/idle/cards/nyra/nyra_stage_1.webp',
        'assets/idle/cards/nyra/nyra_stage_2.webp',
        'assets/idle/cards/nyra/nyra_stage_3.webp',
      ],
    );
    expect(
      heroes[1].animationAsset(0),
      'assets/idle/animations/lira_stage_1_loop.mp4',
    );
    expect(heroes.first.animationAsset(0), isNull);
  });
}
