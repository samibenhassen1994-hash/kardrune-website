import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/game/skill_catalog.dart';
import 'package:idle_kardrune/localization/kr_localizations.dart';
import 'package:idle_kardrune/localization/skill_localizations.dart';

void main() {
  test('every skill is translated in every supported language', () {
    for (final language in KrLanguage.values) {
      for (final skill in SkillCatalog.skills) {
        final translated = skill.localizedFor(language);
        expect(translated.name.trim(), isNotEmpty);
        expect(translated.description.trim(), isNotEmpty);
        expect(translated.trigger.trim(), isNotEmpty);
        expect(translated.limit.trim(), isNotEmpty);
        if (language != KrLanguage.italian) {
          expect(
            (
              translated.name,
              translated.description,
              translated.trigger,
              translated.limit,
            ),
            isNot((skill.name, skill.description, skill.trigger, skill.limit)),
            reason: '${skill.id} is not localized in ${language.code}',
          );
        }
      }
    }
  });

  test(
    'important UI sections are translated in every non-English language',
    () {
      const keys = [
        'ADD NINE CARDS TO YOUR DECK', 'GRAVEYARD',
        'DUPLICATE CARD', 'NEW HERO UNLOCKED', 'Compare both cards, then choose which one to keep.',
        'KEEP CURRENT · +100', 'REPLACE', 'KEEP = +100 SHARDS  ·  REPLACE = NEW STATS',
        '▲ GREEN: BETTER    ▼ RED: WORSE', 'YOUR CARD', 'NEW CARD', 'ADDED TO YOUR COLLECTION',
        'ENTERING THE ARENA', 'YOUR OPPONENT', 'Music', 'Sound effects',

        'VIEW EFFECT',
        'RUNE ADVENTURER',
        'UPLOAD LOCAL',
        'LOAD CLOUD',
        'RESTORE OFFLINE SAVE',
        'FREE PULLS',
        'PvP rewards left (24h)',
        'NEXT CHARGE IN',
        'SKILL RARITY BY STAGE',
      'ATK HIGH → LOW',
      'CRIT HIGH → LOW',
      'SKILL RARITY',
      'STAGE HIGH → LOW',
      'NAME A–Z',
      'ACTIVE CHAMPION',
      'NOT COLLECTED',
      'PER PULL',
        'Nine heroes · 300 Shards or a free charge',
        "OLYMPUS PULL  ◆ 1200",
        "Olympus: 10% total (1.67% each). Otherwise, featured-style heroes with extra Stage 3 chance.",
        "Cost: 1200 Shards. Six Olympus gods: 10% total; 1.67% each.",
        "Other heroes: 90%. Dren featured rate-up.",
        "Fallback stages: Stage 1 55%, Stage 2 30%, Stage 3 15%.",
        "Olympus cards: one form, Ultra fixed skills, ATK 100, CRIT 25%, HP 430.",
        'No event banner is active. Rates and featured heroes will appear here when an event is configured.',
      ];
      for (final language in KrLanguage.values.where(
        (value) => value != KrLanguage.english,
      )) {
        for (final key in keys) {
          expect(
            KrTranslations.translate(language, key),
            isNot(key),
            reason: '$key is not translated in ${language.code}',
          );
        }
      }
    },
  );
}
