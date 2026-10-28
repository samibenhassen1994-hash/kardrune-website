import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../../services/live_pvp_socket.dart';
import 'flame_attack_style.dart';
import 'flame_battle_audio.dart';

typedef LiveCardPose = ({double x, double y, double angle});
const liveCardRest = (x: 0.0, y: 0.0, angle: 0.0);

/// The Worker owns damage and HP. Flame only renders each server log entry.
class LiveFlameBattleGame extends FlameGame {
  LiveFlameBattleGame({
    required this.audio,
    required this.onPose,
  });

  final FlameBattleAudio audio;
  final void Function(LiveCardPose player, LiveCardPose rival) onPose;
  late final _LiveStrikeEffects _effects;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _effects = _LiveStrikeEffects(onPose);
    camera.viewport.add(_effects);
  }

  void strike(int actor, PvpCard card) {
    if (!isLoaded) return;
    final style = flameAttackStyleFor(card.hero);
    audio.attack(style);
    _effects.strike(actor, style);
    resumeEngine();
  }

  void impact(int actor, PvpCard card, int damage, bool critical) {
    if (!isLoaded) return;
    final style = flameAttackStyleFor(card.hero);
    audio.impact(style, critical: critical);
    _effects.impact(actor, style, damage, critical);
    resumeEngine();
  }

  void clear() {
    if (!isLoaded) return;
    _effects.clear();
    pauseEngine();
  }
}

class _LiveStrikeEffects extends Component {
  _LiveStrikeEffects(this.onPose);
  final void Function(LiveCardPose player, LiveCardPose rival) onPose;
  final _damagePaint = TextPaint(style: const TextStyle(
    color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900,
    shadows: [Shadow(color: Color(0xffffd45b), blurRadius: 15),
      Shadow(color: Color(0xff932923), blurRadius: 5)],
  ));
  final _critPaint = TextPaint(style: const TextStyle(
    color: Color(0xffffef96), fontSize: 23, fontWeight: FontWeight.w900,
    shadows: [Shadow(color: Color(0xffffb432), blurRadius: 15)],
  ));
  int actor = -1, damage = 0;
  FlameAttackStyle style = FlameAttackStyle.sword;
  bool critical = false;
  double strikeAge = 99, impactAge = 99;

  void strike(int value, FlameAttackStyle attackStyle) {
    actor = value;
    style = attackStyle;
    strikeAge = 0;
    impactAge = 99;
  }

  void impact(int value, FlameAttackStyle attackStyle, int valueDamage, bool isCritical) {
    actor = value;
    style = attackStyle;
    damage = valueDamage;
    critical = isCritical;
    impactAge = 0;
  }

  void clear() {
    strikeAge = impactAge = 99;
    actor = -1;
    onPose(liveCardRest, liveCardRest);
  }

  @override
  void update(double dt) {
    final step = dt.clamp(0.0, .05);
    strikeAge += step;
    impactAge += step;
    final width = findGame()?.size.x ?? 0;
    final forward = actor == 0 ? 1.0 : -1.0;
    final progress = (strikeAge / .94).clamp(0.0, 1.0);
    final advance = strikeAge < .94 ? .5 - .5 * math.cos(math.pi * progress) :
        strikeAge < 1.30 ? .5 + .5 * math.cos(math.pi * ((strikeAge - .94) / .36)) : 0.0;
    final reach = style == FlameAttackStyle.magic || style == FlameAttackStyle.arrow ? .055 : .13;
    final shakeAge = impactAge;
    final shake = shakeAge < .38 ? math.sin(shakeAge * 98) * 9 * (1 - shakeAge / .38) : 0.0;
    final active = (x: forward * width * reach * advance,
      y: -5 * math.sin(math.pi * advance), angle: forward * .11 * advance);
    final victim = (x: shake, y: shake.abs() * .13, angle: shake * .006);
    onPose(actor == 0 ? active : victim, actor == 0 ? victim : active);
    if (strikeAge > 1.3 && impactAge > .75) findGame()?.pauseEngine();
  }

