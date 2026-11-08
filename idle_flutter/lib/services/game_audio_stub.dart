import 'package:flutter/foundation.dart';

class GameAudio extends ChangeNotifier {
  bool musicEnabled = true, sfxEnabled = true;
  double musicVolume = .35, sfxVolume = .70;
  void unlock() {}
  void prepareBattle() {}
  void suspendMusic(bool value) {}
  void music(String track) {}
  void effect(String effect) {}
  void setMusicEnabled(bool value) { musicEnabled = value; notifyListeners(); }
  void setSfxEnabled(bool value) { sfxEnabled = value; notifyListeners(); }
  void setMusicVolume(double value) { musicVolume = value; notifyListeners(); }
  void setSfxVolume(double value) { sfxVolume = value; notifyListeners(); }
}
