import '../game/catalog.dart';
import '../game/combat_rules.dart';
import '../game/game_rules.dart';
import '../game/skill_catalog.dart';

class PlayerSave {
  PlayerSave({
    required this.name,
    required this.avatar,
    required this.shards,
    required this.owned,
    required this.active,
    required this.duels,
    required this.wins,
    required this.pulls,
    required this.practiceDay,
    required this.practiceCount,
    required this.attacks,
    required this.crits,
    this.skills = const {},
    this.pendingDuplicate,
  });
  final String name, avatar, active, practiceDay;
  final int shards, duels, wins, pulls, practiceCount;
  final List<String> owned;
  final Map<String, int> attacks, crits;
  final Map<String, String> skills;
  final Map<String, Object?>? pendingDuplicate;
  factory PlayerSave.initial() => PlayerSave(
    name: 'Runebearer',
    avatar: 'player',
    shards: 1500,
    owned: ['sam:1'],
    active: 'sam:1',
    duels: 0,
    wins: 0,
    pulls: 0,
    practiceDay: '',
    practiceCount: 0,
    attacks: {'sam:1': 40},
    crits: {'sam:1': 4},
    skills: const {},
  );
  factory PlayerSave.fromJson(Map<String, Object?>? json, {int? nowMs}) {
    if (json == null) return PlayerSave.initial();
    final base = PlayerSave.initial(),
        heroIds = KardRuneCatalog.heroes.map((e) => e.id).toSet();
    final raw = json['owned'] is List ? (json['owned'] as List) : const [];
    final owned = <String>[];
    for (final value in raw) {
      var id = value.toString();
      if (!id.contains(':')) id = '$id:1';
      final p = id.split(':');
      if (p.length == 2 &&
          heroIds.contains(p[0]) &&
          ['1', '2', '3'].contains(p[1]) &&
          !owned.contains(id)) {
        owned.add(id);
      }
    }
    if (owned.isEmpty) {
      owned.addAll(base.owned);
    }
    var active = (json['active'] ?? base.active).toString();
    if (!active.contains(':')) active = '$active:1';
    if (!owned.contains(active)) active = owned.first;
    int count(Object? v) => v is int && v >= 0 ? v : 0;
    int bounded(Object? v, int fallback, int min, int max) =>
        v is int && v >= min && v <= max ? v : fallback;
    final a = json['attacks'] is Map ? json['attacks'] as Map : const {},
        c = json['crits'] is Map ? json['crits'] as Map : const {};
    final rawSkills = json['skills'] is Map ? json['skills'] as Map : const {};
    final dailyRaw = json['practiceDaily'] is Map
        ? json['practiceDaily'] as Map
        : const {};
    final daily = GameRules.dailyRewardState(
      DailyRewardState(
        day: dailyRaw['day'] is String ? dailyRaw['day'] as String : '',
        count: count(dailyRaw['count']),
      ),
      nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    Map<String, Object?>? pending;
    final p = json['pendingDuplicate'];
    if (p is Map &&
        p['id'] is String &&
        owned.contains(p['id']) &&
        p['attack'] is int &&
        (p['attack'] as int) >= 1 &&
        (p['attack'] as int) <= 100) {
      final id = p['id'] as String;
      pending = {
        'id': id,
        'attack': p['attack'] as int,
        'crit': bounded(
          p['crit'],
          CombatRules.legacyCrit('$id:duplicate'),
          0,
          25,
        ),
        if (p['skillId'] is String && SkillCatalog.validForStage(
          p['skillId'] as String, int.parse(id.split(':').last)))
          'skillId': p['skillId'] as String,
        if (p['skillVersion'] == SkillCatalog.version)
          'skillVersion': SkillCatalog.version,
        if (p['rollId'] is String) 'rollId': p['rollId'] as String,
      };
    }
    return PlayerSave(
      name: json['name'] is String
          ? (json['name'] as String).substring(
              0,
              (json['name'] as String).length.clamp(0, 20),
            )
          : base.name,
      avatar: ['player', 'guard', 'vassal', 'king'].contains(json['avatar'])
          ? json['avatar'] as String
          : base.avatar,
      shards: json['shards'] is num
          ? (json['shards'] as num).floor().clamp(0, 0x1fffffffffffff)
          : base.shards,
      owned: owned,
      active: active,
      duels: count(json['duels']),
      wins: count(json['wins']),
      pulls: count(json['pulls']),
      practiceDay: daily.day,
      practiceCount: daily.count,
      attacks: {
        for (final id in owned)
          id: bounded(a[id], CombatRules.legacyAttack(id), 1, 100),
      },
      crits: {
        for (final id in owned)
          id: bounded(c[id], CombatRules.legacyCrit(id), 0, 25),
      },
      skills: {
        for (final id in owned)
          if (rawSkills[id] is Map &&
              (rawSkills[id] as Map)['id'] is String &&
              (rawSkills[id] as Map)['v'] == SkillCatalog.version &&
              SkillCatalog.validForStage(
                (rawSkills[id] as Map)['id'] as String,
                int.parse(id.split(':').last)))
            id: (rawSkills[id] as Map)['id'] as String,
      },
      pendingDuplicate: pending,
    );
  }
  Map<String, Object?> toJson() => {
    'name': name,
    'avatar': avatar,
    'shards': shards,
    'owned': owned,
    'active': active,
    'duels': duels,
    'wins': wins,
    'pulls': pulls,
    'practiceDaily': {'day': practiceDay, 'count': practiceCount},
    'attacks': attacks,
    'crits': crits,
    'skills': {
      for (final entry in skills.entries)
        if (SkillCatalog.byId(entry.value) case final skill?)
          entry.key: {'id': skill.id, 'rarity': skill.rarity, 'v': SkillCatalog.version},
    },
    'pendingDuplicate': pendingDuplicate,
  };
  PlayerSave copyWith({
    String? name,
    String? avatar,
    int? shards,
    List<String>? owned,
    String? active,
    int? duels,
    int? wins,
    int? pulls,
    String? practiceDay,
    int? practiceCount,
    Map<String, int>? attacks,
    Map<String, int>? crits,
    Map<String, String>? skills,
    Map<String, Object?>? pendingDuplicate,
    bool clearPending = false,
  }) => PlayerSave(
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    shards: shards ?? this.shards,
    owned: owned ?? this.owned,
    active: active ?? this.active,
    duels: duels ?? this.duels,
    wins: wins ?? this.wins,
    pulls: pulls ?? this.pulls,
    practiceDay: practiceDay ?? this.practiceDay,
    practiceCount: practiceCount ?? this.practiceCount,
    attacks: attacks ?? this.attacks,
    crits: crits ?? this.crits,
    skills: skills ?? this.skills,
    pendingDuplicate: clearPending
        ? null
        : pendingDuplicate ?? this.pendingDuplicate,
  );
}
