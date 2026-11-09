# Idle Forge / Officina

## Scope and rules

Idle Flutter only. Navigation adds Forge after Profile (existing indices preserved); clans and combat rules are unchanged. Supplied green/blue/red keys and blacksmith MP4 are under `idle_flutter/assets/idle/forge/`; the static background is a frame of that same MP4. Video playback is muted/inline, skippable and does not choose the outcome.

The backend rolls green 35%, blue 55%, red 75% with rejection-sampled crypto RNG. Successful ATK gains a uniform integer 1–5; CRT gains 1–2 percentage points. Stage caps are imported from the existing shared catalog (50/8, 75/16, 100/25). Gains truncate at the remaining cap; requests at cap are rejected without consumption. Failure consumes one key and preserves the card. No HP, Shards, rewards or costs change.

SKILL reuses the existing stage rarity weights. Within a chosen rarity, a different existing compatible skill is selected uniformly. The old skill is excluded; the replacement is permanent. Old/new values appear in the result panel and must be acknowledged before another attempt. Catalog IDs have no RED-ARCO entry; legendary and ultra retain their existing low stage probabilities.

## Persistence and security

Apply `migrations/0015_idle_forge.sql` once, only after a verified D1 backup and schema check. The user authorized remote application after backup and review. It adds `forge_keys`, `forge_attempts` and two triggers; it neither rewrites existing progress nor grants keys. Missing tables return FORGE_UNAVAILABLE.

Firebase identity and active-account checks protect GET/POST `/api/forge`. The request accepts only card ID, key color, stat, revision and request ID; supplied outcome/stat values are ignored. A single SQLite INSERT triggers revision, ownership, pending-duplicate, ban, key and original-grant checks, then consumes the key, updates `skill_grants`, updates the relevant JSON save field, and increments the revision atomically. Any failure rolls back the entire statement. The immutable receipt and unique revision prevent replay/concurrent double spending. Local pending request IDs are scoped to Firebase UID and retained after network errors for recovery on reopen. Responses are applied only to the same current account.

Live PvP already obtains stats and skills from `skill_grants`; friendly PvP consumes the updated save. Save merging uses those grants as authority, preventing client rollback of upgrades. Combat rules are unchanged.

There is **no existing same-card Stage-advancement API**: `sam:1`, `sam:2`, `sam:3` are separate owned cards. This change does not invent an evolution mechanic or copy upgrades to a separately summoned card. Upgrades remain permanently on their original card. A future explicit evolution feature must define and implement transfer semantics; this PR cannot claim such a flow was verified.

## Key distribution and release

Balances default to zero; there is no client endpoint to mint, buy or receive keys. Distribution is deliberately out of scope. Real use with nonzero balances requires a separately approved distribution mechanism. Tests seed keys only in in-memory SQLite or simulated API responses; no live account was modified.

After review: backup and apply 0015, publish Pages Functions + Flutter build together. The PvP Worker needs no changes or deployment. Do not reapply older migrations. No schema/data rollback is needed to disable the UI; preserve attempt history.

## Validation

- 56 Node tests: 12 Forge/SQLite tests plus 44 existing live-PvP tests. Covers success boundaries, all Stage caps, skill rarity, failure consumption, idempotence, competing requests, transaction rollback, account isolation and existing friendly-combat stat consumption.
- 82 targeted Flutter tests: Forge at 320x568 in seven languages, saved request retry, zero keys, cap blocking, plus app shell, arena and clans regression suites.
- `flutter analyze --no-pub` and `flutter build web --release --base-href /idle/ --no-wasm-dry-run`.
- Physical Android/iPhone drag/drop and native video playback still require device verification. No real-key production transaction was attempted.

Local checks:
```
node --test scripts/idle-forge.test.mjs live-pvp/tests/*.test.js
cd idle_flutter
flutter test test/forge_test.dart test/app_shell_test.dart test/live_pvp_arena_test.dart test/clans_test.dart
flutter build web --release --base-href /idle/
```

## Production release — 2026-11-09

PR #89 merged as `962ed7654fc0bc8e35a83fffca79fb75907c644f` after review. Official full D1 export verified by restoration, integrity check and a local migration rehearsal; backup SHA256 `308c457218b3d59d3f380cea8f0748627594c138f036937e91b3fb661b303556` (509853 bytes), retained outside Git.

Migration 0015 applied once to `idle-kardrune`: both tables and both triggers present, `PRAGMA foreign_key_check` empty, zero key rows and zero attempts. No keys distributed or player transactions executed. Pages production deployed commit `962ed76`; public `/idle/release-id.json` serves packaged release `9f8b9c6`, and `/api/forge` correctly returns HTTP 401 without authentication. PvP Worker unchanged.

## Skill choice update

Migration 0016 adds immutable skill decisions and guards without rewriting previous attempts. New successful SKILL attempts consume the key and store a proposal; the equipped skill stays unchanged until approval. Rejection keeps the current skill and does not refund the key. ATK/CRT and failed attempts remain final immediately. Pending choices are recovered from D1 on reopen and block additional Forge attempts until decided. Accept/reject updates the receipt, skill and save revision atomically; repeated or competing requests return the first recorded decision. Existing historical skill upgrades cannot be rejected retroactively.
