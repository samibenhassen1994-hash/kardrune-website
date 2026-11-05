@TestOn('browser')
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/services/game_audio.dart';

void main() {
  test('audio preferences persist across manager lifecycle', () {
    final first = GameAudio();
    first.setMusicEnabled(false);
    first.setSfxEnabled(false);
    first.setMusicVolume(.42);
    first.setSfxVolume(.61);
    first.dispose();
    final reopened = GameAudio();
    expect(reopened.musicEnabled, false);
    expect(reopened.sfxEnabled, false);
    expect(reopened.musicVolume, .42);
    expect(reopened.sfxVolume, .61);
    reopened.setMusicEnabled(true);
    reopened.setSfxEnabled(true);
    reopened.setMusicVolume(.35);
    reopened.setSfxVolume(.70);
    reopened.dispose();
  });
}
