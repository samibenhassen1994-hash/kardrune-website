import 'card_stat_limits.dart';

typedef RandomSource = double Function();

enum BattleStatus { running, finished }

class Combatant {
  const Combatant({
    required this.id,
    required this.name,
    required this.stage,
    required this.attack,
    required this.crit,
    this.hp,
    this.maxHp,
  });
  final String id, name;
  final int stage, attack, crit;
  final int? hp, maxHp;
  Combatant copyWith({int? hp}) => Combatant(
    id: id,
    name: name,
    stage: stage,
    attack: attack,
    crit: crit,
    hp: hp ?? this.hp,
    maxHp: maxHp,
  );
}

class BattleHit {
  const BattleHit({
    required this.actor,
    required this.target,
    required this.attack,
    required this.damage,
    required this.critical,
    required this.hpBefore,
    required this.hp,
  });
  final String actor, target;
  final int attack, damage, hpBefore, hp;
  final bool critical;
}

class CombatState {
  const CombatState({
    required this.player,
    required this.enemy,
    required this.turn,
    required this.hits,
    required this.status,
    this.lastHit,
    this.winner,
  });
  final Combatant player, enemy;
  final String? turn, winner;
  final int hits;
  final BattleStatus status;
  final BattleHit? lastHit;
}

abstract final class CombatRules {
  static const stageHp = [0, 240, 340, 430], maxCrit = 25;
  static int hpForStage(int stage) =>
      stage >= 1 && stage <= 3 ? stageHp[stage] : 240;
  static double _random(RandomSource fn) {
    final value = fn();
    return (value.isFinite ? value : 0.0).clamp(0.0, .999999999).toDouble();
  }

  static int rollAttack(int stage, RandomSource random) =>
      CardStatLimits.rollAttack(stage, _random(random));
  static int rollCrit(int stage, RandomSource random) =>
      CardStatLimits.rollCrit(stage, _random(random));
  static int _hash(String id) {
    var h = 2166136261;
    for (final c in id.codeUnits) {
      h = ((h ^ c) * 16777619) & 0xffffffff;
    }
    return h;
  }

  static int legacyAttack(String id) => 25 + _hash(id) % 51;
  static int legacyCrit(String id) => 4 + _hash(id) % 12;
  static CombatState newBattle(
    Combatant player,
    Combatant enemy,
    RandomSource random,
  ) {
    Combatant ready(Combatant c) {
      final hp = hpForStage(c.stage);
      final effective = CardStatLimits.effective(c.stage, c.attack, c.crit);
      return Combatant(
        id: c.id,
        name: c.name,
        stage: c.stage,
        attack: effective.attack,
        crit: effective.crit,
        hp: hp,
        maxHp: hp,
      );
    }

    return CombatState(
      player: ready(player),
      enemy: ready(enemy),
      turn: _random(random) < .5 ? 'player' : 'enemy',
      hits: 0,
      status: BattleStatus.running,
    );
  }

  static CombatState nextTurn(CombatState b, RandomSource random) {
    if (b.status != BattleStatus.running) return b;
    final actor = b.turn!, target = actor == 'player' ? 'enemy' : 'player';
    final source = actor == 'player' ? b.player : b.enemy,
        victim = target == 'player' ? b.player : b.enemy;
    final critical = _random(random) < source.crit / 100,
        damage = source.attack * (critical ? 2 : 1),
        before = victim.hp!,
        remaining = (before - damage).clamp(0, before),
        winner = remaining == 0 ? actor : null;
    final changed = victim.copyWith(hp: remaining),
        hit = BattleHit(
          actor: actor,
          target: target,
          attack: source.attack,
          damage: damage,
          critical: critical,
          hpBefore: before,
          hp: remaining,
        );
    return CombatState(
      player: target == 'player' ? changed : b.player,
      enemy: target == 'enemy' ? changed : b.enemy,
      turn: winner == null ? target : null,
      hits: b.hits + 1,
      status: winner == null ? BattleStatus.running : BattleStatus.finished,
      lastHit: hit,
      winner: winner,
    );
  }
}
