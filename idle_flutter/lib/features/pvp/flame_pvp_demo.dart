import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/catalog.dart';
import '../cards/card_stat_badges.dart';

/// A visual-only battle. It never reads or writes the live match or player save.
class FlamePvpDemo extends StatefulWidget {
  const FlamePvpDemo({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<FlamePvpDemo> createState() => _FlamePvpDemoState();
}

class _FlamePvpDemoState extends State<FlamePvpDemo> {
  final _playerHp = ValueNotifier<int>(240);
  final _rivalHp = ValueNotifier<int>(240);
  final _playerShift = ValueNotifier<double>(0);
  final _rivalShift = ValueNotifier<double>(0);
  late final _FlameBattleGame _game;

  @override
  void initState() {
    super.initState();
    _game = _FlameBattleGame(
      onPlayerHit: () => _playerHp.value = 150,
      onRivalHit: () => _rivalHp.value = 185,
      onMotion: (player, rival) {
        _playerShift.value = player;
        _rivalShift.value = rival;
      },
    );
  }

  void _replay() {
    _playerHp.value = 240;
    _rivalHp.value = 240;
    _playerShift.value = 0;
    _rivalShift.value = 0;
    _game.replay();
  }

  @override
  void dispose() {
    _game.dispose();
    _playerHp.dispose();
    _rivalHp.dispose();
    _playerShift.dispose();
    _rivalShift.dispose();
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
                  const Text(
                    'FLAME · PVP ANIMATION TEST',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xffffd993),
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
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
                                heroId: 'sam',
                                label: 'YOU · SAM',
                                attack: 55,
                                crit: 10,
                                hp: _playerHp,
                                motion: _playerShift,
                              ),
                            ),
                            const SizedBox(width: 22),
                            Expanded(
                              child: _DemoFighter(
                                heroId: 'dren',
                                label: 'RIVAL · DREN',
                                attack: 65,
                                crit: 10,
                                hp: _rivalHp,
                                motion: _rivalShift,
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
                  const Text(
                    'PLAYER ATTACK  →  RIVAL COUNTERATTACK',
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
  final ValueListenable<double> motion;

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
          child: ValueListenableBuilder<double>(
            valueListenable: motion,
            builder: (context, shift, child) =>
                Transform.translate(offset: Offset(shift, 0), child: child),
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
    required this.onPlayerHit,
    required this.onRivalHit,
    required this.onMotion,
  });

  final VoidCallback onPlayerHit, onRivalHit;
  final void Function(double player, double rival) onMotion;
  late final _BattleEffects _effects;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _effects = _BattleEffects(
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
    required this.onPlayerHit,
    required this.onRivalHit,
    required this.onMotion,
    required this.onFinished,
  });

  final VoidCallback onPlayerHit, onRivalHit, onFinished;
  final void Function(double player, double rival) onMotion;
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
  bool firstHit = false, secondHit = false, finished = false;

  void restart() {
    elapsed = 0;
    firstHit = secondHit = finished = false;
    onMotion(0, 0);
  }

  @override
  void update(double dt) {
    elapsed += dt.clamp(0, .05);
    final width = findGame()?.size.x ?? 0;
    onMotion(
      width * .13 * _lunge(elapsed, .18, 1.12, 1.52) + _shake(elapsed, 3.10),
      -width * .13 * _lunge(elapsed, 2.16, 3.10, 3.50) + _shake(elapsed, 1.12),
    );
    if (!firstHit && elapsed >= 1.12) {
      firstHit = true;
      onRivalHit();
    }
    if (!secondHit && elapsed >= 3.10) {
      secondHit = true;
      onPlayerHit();
    }
    if (!finished && elapsed >= 4.0) {
      finished = true;
      onMotion(0, 0);
      onFinished();
    }
  }

  double _lunge(double time, double start, double impact, double end) {
    if (time < start || time >= end) return 0;
    if (time <= impact) {
      final phase = ((time - start) / (impact - start)).clamp(0.0, 1.0);
      return 1 - math.pow(1 - phase, 3).toDouble();
    }
    final phase = ((time - impact) / (end - impact)).clamp(0.0, 1.0);
    return math.pow(1 - phase, 2).toDouble();
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
    if (elapsed >= .78 && elapsed < 1.42) {
      _sword(
        canvas,
        width * .75,
        height * .49,
        (elapsed - .78) / .64,
        mirrored: false,
      );
    } else if (elapsed >= 2.76 && elapsed < 3.40) {
      _sword(
        canvas,
        width * .25,
        height * .49,
        (elapsed - 2.76) / .64,
        mirrored: true,
      );
    }
    if (elapsed >= 1.12 && elapsed < 1.62) {
      _impact(canvas, width * .75, height * .5, elapsed - 1.12, false);
      final labelY = height * .27 - (elapsed - 1.12) * 18;
      _damageText.render(
        canvas,
        '-55 HP',
        Vector2(width * .75, labelY),
        anchor: Anchor.center,
      );
      _glitter(canvas, width * .75, labelY, elapsed - 1.12);
    }
    if (elapsed >= 3.10 && elapsed < 3.80) {
      _impact(canvas, width * .25, height * .5, elapsed - 3.10, true);
      _criticalText.render(
        canvas,
        'CRITICAL!',
        Vector2(width * .5, height * .16),
        anchor: Anchor.center,
      );
      final labelY = height * .29 - (elapsed - 3.10) * 18;
      _damageText.render(
        canvas,
        '-90 HP',
        Vector2(width * .25, labelY),
        anchor: Anchor.center,
      );
      _glitter(canvas, width * .25, labelY, elapsed - 3.10);
      _glitter(canvas, width * .5, height * .16, elapsed - 3.10);
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

  void _impact(Canvas canvas, double x, double y, double age, bool critical) {
    final duration = critical ? .70 : .50;
    final phase = (age / duration).clamp(0.0, 1.0);
    final opacity = (1 - phase).clamp(0.0, 1.0);
    final color = critical ? const Color(0xffffd566) : const Color(0xfff6f0d2);
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
