import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/kr_localizations.dart';

/// Illustrated entrance to the existing live matchmaking flow.
/// The artwork includes the frame; the button hit area and title are Flutter.
class ArenaLanding extends StatefulWidget {
  const ArenaLanding({
    super.key,
    required this.header,
    required this.onStart,
    required this.hint,
    required this.searching,
    this.onCancel,
    this.onLeaderboard,
    this.rewardRemaining,
    this.rewardLimit = 10,
    this.now,
  });

  final VoidCallback onStart;
  final Widget header;
  final VoidCallback? onCancel;
  final VoidCallback? onLeaderboard;
  final String hint;
  final bool searching;
  final int? rewardRemaining;
  final int rewardLimit;
  final DateTime Function()? now;

  @override
  State<ArenaLanding> createState() => _ArenaLandingState();
}

class _ArenaLandingState extends State<ArenaLanding> {
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.searching) _start();
  }

  void _start() {
    _startedAt = (widget.now ?? DateTime.now)();
    _elapsed = Duration.zero;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = (widget.now ?? DateTime.now)().difference(_startedAt!));
    });
  }

  @override
  void didUpdateWidget(covariant ArenaLanding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searching && !oldWidget.searching) _start();
    if (!widget.searching && oldWidget.searching) {
      _startedAt = null;
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final seconds = _elapsed.inSeconds;
      final elapsedText = '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
      final width = bounds.maxWidth;
      final height = bounds.maxHeight;
      const imageTop = 0.0;
      final imageHeight = height - imageTop;
      // Scale controls with the original 964×1632 artwork, not just the
      // viewport: BoxFit.cover crops vertically in wider browser windows.
      const sourceRatio = 964 / 1632;
      const frameBottomInArt = .875;
      final artWidth = math.min(
        width,
        math.min(
          height * .70,
          (height - 70).clamp(1.0, double.infinity) *
              sourceRatio / frameBottomInArt,
        ),
      );
      final renderedArtHeight = math.max(height, artWidth / sourceRatio);
      // Match the gilded button painted into the original image.
      final ctaTop = renderedArtHeight * .735;
      final ctaHeight = renderedArtHeight * .14;
      // Raise the title and its tappable area by approximately 1.5 cm,
      // while keeping the painted frame and PvP quota in place.
      // Limit the offset on shorter viewports so the title remains visible.
      final titleRise = math.min(56.0, renderedArtHeight * .08);
      // Reserve the reward-row height even while the server quota is loading.
// Otherwise the START/CANCEL image abruptly shrinks when rewardRemaining
// changes from null to a number on app startup.
final quotaHeight = renderedArtHeight * .034;
      // START/CANCEL art is 2:1. The old image was height-limited by the
      // button row, so changing only width did not make it visually bigger.
      // Double the visible graphic height and its tap area while preserving
      // their center and the PvP reward row's original position.
      final oldButtonHeight = ctaHeight - quotaHeight;
      final buttonGrowth = oldButtonHeight / 2;
      final graphicWidth = math.min(artWidth * .95, oldButtonHeight * 4);
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
                Positioned.fill(
                  top: imageTop,
                  child: Image.asset(
                    'assets/idle/arena/arena_background.webp',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: 1080,
                  ),
                ),
                Positioned(top: 0, left: 0, right: 0, child: widget.header),
                Positioned(
                  top: imageTop + imageHeight * (small ? .455 : .49),
                  left: 0,
                  right: 0,
                  child: Center(
                    child: RepaintBoundary(
                      child: DuelingSwords(
                        size: swordsSize,
                        fighting: widget.searching,
                      ),
                    ),
                  ),
                ),
                if (widget.hint.isNotEmpty)
                  Positioned(
                    top: imageTop + imageHeight * .425,
                    left: artWidth * .09,
                    right: artWidth * .09,
                    child: Text(
                      widget.hint,
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
                  key: const Key('arena-painted-cta-anchor'),
                  // Shift the actual tap area, not just the image rendering:
                  // a Transform outside its parent's bounds cannot hit-test.
                  top: imageTop + ctaTop - titleRise - buttonGrowth,
                  left: artWidth * .025,
                  right: artWidth * .025,
                  height: ctaHeight + titleRise + buttonGrowth,
                  child: Column(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: widget.searching
                              ? context.tr('CANCEL')
                              : context.tr('START MATCH'),
                          child: InkWell(
                            key: const Key('find-live-match'),
                            onTap: widget.searching ? widget.onCancel : widget.onStart,
                            borderRadius: BorderRadius.circular(20),
                            child: Center(
                              child: SizedBox(
                                width: graphicWidth,
                                height: graphicWidth / 2,
                                child: Image.asset(
                                  widget.searching
                                      ? 'assets/idle/arena/cancel.webp'
                                      : 'assets/idle/arena/start.webp',
                                  key: Key(widget.searching
                                      ? 'arena-cancel-image'
                                      : 'arena-start-image'),
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.searching)
                        Padding(padding: const EdgeInsets.only(top: 6, bottom: 2),
                          child: Text(elapsedText, key: const Key('pvp-search-elapsed'),
                            style: const TextStyle(color: Color(0xffffdc83),
                              fontSize: 12, fontWeight: FontWeight.bold))),
                      // The spacer retains the original PvP counter position,
                      // while both image variants share the exact same tap area.
                      SizedBox(
                        height: titleRise + quotaHeight - buttonGrowth,
                        child: widget.rewardRemaining == null
                            ? const SizedBox.shrink()
                            : Align(
                                alignment: Alignment.bottomCenter,
                                child: SizedBox(
                                  height: quotaHeight,
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${context.tr('PvP rewards left (24h)')}: ${widget.rewardRemaining}/${widget.rewardLimit}',
                                        key: const Key('pvp-rewards-remaining'),
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: const Color(0xffffdfa8),
                                          fontFamily: 'Georgia',
                                          fontSize: (artWidth * .025).clamp(8.0, 11.0).toDouble(),
                                          fontWeight: FontWeight.w700,
                                          shadows: const [
                                            Shadow(color: Colors.black, blurRadius: 7),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                if (widget.onLeaderboard != null)
                  Positioned(
                    // Trophy in the right-hand arena banner, not under Start Match.
                    top: imageTop + imageHeight * .415,
                    right: artWidth * .018,
                    child: Semantics(
                      button: true,
                      label: context.tr('PVP LEAGUES'),
                      child: Material(
                        color: const Color(0xe8171830),
                        shape: const CircleBorder(
                          side: BorderSide(color: Color(0xffedc27e),width: 2),
                        ),
                        elevation: 8,
                        child: InkWell(
                          key: const Key('pvp-leaderboard'),
                          customBorder: const CircleBorder(),
                          onTap: widget.onLeaderboard,
                          child: const SizedBox(
                            width: 48,height: 48,
                            child: Icon(Icons.emoji_events_rounded,
                              color: Color(0xffffd38a),size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),

              ],
            ),
          ),
        ),
      );
    },
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
