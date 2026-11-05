import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class GameAudio extends ChangeNotifier {
  static const musicTracks = <String>{
    'home_music','battle_music','boss_battle_music','journey_music','shop_music','summon_music',
    'critical_story_music','fear_moment_story_music','fun_moment_story_music','quite_story_music',
    'sad_moment_story','suspance_story_music',
  };
  static const effects = <String>{
    'button_click','button_click_2','card_reveal','chest_reward','defeat','dice_roll',
    'evolution_audio','level_up','pop_up_notification','rune_absorb','rune_altar_spin',
    'rune_altar_victory','select_amount','victory',
  };
  static const _prefix = 'idle-audio-v1-';
  bool musicEnabled = true, sfxEnabled = true;
  double musicVolume = .35, sfxVolume = .70;
  web.AudioContext? _context;
  web.GainNode? _musicGain, _sfxGain;
  void _connect(web.HTMLAudioElement player, bool music) {
    final context = _context;
    if (context == null) return;
    context.createMediaElementSource(player).connect(music ? _musicGain! : _sfxGain!);
  }
  bool _unlocked = false;
  bool _suspended = false;
  void suspendMusic(bool value) {
    _suspended = value;
    if (value) { _music?.pause(); } else { _resume(); }
  }
  String? _track;
  web.HTMLAudioElement? _music;
  final Map<String, web.HTMLAudioElement> _sfx = {};
  late final web.EventListener _visibilityListener;

  GameAudio() {
    _visibilityListener = ((web.Event _) {
      if (web.document.visibilityState == 'visible') { _resume(); } else {
        _music?.pause();
        for (final player in _sfx.values) { player.pause(); }
      }
    }).toJS;
    web.document.addEventListener('visibilitychange', _visibilityListener);
    final store = web.window.localStorage;
    musicEnabled = store.getItem('${_prefix}music') != 'false';
    sfxEnabled = store.getItem('${_prefix}sfx') != 'false';
    musicVolume = (double.tryParse(store.getItem('${_prefix}musicVolume') ?? '') ?? .35).clamp(0,1);
    sfxVolume = (double.tryParse(store.getItem('${_prefix}sfxVolume') ?? '') ?? .70).clamp(0,1);
  }

  void unlock() {
    if (_context == null) {
      final context = _context = web.AudioContext();
      _musicGain = context.createGain()..gain.value = musicVolume;
      _sfxGain = context.createGain()..gain.value = sfxVolume;
      _musicGain!.connect(context.destination);
      _sfxGain!.connect(context.destination);
    }
    _context!.resume().toDart.ignore();
    if (_unlocked) return;
    _unlocked = true;
    _resume();
  }

  void music(String track) {
    if (!musicTracks.contains(track) || _track == track) return;
    _track = track;
    _music?.pause();
    if (_music != null) _music!.src = 'assets/assets/audio/music/$track.mp3';
    if (_unlocked) _resume();
  }

  void _resume() {
    if (_suspended || !_unlocked || !musicEnabled || _track == null || web.document.visibilityState != 'visible') return;
    if (_music == null) {
      _music = web.HTMLAudioElement();
      _connect(_music!, true);
    }
    final player = _music!;
    if (player.src.isEmpty) player.src = 'assets/assets/audio/music/$_track.mp3';
    player.loop = true;
    player.preload = 'none';
    _musicGain?.gain.value = musicVolume;
    try { player.play().toDart.ignore(); } catch (_) { /* Audio is optional. */ }
  }

  void effect(String effect) {
    if (!_unlocked || !sfxEnabled || !effects.contains(effect)) return;
    final player = _sfx.putIfAbsent(effect, () {
      final audio = web.HTMLAudioElement()
        ..src = 'assets/assets/audio/sfx/$effect.mp3'..preload = 'auto';
      _connect(audio, false);
      return audio;
    });
    _sfxGain?.gain.value = sfxVolume;
    player.currentTime = 0;
    try { player.play().toDart.ignore(); } catch (_) { /* Audio is optional. */ }
  }

  void setMusicEnabled(bool value) {
    musicEnabled = value;
    web.window.localStorage.setItem('${_prefix}music', '$value');
    if (value) { _resume(); } else { _music?.pause(); }
    notifyListeners();
  }
  void setSfxEnabled(bool value) {
    sfxEnabled = value;
    if (!value) { for (final player in _sfx.values) { player.pause(); } }
    web.window.localStorage.setItem('${_prefix}sfx', '$value');
    notifyListeners();
  }
  void setMusicVolume(double value) {
    musicVolume = value.clamp(0,1);
    web.window.localStorage.setItem('${_prefix}musicVolume', '$musicVolume');
    _musicGain?.gain.value = musicVolume;
    notifyListeners();
  }
  void setSfxVolume(double value) {
    sfxVolume = value.clamp(0,1);
    _sfxGain?.gain.value = sfxVolume;
    web.window.localStorage.setItem('${_prefix}sfxVolume', '$sfxVolume');
    notifyListeners();
  }

  @override
  void dispose() {
    web.document.removeEventListener('visibilitychange', _visibilityListener);
    _music?.pause(); _music?.src = '';
    for (final player in _sfx.values) { player.pause(); player.src = ''; }
    _sfx.clear();
    _context?.close().toDart.ignore();
    super.dispose();
  }
}
