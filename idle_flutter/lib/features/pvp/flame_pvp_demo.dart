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
  late final _FlameBattleGame _game;

  @override
  void initState() {
    super.initState();
    _game = _FlameBattleGame(
      onPlayerHit: () => _playerHp.value = 150,
      onRivalHit: () => _rivalHp.value = 185,
    );
  }

  void _replay() {
    _playerHp.value = 240;
    _rivalHp.value = 240;
    _game.replay();
  }

  @override
  void dispose() {
    _game.dispose();
    _playerHp.dispose();
    _rivalHp.dispose();
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
  });

  final String heroId, label;
  final int attack, crit;
  final ValueListenable<int> hp;

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
  _FlameBattleGame({required this.onPlayerHit, required this.onRivalHit});

  final VoidCallback onPlayerHit, onRivalHit;
  late final _BattleEffects _effects;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _effects = _BattleEffects(
      onPlayerHit: onPlayerHit,
      onRivalHit: onRivalHit,
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

/// Draws only a small slash, impact ring and critical text on Flame's canvas.
/// The card images are separate static Flutter widgets behind this component.
class _BattleEffects extends Component {
  _BattleEffects({
    required this.onPlayerHit,
    required this.onRivalHit,
    required this.onFinished,
  });

  final VoidCallback onPlayerHit, onRivalHit, onFinished;
  final _criticalText = TextPaint(
    style: const TextStyle(
      color: Color(0xffffde76),
      fontSize: 23,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Color(0xff5b1b13), blurRadius: 5)],
    ),
  );
  final _damageText = TextPaint(
    style: const TextStyle(
      color: Color(0xffff8b8b),
      fontSize: 24,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: Color(0xff250909), blurRadius: 4)],
    ),
  );
  double elapsed = 0;
  bool firstHit = false, secondHit = false, finished = false;

  void restart() {
    elapsed = 0;
    firstHit = secondHit = finished = false;
  }

  @override
  void update(double dt) {
    elapsed += dt.clamp(0, .05);
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
      onFinished();
    }
  }

  @override
  void render(Canvas canvas) {
    final game = findGame()!;
    final width = game.size.x, height = game.size.y;
    if (elapsed >= .18 && elapsed < 1.12) {
      _slash(canvas, width, height, (elapsed - .18) / .94, forward: true);
    } else if (elapsed >= 2.16 && elapsed < 3.10) {
      _slash(canvas, width, height, (elapsed - 2.16) / .94, forward: false);
    }
    if (elapsed >= 1.12 && elapsed < 1.62) {
      _impact(canvas, width * .75, height * .5, elapsed - 1.12, false);
      _damageText.render(
        canvas,
        '-55 HP',
        Vector2(width * .75, height * .31),
        anchor: Anchor.center,
      );
    }
    if (elapsed >= 3.10 && elapsed < 3.80) {
      _impact(canvas, width * .25, height * .5, elapsed - 3.10, true);
      _criticalText.render(
        canvas,
        'CRITICAL!',
        Vector2(width * .5, height * .24),
        anchor: Anchor.center,
      );
      _damageText.render(
        canvas,
        '-90 HP',
        Vector2(width * .25, height * .31),
        anchor: Anchor.center,
      );
    }
  }

  void _slash(
    Canvas canvas,
    double width,
    double height,
    double progress, {
    required bool forward,
  }) {
    final start = width * (forward ? .25 : .75);
    final end = width * (forward ? .75 : .25);
    final eased = 1 - math.pow(1 - progress, 3).toDouble();
    final x = start + (end - start) * eased;
    final y = height * (.5 - .10 * math.sin(progress * math.pi));
    final direction = forward ? 1.0 : -1.0;
    final trail = Paint()
      ..color = const Color(0x99fff1aa)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x - direction * 27, y + 13), Offset(x, y), trail);
    final blade = Path()
      ..moveTo(x + direction * 22, y - 14)
      ..lineTo(x - direction * 5, y + 4)
      ..lineTo(x - direction * 10, y - 1)
      ..close();
    canvas.drawPath(blade, Paint()..color = const Color(0xffffe8a0));
    canvas.drawCircle(
      Offset(x, y),
      4,
      Paint()..color = const Color(0xffffffff),
    );
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
