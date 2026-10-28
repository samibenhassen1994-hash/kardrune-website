import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/catalog.dart';
import '../cards/card_stat_badges.dart';
import 'flame_attack_style.dart';
import 'flame_battle_audio.dart';

typedef _CardMotion = ({double x, double y, double angle});
const _rest = (x: 0.0, y: 0.0, angle: 0.0);

class _DemoPair {
  const _DemoPair({
    required this.playerId,
    required this.rivalId,
    required this.playerAttack,
    required this.rivalAttack,
    required this.playerDamage,
    required this.rivalDamage,
  });

  final String playerId, rivalId;
  final int playerAttack, rivalAttack, playerDamage, rivalDamage;
  FlameAttackStyle get playerStyle => flameAttackStyleFor(playerId);
  FlameAttackStyle get rivalStyle => flameAttackStyleFor(rivalId);
}

const _pairs = [
  _DemoPair(
    playerId: 'sam',
    rivalId: 'dren',
    playerAttack: 55,
    rivalAttack: 65,
    playerDamage: 55,
    rivalDamage: 90,
  ),
  _DemoPair(
    playerId: 'aria',
    rivalId: 'rhea',
    playerAttack: 79,
    rivalAttack: 38,
    playerDamage: 79,
    rivalDamage: 75,
  ),
];

/// A visual-only battle. It never reads or writes the live match or player save.
class FlamePvpDemo extends StatefulWidget {
  const FlamePvpDemo({super.key, required this.onBack, required this.audio});

  final VoidCallback onBack;
  final FlameBattleAudio audio;

  @override
  State<FlamePvpDemo> createState() => _FlamePvpDemoState();
}

class _FlamePvpDemoState extends State<FlamePvpDemo> {
  final _playerHp = ValueNotifier<int>(240);
  final _rivalHp = ValueNotifier<int>(240);
  final _playerMotion = ValueNotifier<_CardMotion>(_rest);
  final _rivalMotion = ValueNotifier<_CardMotion>(_rest);
  late final _FlameBattleGame _game;
  var _pairIndex = 0;
  var _soundOn = true;
  _DemoPair get _pair => _pairs[_pairIndex];

  @override
  void initState() {
    super.initState();
    _game = _FlameBattleGame(
      pair: _pair,
      audio: widget.audio,
      onPlayerHit: () => _playerHp.value = 240 - _pair.rivalDamage,
      onRivalHit: () => _rivalHp.value = 240 - _pair.playerDamage,
      onMotion: (player, rival) {
        _playerMotion.value = player;
        _rivalMotion.value = rival;
      },
    );
  }

  void _replay() {
    if (_soundOn) widget.audio.unlock();
    _playerHp.value = 240;
    _rivalHp.value = 240;
    _playerMotion.value = _rest;
    _rivalMotion.value = _rest;
    _game.replay();
  }

  void _nextPair() {
    setState(() => _pairIndex = (_pairIndex + 1) % _pairs.length);
    _game.setPair(_pair);
    _replay();
  }

