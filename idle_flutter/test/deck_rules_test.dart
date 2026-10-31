import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/game/deck_rules.dart';

void main() {
  const owned = ['sam:1', 'lira:1', 'dren:2'];
  test('deck normalizes to nine unique owned slots', () {
    expect(DeckRules.normalize(['sam:1', 'sam:1', 'bad'], owned), [
      'sam:1',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ]);
  });
  test('put reorders and displaced card moves to empty slot', () {
    final moved = DeckRules.put(['sam:1', 'lira:1'], 'sam:1', 1, owned);
    expect(moved.take(2), ['lira:1', 'sam:1']);
    final inserted = DeckRules.put(['sam:1'], 'dren:2', 0, owned);
    expect(inserted.take(2), ['dren:2', 'sam:1']);
  });
  test('auto deck selects strongest distinct cards deterministically', () {
    final cards = List.generate(12, (i) => 'hero:$i');
    final attacks = <String, int>{
      for (var i = 0; i < cards.length; i++) cards[i]: i == 10 ? 99 : i,
    };
    expect(DeckRules.auto(cards, attacks), [
      'hero:10',
      'hero:11',
      'hero:9',
      'hero:8',
      'hero:7',
      'hero:6',
      'hero:5',
      'hero:4',
      'hero:3',
    ]);
  });
}
