import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'flame_attack_style.dart';
import 'flame_battle_audio.dart';

FlameBattleAudio createFlameBattleAudio() => _WebBattleAudio();

/// Short synthesized cues avoid downloads and can be unlocked by the tap that
/// opens TEST FLAME on iOS Safari.
class _WebBattleAudio implements FlameBattleAudio {
  web.AudioContext? _context;

  @override
  void unlock() {
    try {
      final context = _context ??= web.AudioContext();
      if (context.state != 'running') context.resume().toDart.ignore();
    } catch (_) {
      // Audio is optional if a browser or device blocks it.
    }
  }

  @override
  void attack(FlameAttackStyle style) {
    switch (style) {
      case FlameAttackStyle.sword:
        _tone('sawtooth', 430, 120, .18, .045);
      case FlameAttackStyle.dagger:
        _tone('sawtooth', 720, 200, .10, .035);
      case FlameAttackStyle.magic:
        _tone('sine', 360, 840, .30, .045);
        _tone('triangle', 540, 1160, .26, .025);
      case FlameAttackStyle.arrow:
        _tone('sawtooth', 920, 280, .15, .030);
    }
  }

  @override
  void impact(FlameAttackStyle style, {required bool critical}) {
    switch (style) {
      case FlameAttackStyle.sword:
        _tone('triangle', 960, 340, .20, .070);
        _tone('sine', 140, 65, .13, .045);
      case FlameAttackStyle.dagger:
        _tone('triangle', 1200, 420, .12, .060);
      case FlameAttackStyle.magic:
        _tone('sine', 680, 1320, .28, .065);
        _tone('triangle', 350, 780, .22, .032);
      case FlameAttackStyle.arrow:
        _tone('triangle', 360, 95, .11, .055);
    }
    if (critical) _tone('sine', 900, 1550, .27, .055);
  }

  void _tone(
    String wave,
    double from,
    double to,
    double duration,
    double volume,
  ) {
    final context = _context;
    if (context == null || context.state != 'running') return;
    try {
      final when = context.currentTime;
      final oscillator = context.createOscillator()..type = wave;
      final gain = context.createGain();
      oscillator.frequency
        ..setValueAtTime(from, when)
        ..exponentialRampToValueAtTime(to, when + duration);
      gain.gain
        ..setValueAtTime(.0001, when)
        ..linearRampToValueAtTime(volume, when + .012)
        ..exponentialRampToValueAtTime(.0001, when + duration);
      oscillator.connect(gain);
      gain.connect(context.destination);
      oscillator.start(when);
      oscillator.stop(when + duration + .02);
    } catch (_) {
      // Visual feedback remains available when Web Audio is unavailable.
    }
  }

  @override
  void pause() {
    final context = _context;
    if (context != null && context.state == 'running') {
      context.suspend().toDart.ignore();
    }
  }

  @override
  void dispose() {
    final context = _context;
    _context = null;
    if (context != null && context.state != 'closed') {
      context.close().toDart.ignore();
    }
  }
}
