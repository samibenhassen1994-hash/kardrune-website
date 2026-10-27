# Idle KardRune Flutter Web — preview and release runbook

The Flutter application is isolated in `idle_flutter/`. The legacy `idle/` directory and the Cloudflare Worker remain unchanged.

## Local preview

From `idle_flutter/`:

```powershell
flutter run -d chrome
```

For a release-like `/idle/` preview, run `tool/build_idle_web.ps1`, serve `build/web` under an `/idle/` route, and verify that API requests still target the existing relative `/api/*` endpoints.

## Release candidate build

```powershell
cd idle_flutter
.\tool\build_idle_web.ps1
```

The script runs `flutter build web --release --base-href /idle/` and checks the generated base tag. `build/web` is an untracked artifact and must not be copied into `idle/` by this task.

## Cloudflare preview (no production cutover)

Create a separate preview project or preview branch whose output directory is `idle_flutter/build/web`, mounting it at `/idle/`. Keep the current Worker routes and Firebase project configuration. Validate login, local import, cloud reconciliation, summon, training, Deck Builder, PvP matchmaking, reconnect, and a second PvP match on both a 320×568 device and a current desktop browser.

## Future cutover and rollback

Cutover requires separate approval. Preserve a deployable copy of the current `idle/` output, then switch only the static `/idle/` asset origin to the verified Flutter output; do not change `/api/*` or the WebSocket Worker. If auth, saves, or matchmaking regress, restore the prior static artifact. The shared save JSON and storage keys permit rollback without conversion.

The application defers a pending web update while a live match is active. Apply it only after the match controller leaves the arena, preventing a service-worker refresh from abandoning a round.
