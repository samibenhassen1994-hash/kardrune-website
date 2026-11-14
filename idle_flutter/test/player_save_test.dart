import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/models/player_save.dart';

void main() {
  test('Olympus cloud cards survive reload as single forms with fixed skills', () {
    const gods = ['zeus','poseidon','hades','athena','ares','apollo'];
    final json = PlayerSave.initial().toJson();
    json['owned'] = ['sam:1', for(final h in gods) '$h:3', 'zeus:1', 'athena:2'];
    json['attacks'] = {'sam:1':49, for(final h in gods) '$h:3':100};
    json['crits'] = {'sam:1':7, for(final h in gods) '$h:3':25};
    json['skills'] = {for(var i=0;i<gods.length;i++) '${gods[i]}:3':{'id':'D${i+1}','rarity':'ultra','v':1}};
    final save = PlayerSave.fromJson(json);
    expect(save.owned.length,7);
    expect(save.attacks['sam:1'],49);
    for(var i=0;i<gods.length;i++) {
      expect(save.skills['${gods[i]}:3'],'D${i+1}');
      expect(save.attacks['${gods[i]}:3'],100);
      expect(save.crits['${gods[i]}:3'],25);
    }
    expect(PlayerSave.fromJson(save.toJson()).owned,save.owned);
  });
  test('initial save is byte-schema compatible', () {
    final save = PlayerSave.initial();
    expect(save.toJson(), {
      'name': 'Runebearer',
      'avatar': 'player',
      'shards': 1500,
      'owned': ['sam:1'],
      'active': 'sam:1',
      'duels': 0,
      'wins': 0,
      'pulls': 0,
      'practiceDaily': {'day': '', 'count': 0},
      'attacks': {'sam:1': 40},
      'crits': {'sam:1': 4},
      'skills': {},
      'pendingDuplicate': null,
    });
  });
  test(
    'legacy and malformed save fields normalize without losing progress',
    () {
      final save = PlayerSave.fromJson({
        'name': 'A very long Runebearer name',
        'avatar': 'bad',
        'shards': -2,
        'owned': ['sam', 'lira:2', 'bogus:1', 'lira:2'],
        'active': 'lira',
        'duels': -1,
        'wins': 3,
        'attacks': {'lira:2': 99},
        'crits': {'lira:2': 25},
      }, nowMs: DateTime(2026, 10, 25, 12).millisecondsSinceEpoch);
      expect(save.name, 'A very long Runebear');
      expect(save.avatar, 'player');
      expect(save.shards, 0);
      expect(save.owned, ['sam:1', 'lira:2']);
      expect(save.active, 'sam:1');
      expect(save.wins, 3);
      expect(save.attacks['lira:2'], 75);
      expect(save.crits['lira:2'], 16);
    },
  );

  test('daily progress and a valid pending duplicate survive migration', () {
    final now = DateTime(2026, 10, 25, 12).millisecondsSinceEpoch;
    final save = PlayerSave.fromJson({
      'owned': ['sam:1'],
      'practiceDaily': {'day': '2026-10-25', 'count': 8},
      'pendingDuplicate': {'id': 'sam:1', 'attack': 77, 'crit': 25},
    }, nowMs: now);
    expect(save.practiceDay, '2026-10-25');
    expect(save.practiceCount, 8);
    expect(save.pendingDuplicate, {'id': 'sam:1', 'attack': 50, 'crit': 8});
  });

  test('shards clamp to the largest integer exactly representable on Web', () {
    final save = PlayerSave.fromJson({'shards': 1e30});
    expect(save.shards, 0x1fffffffffffff);
  });
}
