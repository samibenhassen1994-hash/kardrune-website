import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/localization/kr_localizations.dart';
import 'package:idle_kardrune/services/local_save_service.dart';
import 'package:idle_kardrune/tutorial/first_visit_tutorial.dart';

class _Storage implements KeyValueStorage {
  final values = <String, String>{};
  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String value) => values[key] = value;
}

void main() {
  test('tutorial completions are persistent and independent', () {
    final storage = _Storage();
    final first = IdleTutorialProgress(storage);
    expect(first.unseen(IdleTutorialSection.cards), isTrue);
    expect(first.unseen(IdleTutorialSection.summon), isTrue);
    expect(first.unseen(IdleTutorialSection.arena), isTrue);
    first.complete(IdleTutorialSection.cards);
    final nextSession = IdleTutorialProgress(storage);
    expect(nextSession.unseen(IdleTutorialSection.cards), isFalse);
    expect(nextSession.unseen(IdleTutorialSection.summon), isTrue);
    expect(nextSession.unseen(IdleTutorialSection.arena), isTrue);
  });

  test('every tutorial string is translated into all seven languages', () {
    final source = [
      'CARD STATISTICS',
      'SUMMON PORTALS',
      'ARENA BATTLES',
      'GOT IT',
      for (final section in IdleTutorialSection.values)
        ...IdleFirstVisitTutorial(
          section: section, onDone: () {},
        ).explanations,
    ];
    for (final language in KrLanguage.values) {
      for (final key in source) {
        final translated = KrTranslations.translate(language, key);
        expect(translated.trim(), isNotEmpty);
        if (language != KrLanguage.english) {
          expect(translated, isNot(key), reason: '${language.code}: $key');
        }
      }
    }
  });
}
