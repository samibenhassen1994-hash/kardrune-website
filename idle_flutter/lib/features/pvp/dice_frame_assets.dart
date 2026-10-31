abstract final class DiceFrameAssets {
  static const _root = 'assets/idle/animations/dice_kr_v2_frames';

  static final List<String> spinFrames = List.unmodifiable(
    List.generate(30, (index) => '$_root/spin_${_two(index + 1)}.webp'),
  );

  static String result(int value) {
    if (value < 1 || value > 20) {
      throw RangeError.range(value, 1, 20, 'value');
    }
    return '$_root/result_${_two(value)}.webp';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
