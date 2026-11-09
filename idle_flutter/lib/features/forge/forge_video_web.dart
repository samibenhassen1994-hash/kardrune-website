import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../localization/kr_localizations.dart';

class ForgeVideo extends StatefulWidget {
  const ForgeVideo({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<ForgeVideo> createState() => _State();
}

class _State extends State<ForgeVideo> {
  web.HTMLVideoElement? video;
  Timer? attach, timeout;
  bool done = false;
  void finish() {
    if (!mounted || done) return;
    done = true;
    video?.pause();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (element) {
      final root = element as web.HTMLDivElement;
      root.style
        ..width = '100%'
        ..height = '100%'
        ..position = 'relative'
        ..backgroundColor = 'black';
      final v = video = web.HTMLVideoElement()
        ..src = 'assets/assets/idle/forge/forge.mp4'
        ..muted = true
        ..playsInline = true
        ..controls = false;
      v.setAttribute('playsinline', '');
      v.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'contain';
      final skip = web.HTMLButtonElement()..textContent = context.tr('SKIP');
      skip.style
        ..position = 'absolute'
        ..right = '12px'
        ..top = '12px'
        ..padding = '12px';
      skip.addEventListener('click', ((web.Event _) => finish()).toJS);
      v.addEventListener('ended', ((web.Event _) => finish()).toJS);
      v.addEventListener('error', ((web.Event _) => finish()).toJS);
      root.appendChild(v);
      root.appendChild(skip);
      attach = Timer.periodic(const Duration(milliseconds: 50), (t) {
        if (!mounted || done) {
          t.cancel();
          return;
        }
        if (v.isConnected) {
          t.cancel();
          v.play().toDart.catchError((Object _) {
            finish();
            return null;
          });
        }
      });
      timeout = Timer(const Duration(seconds: 20), finish);
    },
  );
  @override
  void dispose() {
    attach?.cancel();
    timeout?.cancel();
    video?.pause();
    video?.src = '';
    super.dispose();
  }
}
