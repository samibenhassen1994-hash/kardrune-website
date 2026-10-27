# Idle KardRune Flutter migration audit

The source of truth is `idle/`, Pages Functions, and the `live-pvp/` Worker. Flutter keeps those files operational and ports their values and wire formats verbatim.

| Behavior | Legacy source | Flutter destination | Evidence |
|---|---|---|---|
| Catalog and media | `idle/catalog.js` | `game/catalog.dart`, `models/hero.dart` | `catalog_test.dart` |
| State and save migration | `idle/app.js` | `models/player_save.dart` | save tests |
| Rewards and training | `idle/game-rules.js` | `game/game_rules.dart` | rule tests |
| HP, ATK, CRIT and combat | `idle/combat-rules.js` | `game/combat_rules.dart` | combat tests |
| Summon and duplicates | `idle/app.js` | `game/summon_rules.dart` | summon tests |
| Nine-slot deck | `idle/deck-layout.js` | `game/deck_rules.dart` | deck tests |
| Local/cloud/Firebase | `idle/cloud*.js` | services and save repository | sync tests |
| Friendly/live PvP | `idle/pvp*.js`, APIs, Worker | PvP repository, socket and arena | protocol/widget tests |
| Languages and PWA | `idle/i18n.js`, manifest/SW | localization and web bootstrap | widget/release checks |

## Confirmed contracts

- Storage keys: `idle-kardrune-demo-v1` and `idle-pvp-deck-draft-v1`.
- Initial save: Runebearer/player, 1500 Shards, `sam:1`, ATK 40, CRIT 4.
- HP 240/340/430; ATK 1–100; CRIT 0–25%; critical damage ×2.
- Training rewards 100/35 Shards for the first 10 duels per local day.
- Standard summon: 300 Shards, stages 78%/19%/3%. Featured: 600 Shards, stages 60%/30%/10%, Dren rate-up 35%. Discarding the new duplicate returns 100 Shards.
- Cloud saves retain JSON keys and compare-and-swap `revision` semantics.
- Live decks contain 1–9 distinct owned cards; choice deadline is 30 seconds; replay readiness timeout is 180 seconds.
- Client socket messages remain `play`, `ready`, `pong`; Flutter only replays server results.

## Manual release validation

Firebase popup/redirect, real D1 conflicts, two-account matchmaking, disconnection behavior, iPhone Safari gestures, Android PWA installation, and service-worker updates require a deployed preview or physical devices and must not be reported as passed before then.
