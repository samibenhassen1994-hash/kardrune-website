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
        'VIEW EFFECT',
        'RUNE ADVENTURER',
        'UPLOAD LOCAL',
        'LOAD CLOUD',
        'RESTORE OFFLINE SAVE',
        'FREE PULLS',
        'PvP rewards left (24h)',
        'NEXT CHARGE IN',
        'SKILL RARITY BY STAGE',
        'Nine heroes · 300 Shards or a free charge',
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
