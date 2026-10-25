# Idle KardRune Flutter Web Migration Design

## Intent

Port the complete `/idle/` game to a separate Flutter Web application in `idle_flutter/`, preserving the existing visual identity, gameplay values, save schema, Firebase identity, Cloudflare Pages APIs, and live-PvP protocol. The legacy HTML/CSS/JavaScript implementation remains untouched and usable until a separately approved cutover.

## Goals and constraints

- Match all current behaviors: Tournament/training, Cards, evolutions and stats, Summon and duplicate resolution, Shards, nine-slot deck editing, asynchronous PvP, live PvP, profile, Firebase authentication, local/cloud saves, Italian/English, and PWA updates.
- Keep Stage HP at 240/340/430, ATK at 1–100, CRIT at 0–25%, critical damage at ×2, training rewards at 100/35 Shards for at most 10 rewarded duels per local calendar day, and current Summon costs/rates.
- Use the existing assets in `idle/media/`; no replacement art and no backend/schema change unless a demonstrated compatibility defect requires a separate tested change.
- Main game screens are fixed-height, safe-area-aware compositions. Only bounded collections scroll or page. Target logical viewports: 320×568, 375×667, 390×844, 393×852, 430×932.
- Keep the production `/idle/` route unchanged during development. Build Flutter with base href `/idle/` only for candidate artifacts and document a safe cutover.

## Approach

Three approaches were considered: (1) wrap the existing site in a WebView, which fails the native Flutter interaction and animation requirements; (2) rewrite everything together around UI widgets, which makes behavioral parity difficult to prove; (3) port pure rules and persistence contracts first, then build screens and realtime animation on those tested boundaries. Approach 3 is selected because it minimizes risk to progress and server compatibility while allowing incremental, reviewable commits.

## Architecture

`models/` owns JSON-compatible domain values. `game/` owns pure deterministic rules and state transitions. `repositories/` reconciles local and cloud snapshots. `services/` owns browser storage, Firebase/API requests, and WebSocket transport. `features/` owns page-level controllers and views. `widgets/`, `animations/`, and `theme/` contain reusable presentation code. Riverpod is intentionally avoided initially; small `ChangeNotifier` controllers and injected services keep dependencies low and isolate animated subtrees.

The live PvP client treats Worker events as authoritative. It sends only existing `play`, `ready`, and `pong` messages, animates `hand`, `locked`, `opponent_locked`, `round_result`, and `finished`, and resets all match-scoped state before opening a new arena. Replay timing is derived from log length while staying below the server's 180-second ready timeout.

## Compatibility and rollout

Local import reads `idle-kardrune-demo-v1` and `idle-pvp-deck-draft-v1` on the same origin and normalizes without deleting the legacy values. Cloud saves retain the exact JSON field names and revision compare-and-swap semantics. Firebase configuration continues to come from `/api/config`; bearer tokens continue to authenticate `/api/save` and `/api/pvp/*`.

The release candidate is built separately, previewed without changing production routing, and validated against both automated tests and two-account/manual device checks. Cutover happens only after approval, with the legacy directory retained for rollback and service-worker cache namespaces/versioning separated.

