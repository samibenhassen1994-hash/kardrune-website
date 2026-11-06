{{flutter_js}}
{{flutter_build_config}}
// An old installed worker can still control the first navigation after a
// deploy. Version the entrypoint itself so it cannot reuse a four-hour-old JS.
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath === 'main.dart.js') {
    build.mainJsPath = 'main.dart.js?v=__KARDRUNE_PACKAGED_RELEASE__';
  }
}
// The custom Idle KardRune PWA owns all updates; Flutter must not register
// its deprecated second service worker on the same scope.
_flutter.loader.load({
  // Embed Flutter inside an actual phone-width element rather than resizing
  // the flutter-view canvas after engine initialization.
  config: { hostElement: document.getElementById('idle-game-frame') },
  onEntrypointLoaded: async (initializer) => {
    try {
      const runner = await initializer.initializeEngine({hostElement: document.getElementById('idle-game-frame')});
      await runner.runApp();
    } catch (_) { window.kardruneLoadingError?.(); }
  }
});