  @override
  void render(Canvas canvas) {
    if (actor < 0) return;
    final game = findGame();
    if (game == null) return;
    final w = game.size.x, h = game.size.y;
    final sourceX = w * (actor == 0 ? .25 : .75);
    final targetX = w * (actor == 0 ? .75 : .25);
    final y = h * .5;
    if (strikeAge < .94) {
      final phase = (strikeAge / .94).clamp(0.0, 1.0);
      switch (style) {
        case FlameAttackStyle.magic:
          final x = sourceX + (targetX - sourceX) * phase;
          final center = Offset(x, y - 14 * math.sin(math.pi * phase));
          canvas.drawCircle(center, 19, Paint()..color = const Color(0x775f9fff));
          canvas.drawCircle(center, 11, Paint()..color = const Color(0xffb99cff));
          canvas.drawCircle(center, 4, Paint()..color = Colors.white);
        case FlameAttackStyle.arrow:
          final x = sourceX + (targetX - sourceX) * phase;
          final d = actor == 0 ? 1.0 : -1.0;
          canvas.drawLine(Offset(x - d * 30, y), Offset(x + d * 16, y),
            Paint()..color = const Color(0xffbd8d55)..strokeWidth = 4);
          final head = Path()..moveTo(x + d * 29, y)
            ..lineTo(x + d * 15, y - 7)..lineTo(x + d * 15, y + 7)..close();
          canvas.drawPath(head, Paint()..color = Colors.white);
        case FlameAttackStyle.sword:
        case FlameAttackStyle.dagger:
          if (phase > .65) {
            canvas.save();
            canvas.translate(targetX, y);
            canvas.rotate((actor == 0 ? -1 : 1) * (.95 - phase * 1.65));
            final length = style == FlameAttackStyle.sword ? 72.0 : 43.0;
            final blade = Path()..moveTo(0, -length)
              ..lineTo(7, -length + 15)..lineTo(5, 4)..lineTo(-5, 4)
              ..lineTo(-7, -length + 15)..close();
            canvas.drawPath(blade, Paint()..color = const Color(0xffc8e6fc));
            canvas.drawLine(const Offset(-17, 7), const Offset(17, 7),
              Paint()..color = const Color(0xffffd57b)..strokeWidth = 5);
            canvas.drawLine(const Offset(0, 9), const Offset(0, 31),
              Paint()..color = const Color(0xff82502e)..strokeWidth = 7);
            canvas.restore();
          }
      }
    }
    if (impactAge < .75) {
      final opacity = (1 - impactAge / .75).clamp(0.0, 1.0);
      final color = critical ? const Color(0xffffd566) :
        style == FlameAttackStyle.magic ? const Color(0xffb99bff) :
        style == FlameAttackStyle.arrow ? const Color(0xffb6e9a2) :
        const Color(0xfff6f0d2);
      canvas.drawCircle(Offset(targetX, y), 12 + impactAge * 55,
        Paint()..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke..strokeWidth = 3);
      final labelY = h * .26 - impactAge * 18;
      _damagePaint.render(canvas, '-$damage HP', Vector2(targetX, labelY), anchor: Anchor.center);
      if (critical) {
        _critPaint.render(canvas, 'CRITICAL!',
          Vector2(w * .5, h * .14), anchor: Anchor.center);
      }
      for (var i = 0; i < 12; i++) {
        final a = i * 2.399963;
        final radius = 23 + (i % 4) * 12.0;
        final x = targetX + math.cos(a) * radius;
        final yy = labelY + math.sin(a) * (12 + i % 3 * 8);
        final size = 2.5 + (i % 3) * 1.3;
        final paint = Paint()..color = const Color(0xffffe694).withValues(alpha: opacity);
        canvas.drawLine(Offset(x - size, yy), Offset(x + size, yy), paint);
        canvas.drawLine(Offset(x, yy - size), Offset(x, yy + size), paint);
      }
    }
  }
}
