import 'dart:async';
import '../../localization/kr_localizations.dart';
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
  bool get _ios => RegExp(r'iPhone|iPad|iPod').hasMatch(web.window.navigator.userAgent);
  Timer? _attachTimer;
  bool _finished = false;
  bool _needsTap = false;
  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _video?.pause();
    widget.onComplete();
  }
  @override
  void dispose() { _attachTimer?.cancel(); _video?.pause(); _video?.src = ''; super.dispose(); }
  @override
  Widget build(BuildContext context) => _ios ? _nativeVideo() : Stack(children: [
    Positioned.fill(child: HtmlElementView.fromTagName(tagName: 'video', onElementCreated: (element) {
      final video = element as web.HTMLVideoElement;
      _video = video;
      video.setAttribute('playsinline', '');
      video.setAttribute('webkit-playsinline', '');
      video..src = 'assets/assets/idle/summon/pull_animation_1.mp4'
        ..muted = false..autoplay = true..playsInline = true;
      video.style..width = '100%'..height = '100%'..objectFit = 'contain'..pointerEvents = 'none';
      video.addEventListener('ended', ((web.Event _) => _finish()).toJS);
      video.addEventListener('error', ((web.Event _) => _finish()).toJS);
      Timer.run(() {
      if (!mounted || _finished) return;
      video.play().toDart.catchError((Object _) {
        if (mounted) setState(() => _needsTap = true);
        return null;
      });
      });
    })),
    if (_needsTap) Center(child: FilledButton(onPressed: () {
      _video?.play().toDart.then((_) { if (mounted) setState(() => _needsTap = false); }).ignore();
    }, child: Text('▶ ${context.tr('PLAY')}'))),
    Positioned(top: MediaQuery.paddingOf(context).top + 12, right: 12, child: FilledButton(onPressed: _finish, child: Text(context.tr('SKIP')))),
  ]);

  Widget _nativeVideo() => HtmlElementView.fromTagName(tagName: 'div', onElementCreated: (element) {
    final root = element as web.HTMLDivElement;
    root.style..position = 'relative'..width = '100%'..height = '100%'..backgroundColor = 'black';
    final video = _video = web.HTMLVideoElement();
    video..src = 'assets/assets/idle/summon/pull_animation_1.mp4'
      ..playsInline = true..muted = false..preload = 'metadata';
    video.setAttribute('playsinline', '');
    video.setAttribute('webkit-playsinline', '');
    video.style..width = '100%'..height = '100%'..objectFit = 'contain';
    final play = web.HTMLButtonElement()..textContent = context.tr('PLAY');
    play.style..position = 'absolute'..top = '45%'..left = '35%'..width = '30%'
      ..padding = '18px'..fontSize = '20px'..zIndex = '2';
    final skip = web.HTMLButtonElement()..textContent = context.tr('SKIP');
    skip.style..position = 'absolute'..top = 'max(16px, env(safe-area-inset-top))'
      ..right = '16px'..padding = '14px 22px'..zIndex = '3';
    root.appendChild(video); root.appendChild(play); root.appendChild(skip);
    void start() {
      if (!mounted || _finished) return;
      if (video.error != null) video.load();
      video.play().toDart.then((_) { play.style.display = 'none'; }).catchError((Object _) {
        play.style.display = 'block'; return null;
      });
    }
    play.addEventListener('click', ((web.Event _) => start()).toJS);
    skip.addEventListener('click', ((web.Event _) => _finish()).toJS);
    video.addEventListener('ended', ((web.Event _) => _finish()).toJS);
    video.addEventListener('error', ((web.Event _) { play.textContent = context.tr('RETRY'); play.style.display = 'block'; }).toJS);
    _attachTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _finished) { timer.cancel(); return; }
      if (video.isConnected) { timer.cancel(); video.load(); start(); }
    });
  });
}
