import 'package:flutter/material.dart';

class ForgeVideo extends StatefulWidget {
  const ForgeVideo({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<ForgeVideo> createState() => _State();
}

class _State extends State<ForgeVideo> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
