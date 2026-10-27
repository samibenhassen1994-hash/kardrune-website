{{flutter_js}}
{{flutter_build_config}}
// The custom Idle KardRune PWA owns all updates; Flutter must not register
// its deprecated second service worker on the same scope.
_flutter.loader.load({
  // Embed Flutter inside an actual phone-width element rather than resizing
  // the flutter-view canvas after engine initialization.
  config: { hostElement: document.getElementById('idle-game-frame') }
});
