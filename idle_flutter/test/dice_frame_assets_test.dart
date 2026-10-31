import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/pvp/dice_frame_assets.dart';

void main() {
  test('D20 spin uses thirty lightweight frame files in stable order', () {
    expect(DiceFrameAssets.spinFrames, hasLength(30));
    expect(
      DiceFrameAssets.spinFrames.first,
      'assets/idle/animations/dice_kr_v2_frames/spin_01.webp',
    );
    expect(
      DiceFrameAssets.spinFrames.last,
      'assets/idle/animations/dice_kr_v2_frames/spin_30.webp',
    );
  });

  test('each authoritative result maps to one persistent final frame', () {
    expect(
      DiceFrameAssets.result(1),
      'assets/idle/animations/dice_kr_v2_frames/result_01.webp',
    );
    expect(
      DiceFrameAssets.result(20),
      'assets/idle/animations/dice_kr_v2_frames/result_20.webp',
    );
    expect(() => DiceFrameAssets.result(0), throwsRangeError);
    expect(() => DiceFrameAssets.result(21), throwsRangeError);
  });
}
