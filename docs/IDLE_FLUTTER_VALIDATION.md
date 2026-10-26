# Idle KardRune Flutter Web — validation evidence

Evidence is recorded against branch `feature/idle-flutter-web-migration`; no deployment or merge is part of validation.

> Status: release-candidate build verification succeeded, but the whole-branch review found missing runtime Firebase/cloud/PvP wiring. The branch is not yet eligible for a PR claiming a complete migration. Local-save/gameplay/deck integration and duplicate replay protection were corrected after that review; cloud and live-PvP entry integration remain open in the plan.

## Automated coverage

- Dart parity fixtures execute the original JavaScript inputs and compare normalized outputs.
- Persistence tests cover legacy local-storage import, reconciliation decisions, revision conflicts, account switches, and retry backoff. Firebase/D1 runtime integration still needs an app-level test.
- Widget tests cover 320×568 through 430×932 layouts, feature navigation, summon decisions, rewards, Deck Builder drag/tap behavior, and realtime arena lifecycle.
- PvP tests cover the unchanged Worker protocol, one-play lock, physical deal, timer, authoritative replay, critical/hit feedback, two-second result, disconnect, late-event cancellation, and second-match reset.
- Web release tests cover PWA identity, `/idle/` base injection, install scope, zoom lock, and the update-gate unit. Browser-to-Flutter update signaling is not yet wired.

Final run on 2026-10-25: `flutter test` 49/49 passed; `flutter analyze` reported no issues; `flutter build web --release --base-href /idle/` completed and produced `build/web`; live-PvP Worker rules 4/4 passed; legacy rules 26/27 passed with only the baseline CRIT fixture below.

## Visual evidence

The deterministic Flutter candidate is `idle_flutter/test/goldens/tournament_390x844.png`. Local browser smoke captures were inspected at 390×844 for both `idle/#tournament` and the `/idle/`-based Flutter release: navigation remained reachable, no overflow occurred, original card assets loaded, and browser logs contained no warnings/errors. The legacy screen contains richer promotional copy than the migrated training view; this remains visible in the comparison and is not concealed as a test success. No visual discrepancy was fixed without a reproducible widget test.

## Known baseline

The untouched legacy `idle/tests/combat-rules.test.js` suite contains one pre-existing invalid CRIT fixture: a roll of `0.5` is expected to pass a 25% threshold. The implementation and Dart parity preserve the actual JavaScript rule; all other legacy rule cases pass.
