import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/skill_catalog.dart';

class SkillPreviewButton extends StatefulWidget {
  const SkillPreviewButton({super.key, required this.skill});
  final SkillDefinition skill;
  @override
  State<SkillPreviewButton> createState() => _SkillPreviewButtonState();
}

class _SkillPreviewButtonState extends State<SkillPreviewButton> {
  SkillPreviewGame? game;
  @override
  void dispose() {
    game?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    TextButton(
      onPressed: () {
        game?.dispose();
        setState(() => game = SkillPreviewGame(widget.skill));
      },
      child: const Text('VEDI EFFETTO'),
    ),
    if (game != null)
      SizedBox(height: 85, child: IgnorePointer(child: GameWidget(game: game!))),
  ]);
}

class SkillPreviewGame extends FlameGame {
  SkillPreviewGame(this.skill);
  final SkillDefinition skill;
  double elapsed = 0;

  @override
  Color backgroundColor() => const Color(0xff0c1930);

  @override
  void update(double dt) {
    super.update(dt);
    elapsed += dt.clamp(0, .05);
    if (elapsed > 1.3) pauseEngine();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(size.x / 2, size.y / 2);
    final phase = (elapsed / 1.3).clamp(0.0, 1.0);
    final opacity = (1 - phase).clamp(0.0, 1.0);
    final color = skill.color;
    canvas.drawCircle(center, 12 + phase * size.y * .48,
      Paint()..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke..strokeWidth = 3);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final distance = 8 + phase * (18 + i % 3 * 7);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(point, 2.5, Paint()..color = color.withValues(alpha: opacity));
    }
    final text = TextPainter(
      text: TextSpan(text: skill.name.toUpperCase(), style: TextStyle(
        color: color.withValues(alpha: .5 + .5 * opacity), fontSize: 13,
        fontWeight: FontWeight.w900,
        shadows: [Shadow(color: color, blurRadius: 11)])),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);
    text.paint(canvas, Offset(center.dx - text.width / 2, center.dy - text.height / 2));
  }
}
