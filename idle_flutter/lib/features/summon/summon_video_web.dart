import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class SummonVideo extends StatefulWidget {
  const SummonVideo({super.key, required this.onComplete});
  final VoidCallback onComplete;
  @override
  State<SummonVideo> createState() => _SummonVideoState();
}
class _SummonVideoState extends State<SummonVideo> {
  web.HTMLVideoElement? _video;
  bool _finished = false;
  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _video?.pause();
    widget.onComplete();
  }
  @override
  void dispose() { _video?.pause(); _video?.src = ''; super.dispose(); }
  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned.fill(child: HtmlElementView.fromTagName(tagName: 'video', onElementCreated: (element) {
      final video = element as web.HTMLVideoElement;
      _video = video;
      video..src = 'assets/assets/idle/summon/pull_animation_1.mp4'
        ..muted = true..autoplay = true..playsInline = true;
      video.style..width = '100%'..height = '100%'..objectFit = 'contain';
      video.addEventListener('ended', ((web.Event _) => _finish()).toJS);
      video.addEventListener('error', ((web.Event _) => _finish()).toJS);
      video.play().toDart.catchError((Object _) { _finish(); return null; });
    })),
    Positioned(top: 12, right: 12, child: FilledButton(onPressed: _finish, child: const Text('SKIP'))),
  ]);
}
