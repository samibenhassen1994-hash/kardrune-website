# Idle KardRune skill system v1

The shared, versioned source of the 30 skills is `shared/skill_catalog.js`.
After editing it, regenerate Flutter's catalog with
`node idle_flutter/tool/generate_skill_catalog.mjs` from the repository root.
The Stage 1/2/3 rarity weights are expressed per 1,000 and the selected
rarity's five skills are equiprobable.

## Existing saves and online authority

`migrations/0004_skill_system.sql` snapshots existing accounts, cards,
statistics, Shards and daily practice counts. It creates server grants and
verified wallets without replacing the original saves. A legacy card's skill
is rolled once on first account access; its existing ATK and CRIT remain.
The migration was applied to the existing `idle-kardrune` D1 database on
2026-10-28 after an export backup. The aggregate counts were 7 saves,
7 wallets, 46 legacy cards and 46 grants.

Online summons, duplicate decisions, practice and friendly PvP rewards use
authenticated, revision checked, idempotent endpoints. The live Worker loads
ATK, CRIT and the skill from `skill_grants`, then decides all combat effects.
The Flutter/Flame client only replays the server timeline. Local guest cards
remain playable offline; an unverified card cannot enter a live deck. On the
first upload to a new account, a copy of the guest save is kept on the device
and can be restored from Profile after signing out. New online accounts start
with the existing 1,500 verified Shards; local guest currency is not promoted
to the competitive wallet.

No ranked rating or ranked reward has been enabled. A completed friendly PvP
match retains its existing 100 Shard demo reward, now claimed once per account
from the server's match history.

## Manual checks for the owner

The user requested no automated gameplay tests. On an iPhone PWA, check Stage
drop and skill distribution, duplicate keep/replace across reload, account
sync, the position and inspector of every card label, three live PvP rounds
with two accounts, skill effects and matching HP on both devices, skip replay,
and the final COMPLETE screen. Confirm the cloud and Worker deployment before
testing with real accounts.
