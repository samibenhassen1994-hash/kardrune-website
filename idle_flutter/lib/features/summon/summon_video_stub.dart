import 'package:flutter/material.dart';
class SummonVideo extends StatelessWidget {
  const SummonVideo({super.key, required this.onComplete});
  final VoidCallback onComplete;
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onComplete());
    return const SizedBox.shrink();
  }
}
