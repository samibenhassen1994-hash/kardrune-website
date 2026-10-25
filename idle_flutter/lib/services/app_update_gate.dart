typedef ReloadAction = void Function();

class AppUpdateGate {
  bool _matchActive = false;
  ReloadAction? _pending;

  bool get updatePending => _pending != null;

  void setMatchActive(bool active) {
    _matchActive = active;
    if (!active) {
      final reload = _pending;
      _pending = null;
      reload?.call();
    }
  }

  void requestReload(ReloadAction reload) {
    if (_matchActive) {
      _pending = reload;
    } else {
      reload();
    }
  }
}