  @override
  void dispose() {
    _game.dispose();
    widget.audio.pause();
    _playerHp.dispose();
    _rivalHp.dispose();
    _playerMotion.dispose();
    _rivalMotion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff091225),
    body: SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff203959), Color(0xff091225), Color(0xff1a1232)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'FLAME · PVP ANIMATION TEST',
                          style: TextStyle(
                            color: Color(0xffffd993),
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _soundOn = !_soundOn;
                          _game.soundEnabled = _soundOn;
                          if (_soundOn) widget.audio.unlock();
                        }),
                        child: Text(
                          _soundOn ? 'SOUND ON' : 'SOUND OFF',
                          style: const TextStyle(
                            color: Color(0xffeac981),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'OFFLINE VISUAL PREVIEW · NO REWARDS',
                    style: TextStyle(color: Color(0xffb7cceb), fontSize: 10),
                  ),
                  const Spacer(),
                  AspectRatio(
                    aspectRatio: 1.45,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _DemoFighter(
                                heroId: _pair.playerId,
                                label: 'YOU · ${_pair.playerId.toUpperCase()}',
                                attack: _pair.playerAttack,
                                crit: 10,
                                hp: _playerHp,
                                motion: _playerMotion,
                              ),
                            ),
                            const SizedBox(width: 22),
                            Expanded(
                              child: _DemoFighter(
                                heroId: _pair.rivalId,
                                label: 'RIVAL · ${_pair.rivalId.toUpperCase()}',
                                attack: _pair.rivalAttack,
                                crit: 10,
                                hp: _rivalHp,
                                motion: _rivalMotion,
                              ),
                            ),
                          ],
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: RepaintBoundary(
                              child: GameWidget(game: _game),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_pair.playerStyle.name.toUpperCase()}  →  ${_pair.rivalStyle.name.toUpperCase()} COUNTER',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xffeac981), fontSize: 10),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DemoButton(label: 'REPLAY', onTap: _replay),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _DemoButton(
                          label: 'NEXT PAIR',
                          onTap: _nextPair,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _DemoButton(
                          label: 'BACK TO PVP',
                          onTap: widget.onBack,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DemoFighter extends StatelessWidget {
  const _DemoFighter({
    required this.heroId,
    required this.label,
    required this.attack,
    required this.crit,
    required this.hp,
    required this.motion,
  });

  final String heroId, label;
  final int attack, crit;
  final ValueListenable<int> hp;
  final ValueListenable<_CardMotion> motion;

  @override
  Widget build(BuildContext context) {
    final hero = KardRuneCatalog.heroes.firstWhere(
      (entry) => entry.id == heroId,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            color: Color(0xffffd993),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: ValueListenableBuilder<_CardMotion>(
            valueListenable: motion,
            builder: (context, pose, child) => Transform.translate(
              offset: Offset(pose.x, pose.y),
              child: Transform.rotate(angle: pose.angle, child: child),
            ),
            child: RepaintBoundary(
              child: Center(
                child: AspectRatio(
                  aspectRatio: .75,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        hero.cardAsset(hero.stages.first),
                        fit: BoxFit.contain,
                        cacheWidth: 420,
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        right: 4,
                        child: ValueListenableBuilder<int>(
                          valueListenable: hp,
                          builder: (context, value, _) => CardStatBadges(
                            hp: value,
                            attack: attack,
                            crit: crit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff263e5a), Color(0xff13213a)],
        ),
        border: Border.all(color: const Color(0xffd7b26e)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xffffd993),
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    ),
  );
}

class _FlameBattleGame extends FlameGame {
  _FlameBattleGame({
    required this.pair,
    required this.audio,
    required this.onPlayerHit,
    required this.onRivalHit,
    required this.onMotion,
  });

  _DemoPair pair;
  void setPair(_DemoPair value) {
    pair = value;
    if (isLoaded) _effects.pair = value;
  }

  final FlameBattleAudio audio;
  bool soundEnabled = true;
  final VoidCallback onPlayerHit, onRivalHit;
  final void Function(_CardMotion player, _CardMotion rival) onMotion;
  late final _BattleEffects _effects;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _effects = _BattleEffects(
      pair: pair,
      audio: audio,
      soundEnabled: () => soundEnabled,
      onPlayerHit: onPlayerHit,
      onRivalHit: onRivalHit,
      onMotion: onMotion,
      onFinished: pauseEngine,
    );
    camera.viewport.add(_effects);
  }

  void replay() {
    if (!isLoaded) return;
    _effects.restart();
    resumeEngine();
  }
}

/// Draws a sword strike and impact effects over the card widgets.
class _BattleEffects extends Component {
  _BattleEffects({
    required this.pair,
    required this.audio,
    required this.soundEnabled,
    required this.onPlayerHit,
    required this.onRivalHit,
    required this.onMotion,
    required this.onFinished,
  });

  _DemoPair pair;
  final FlameBattleAudio audio;
  final bool Function() soundEnabled;
  final VoidCallback onPlayerHit, onRivalHit, onFinished;
  final void Function(_CardMotion player, _CardMotion rival) onMotion;
  final _criticalText = TextPaint(
    style: const TextStyle(
      color: Color(0xffffee91),
      fontSize: 25,
      fontWeight: FontWeight.w900,
      shadows: [
        Shadow(color: Color(0xffffbe3b), blurRadius: 13),
        Shadow(color: Color(0xff5b1b13), blurRadius: 4),
      ],
    ),
  );
  final _damageText = TextPaint(
    style: const TextStyle(
      color: Color(0xffffffff),
      fontSize: 28,
      fontWeight: FontWeight.w900,
      shadows: [
        Shadow(color: Color(0xffffd65d), blurRadius: 15),
        Shadow(color: Color(0xffa72f22), blurRadius: 6),
        Shadow(color: Color(0xff250909), blurRadius: 2),
      ],
    ),
  );
  double elapsed = 0;
  bool firstAttack = false, secondAttack = false;
  bool firstHit = false, secondHit = false, finished = false;

  void restart() {
    elapsed = 0;
    firstAttack = secondAttack = false;
    firstHit = secondHit = finished = false;
    onMotion(_rest, _rest);
  }

  @override
  void update(double dt) {
    elapsed += dt.clamp(0, .05);
    final width = findGame()?.size.x ?? 0;
    final playerAdvance = _lunge(elapsed, .18, 1.12, 1.52);
    final rivalAdvance = _lunge(elapsed, 2.16, 3.10, 3.50);
    final playerShake = _shake(elapsed, 3.10);
    final rivalShake = _shake(elapsed, 1.12);
    onMotion(
      _pose(playerAdvance, playerShake, 1, width, pair.playerStyle),
      _pose(rivalAdvance, rivalShake, -1, width, pair.rivalStyle),
    );
    if (!firstAttack && elapsed >= .18) {
      firstAttack = true;
      if (soundEnabled()) audio.attack(pair.playerStyle);
    }
    if (!firstHit && elapsed >= 1.12) {
      firstHit = true;
      if (soundEnabled()) audio.impact(pair.playerStyle, critical: false);
      onRivalHit();
    }
    if (!secondAttack && elapsed >= 2.16) {
      secondAttack = true;
      if (soundEnabled()) audio.attack(pair.rivalStyle);
    }
    if (!secondHit && elapsed >= 3.10) {
      secondHit = true;
      if (soundEnabled()) audio.impact(pair.rivalStyle, critical: true);
      onPlayerHit();
    }
    if (!finished && elapsed >= 4.0) {
      finished = true;
      onMotion(_rest, _rest);
      onFinished();
    }
  }

  double _lunge(double time, double start, double impact, double end) {
    if (time < start || time >= end) return 0;
    if (time <= impact) {
      final phase = ((time - start) / (impact - start)).clamp(0.0, 1.0);
      return .5 - .5 * math.cos(math.pi * phase);
    }
    final phase = ((time - impact) / (end - impact)).clamp(0.0, 1.0);
    return .5 + .5 * math.cos(math.pi * phase);
  }

  _CardMotion _pose(
    double advance,
    double shake,
    int direction,
    double width,
    FlameAttackStyle style,
  ) {
    final reach = switch (style) {
      FlameAttackStyle.sword || FlameAttackStyle.dagger => .13,
      FlameAttackStyle.magic || FlameAttackStyle.arrow => .055,
    };
    return (
      x: direction * width * reach * advance + shake,
      y: -5 * math.sin(math.pi * advance) + shake.abs() * .13,
      angle: direction * .11 * advance + shake * .006,
    );
  }

  double _shake(double time, double impact) {
    final age = time - impact;
    if (age < 0 || age >= .38) return 0;
    return math.sin(age * 98) * 9 * (1 - age / .38);
  }

  @override
  void render(Canvas canvas) {
    final game = findGame()!;
    final width = game.size.x, height = game.size.y;
    if (elapsed >= .18 && elapsed < 1.42) {
      _renderAttack(
        canvas,
        pair.playerStyle,
        width,
        height,
        start: .18,
        hit: 1.12,
        forward: true,
      );
    } else if (elapsed >= 2.16 && elapsed < 3.40) {
      _renderAttack(
        canvas,
        pair.rivalStyle,
        width,
        height,
        start: 2.16,
        hit: 3.10,
        forward: false,
      );
    }
    if (elapsed >= 1.12 && elapsed < 1.62) {
      _impact(
        canvas,
        width * .75,
        height * .5,
        elapsed - 1.12,
        pair.playerStyle,
        false,
      );
      final labelY = height * .27 - (elapsed - 1.12) * 18;
      _damageText.render(
        canvas,
        '-${pair.playerDamage} HP',
        Vector2(width * .75, labelY),
        anchor: Anchor.center,
      );
      _glitter(canvas, width * .75, labelY, elapsed - 1.12);
    }
    if (elapsed >= 3.10 && elapsed < 3.80) {
      _impact(
        canvas,
        width * .25,
        height * .5,
        elapsed - 3.10,
        pair.rivalStyle,
        true,
      );
      _criticalText.render(
        canvas,
        'CRITICAL!',
        Vector2(width * .5, height * .16),
        anchor: Anchor.center,
      );
      final labelY = height * .29 - (elapsed - 3.10) * 18;
      _damageText.render(
        canvas,
        '-${pair.rivalDamage} HP',
        Vector2(width * .25, labelY),
        anchor: Anchor.center,
      );
      _glitter(canvas, width * .25, labelY, elapsed - 3.10);
      _glitter(canvas, width * .5, height * .16, elapsed - 3.10);
    }
  }

  void _renderAttack(
    Canvas canvas,
    FlameAttackStyle style,
    double width,
    double height, {
    required double start,
    required double hit,
    required bool forward,
  }) {
    final targetX = width * (forward ? .75 : .25);
    final sourceX = width * (forward ? .25 : .75);
    switch (style) {
      case FlameAttackStyle.sword:
        if (elapsed >= hit - .34) {
          _sword(
            canvas,
            targetX,
            height * .49,
            (elapsed - (hit - .34)) / .64,
            mirrored: !forward,
          );
        }
      case FlameAttackStyle.dagger:
        if (elapsed >= hit - .29) {
          _dagger(
            canvas,
            targetX,
            height * .50,
            (elapsed - (hit - .29)) / .56,
            mirrored: !forward,
          );
        }
      case FlameAttackStyle.magic:
        if (elapsed < hit) {
          _magic(
            canvas,
            sourceX,
            targetX,
            height * .5,
            (elapsed - start) / (hit - start),
          );
        }
      case FlameAttackStyle.arrow:
        if (elapsed < hit) {
          _arrow(
            canvas,
            sourceX,
            targetX,
            height * .5,
            (elapsed - start) / (hit - start),
          );
        }
    }
  }

  void _sword(
    Canvas canvas,
    double x,
    double y,
    double phase, {
    required bool mirrored,
  }) {
    final eased = 1 - math.pow(1 - phase.clamp(0.0, 1.0), 3).toDouble();
    final fade = math.min(1.0, math.min(phase * 8, (1 - phase) * 7));
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate((mirrored ? 1 : -1) * (.95 - eased * 1.65));
    final blade = Path()
      ..moveTo(0, -78)
      ..lineTo(8, -58)
      ..lineTo(6, 6)
      ..lineTo(-6, 6)
      ..lineTo(-8, -58)
      ..close();
    canvas.drawPath(
      blade,
      Paint()..color = const Color(0xffa4d5f7).withValues(alpha: fade),
    );
    canvas.drawPath(
      blade,
      Paint()
        ..color = const Color(0xffffffff).withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      const Offset(0, -67),
      const Offset(0, 4),
      Paint()
        ..color = const Color(0xffffffff).withValues(alpha: fade)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      const Offset(-18, 8),
      const Offset(18, 8),
      Paint()
        ..color = const Color(0xffffda78).withValues(alpha: fade)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(0, 9),
      const Offset(0, 35),
      Paint()
        ..color = const Color(0xff8c5128).withValues(alpha: fade)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(0, 37),
      5,
      Paint()..color = const Color(0xffffd973).withValues(alpha: fade),
    );
    canvas.restore();
  }

  void _dagger(
    Canvas canvas,
    double x,
    double y,
    double phase, {
    required bool mirrored,
  }) {
    final progress = phase.clamp(0.0, 1.0);
    final thrust = math.sin(math.pi * progress);
    final direction = mirrored ? -1.0 : 1.0;
    canvas.save();
    canvas.translate(x - direction * (25 - 20 * thrust), y + 7);
    canvas.rotate(direction * (.6 - .9 * progress));
    final blade = Path()
      ..moveTo(direction * 44, 0)
      ..lineTo(direction * 10, -7)
      ..lineTo(direction * 10, 7)
      ..close();
    canvas.drawPath(blade, Paint()..color = const Color(0xffd9ecf8));
    canvas.drawLine(
      Offset(direction * 9, -11),
      Offset(direction * 9, 11),
      Paint()
        ..color = const Color(0xffffd07b)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(direction * 7, 0),
      Offset(-direction * 20, 0),
      Paint()
        ..color = const Color(0xff6f3b30)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _magic(
    Canvas canvas,
    double sourceX,
    double targetX,
    double y,
    double phase,
  ) {
    final progress = .5 - .5 * math.cos(math.pi * phase.clamp(0.0, 1.0));
    final x = sourceX + (targetX - sourceX) * progress;
    final center = Offset(x, y - 16 * math.sin(math.pi * progress));
    canvas.drawCircle(center, 18, Paint()..color = const Color(0x554eafff));
    canvas.drawCircle(center, 11, Paint()..color = const Color(0xaaac7bff));
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xffffffff));
    canvas.drawCircle(
      center,
      22 + 3 * math.sin(progress * 12),
      Paint()
        ..color = const Color(0xaad9c1ff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _arrow(
    Canvas canvas,
    double sourceX,
    double targetX,
    double y,
    double phase,
  ) {
    final progress = phase.clamp(0.0, 1.0);
    final x = sourceX + (targetX - sourceX) * progress;
    final direction = targetX > sourceX ? 1.0 : -1.0;
    final centerY = y - 10 * math.sin(math.pi * progress);
    final wood = Paint()
      ..color = const Color(0xffb78955)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(x - direction * 33, centerY),
      Offset(x + direction * 17, centerY),
      wood,
    );
    final tip = Path()
      ..moveTo(x + direction * 30, centerY)
      ..lineTo(x + direction * 15, centerY - 7)
      ..lineTo(x + direction * 15, centerY + 7)
      ..close();
    canvas.drawPath(tip, Paint()..color = const Color(0xffe4f2fa));
    final feather = Paint()
      ..color = const Color(0xffd7f3c5)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(x - direction * 31, centerY),
      Offset(x - direction * 42, centerY - 9),
      feather,
    );
    canvas.drawLine(
      Offset(x - direction * 31, centerY),
      Offset(x - direction * 42, centerY + 9),
      feather,
    );
  }

  void _glitter(Canvas canvas, double x, double y, double age) {
    final visibility = (1 - age / .72).clamp(0.0, 1.0);
    for (var i = 0; i < 13; i++) {
      final angle = i * 2.399963;
      final radius = 23 + (i % 4) * 12.0;
      final twinkle = (.5 + .5 * math.sin(age * 30 + i * 2.2));
      final alpha = (visibility * twinkle).clamp(0.0, 1.0);
      final center = Offset(
        x + math.cos(angle) * radius,
        y + math.sin(angle) * (12 + i % 3 * 8),
      );
      final size = 2.5 + (i % 3) * 1.3;
      final paint = Paint()
        ..color = const Color(0xffffe694).withValues(alpha: alpha)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(center.dx - size, center.dy),
        Offset(center.dx + size, center.dy),
        paint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - size),
        Offset(center.dx, center.dy + size),
        paint,
      );
    }
  }

  void _impact(
    Canvas canvas,
    double x,
    double y,
    double age,
    FlameAttackStyle style,
    bool critical,
  ) {
    final duration = critical ? .70 : .50;
    final phase = (age / duration).clamp(0.0, 1.0);
    final opacity = (1 - phase).clamp(0.0, 1.0);
    final color = critical
        ? const Color(0xffffd566)
        : switch (style) {
            FlameAttackStyle.magic => const Color(0xffb99bff),
            FlameAttackStyle.arrow => const Color(0xffb6e9a2),
            FlameAttackStyle.dagger => const Color(0xffff9f91),
            FlameAttackStyle.sword => const Color(0xfff6f0d2),
          };
    canvas.drawCircle(
      Offset(x, y),
      12 + phase * (critical ? 45 : 30),
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * opacity + .5,
    );
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final inner = 10 + phase * 14;
      final outer = 20 + phase * (critical ? 42 : 26);
      canvas.drawLine(
        Offset(x + math.cos(angle) * inner, y + math.sin(angle) * inner),
        Offset(x + math.cos(angle) * outer, y + math.sin(angle) * outer),
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..strokeWidth = critical ? 3 : 2,
      );
    }
  }
}
