import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../localization/kr_localizations.dart';

class SummonVideo extends StatefulWidget {
  const SummonVideo({super.key, required this.onComplete});
  final VoidCallback onComplete;
  @override
  State<SummonVideo> createState() => _SummonVideoState();
}
class _SummonVideoState extends State<SummonVideo> {
  web.HTMLVideoElement? _video;
  Timer? _attachTimer;
  bool _finished = false;
  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _video?.pause();
    widget.onComplete();
  }
  @override
  void dispose() {
    _attachTimer?.cancel();
    _video?.pause();
    _video?.src = '';
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'div', onElementCreated: (element) {
      final root = element as web.HTMLDivElement;
      root.style..position = 'relative'..width = '100%'..height = '100%'..backgroundColor = 'black';
      final video = _video = web.HTMLVideoElement();
      video..src = 'assets/assets/idle/summon/pull_animation_1.mp4'
        ..playsInline = true..muted = false..controls = false..preload = 'auto';
      video.setAttribute('playsinline', '');
      video.setAttribute('webkit-playsinline', '');
      video.style..width = '100%'..height = '100%'..objectFit = 'contain';
      final skip = web.HTMLButtonElement()..textContent = context.tr('SKIP');
      skip.style..position = 'absolute'..top = 'max(16px, env(safe-area-inset-top))'
        ..right = '16px'..padding = '14px 22px'..zIndex = '3';
      root.appendChild(video);
      root.appendChild(skip);
      Future<void> start() async {
        if (!mounted || _finished) return;
        try {
          await video.play().toDart;
        } catch (_) {
          if (!mounted || _finished) return;
          // Autoplay policies can prohibit sound after the asynchronous summon.
          // Keep the animation moving without a visible Play overlay.
          video.muted = true;
          try { await video.play().toDart; } catch (_) {
            // A native tap on the video retries; Skip always remains available.
          }
        }
      }
      video.addEventListener('click', ((web.Event _) {
        if (!mounted || _finished) return;
        video.muted = false;
        if (video.error != null) video.load();
        unawaited(start());
      }).toJS);
      skip.addEventListener('click', ((web.Event _) => _finish()).toJS);
      video.addEventListener('ended', ((web.Event _) => _finish()).toJS);
      video.addEventListener('error', ((web.Event _) => _finish()).toJS);
      _attachTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!mounted || _finished) { timer.cancel(); return; }
        if (video.isConnected) { timer.cancel(); unawaited(start()); }
      });
    },
  );
}
