import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

const bool arenaAvailable = true;

void openTrialArena(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => const _TrialArena(),
  ));
}

class _TrialArena extends StatefulWidget {
  const _TrialArena();
  @override
  State<_TrialArena> createState() => _TrialArenaState();
}

class _TrialArenaState extends State<_TrialArena> {
  web.HTMLIFrameElement? _frame;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Arena 3D')),
    body: HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (element) {
        final frame = _frame = element as web.HTMLIFrameElement;
        frame.title = 'Arena 3D KardRune';
        frame.src = Uri.parse(web.document.baseURI)
            .resolve('combat3d/duel.html?hero=ares&embedded=1').toString();
        frame.style
          ..border = '0'
          ..width = '100%'
          ..height = '100%';
      },
    ),
  );
  @override
  void dispose() {
    _frame?.src = 'about:blank';
    _frame = null;
    super.dispose();
  }
}
