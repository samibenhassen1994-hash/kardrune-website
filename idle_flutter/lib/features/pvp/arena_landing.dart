import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Illustrated entrance to the existing live matchmaking flow.
/// The artwork includes the frame; the button hit area and title are Flutter.
class ArenaLanding extends StatelessWidget {
  const ArenaLanding({
    super.key,
    required this.onStart,
    required this.hint,
    required this.searching,
    this.onCancel,
  });

  final VoidCallback onStart;
  final VoidCallback? onCancel;
  final String hint;
  final bool searching;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = bounds.maxWidth;
      final height = bounds.maxHeight;
      final wide = width / height > .7;
      final artWidth = wide ? height * 964 / 1632 : width;
      final small = height < 650;
      final swordsSize = small ? 76.0 : 106.0;
      return ColoredBox(
        color: const Color(0xff170f16),
        child: Center(
          child: SizedBox(
            width: artWidth,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/idle/arena/arena_background.webp',
                  fit: wide ? BoxFit.fill : BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: 1080,
                ),
                Positioned(
                  top: height * (small ? .48 : .515),
                  left: 0,
                  right: 0,
                  child: Center(
                    child: RepaintBoundary(
                      child: DuelingSwords(
                        size: swordsSize,
                        fighting: searching,
                      ),
                    ),
                  ),
                ),
                Positioned(
              top: height * .425,
                  left: artWidth * .09,
                  right: artWidth * .09,
                  child: Text(
                    hint,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xffffe5af),
                      fontFamily: 'Georgia',
                      fontSize: small ? 10 : 12,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 7),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: height * .681,
                  left: artWidth * .22,
                  right: artWidth * .22,
                  height: height * .073,
                  child: Semantics(
                    button: true,
                    label: searching ? 'Searching for opponent' : 'Start match',
                    child: InkWell(
                      key: const Key('find-live-match'),
                      onTap: searching ? null : onStart,
                      borderRadius: BorderRadius.circular(20),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'START MATCH',
                            style: TextStyle(
                              color: const Color(0xffffdfa0),
                              fontFamily: 'Georgia',
                              fontSize: small ? 22 : 29,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.7,
                              shadows: const [
                                Shadow(
                                  color: Color(0xff170b08),
                                  offset: Offset(0, 3),
                                  blurRadius: 2,
                                ),
                                Shadow(
                                  color: Color(0xfff3a645),
                                  blurRadius: 13,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: small ? 72 : 82,
                  child: searching && onCancel != null
                      ? Center(child: _SecondaryAction(label: 'CANCEL', onTap: onCancel!))
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xb8170d15),
    borderRadius: BorderRadius.circular(7),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36, minWidth: 90),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xc5e5b66b)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xffffe4ae),
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class DuelingSwords extends StatefulWidget {
  const DuelingSwords({super.key, required this.size, required this.fighting});
  final double size;
  final bool fighting;

  @override
  State<DuelingSwords> createState() => _DuelingSwordsState();
}

class _DuelingSwordsState extends State<DuelingSwords>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );

  @override
  void initState() {
    super.initState();
    if (widget.fighting) controller.repeat();
  }

  @override
  void didUpdateWidget(covariant DuelingSwords oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fighting == oldWidget.fighting) return;
    if (widget.fighting) {
      controller.repeat();
    } else {
      controller.stop();
      controller.value = 0;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final swing = widget.fighting && !reduceMotion
              ? math.sin(controller.value * math.pi * 2) * .22
              : 0.0;
          final flash = widget.fighting && !reduceMotion
              ? math
                    .pow(
                      math.max(0, math.cos(controller.value * math.pi * 4)),
                      8,
                    )
                    .toDouble()
              : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -.64 + swing,
                child: CustomPaint(
                  size: Size(widget.size * .72, widget.size * .72),
                  painter: const _SwordPainter(),
                ),
              ),
              Transform.rotate(
                angle: .64 - swing,
                child: CustomPaint(
                  size: Size(widget.size * .72, widget.size * .72),
                  painter: const _SwordPainter(),
                ),
              ),
              if (flash > .02)
                Container(
                  width: 9 + flash * 17,
                  height: 9 + flash * 17,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xffffe9ac)
                        .withValues(alpha: flash * .9),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xffffd58a).withValues(alpha: flash),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SwordPainter extends CustomPainter {
  const _SwordPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final blade = Path()
      ..moveTo(x, size.height * .02)
      ..lineTo(x + size.width * .075, size.height * .24)
      ..lineTo(x + size.width * .048, size.height * .67)
      ..lineTo(x - size.width * .048, size.height * .67)
      ..lineTo(x - size.width * .075, size.height * .24)
      ..close();
    canvas.drawPath(
      blade,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xff91a7bb), Color(0xffffffff), Color(0xff6b8fae)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawLine(
      Offset(x, size.height * .11),
      Offset(x, size.height * .67),
      Paint()
        ..color = const Color(0xffeff9ff)
        ..strokeWidth = 1.5,
    );
    final gold = Paint()..color = const Color(0xffffc76c);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, size.height * .7),
          width: size.width * .38,
          height: size.height * .07,
        ),
        const Radius.circular(3),
      ),
      gold,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, size.height * .82),
          width: size.width * .08,
          height: size.height * .22,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xff63341d),
    );
    canvas.drawCircle(Offset(x, size.height * .94), size.width * .055, gold);
  }

  @override
  bool shouldRepaint(covariant _SwordPainter oldDelegate) => false;
}
