# Gods of Olympus — Idle KardRune event (implementation notes)

The six divine heroes are **single-form**, with a single internal `:3` ID to
reuse existing Stage-3 combat limits. The UI never calls them Stage 3. New cards roll `ATK 60–100 / CRIT 8–25%`, keep `HP 430` and one fixed **Ultra** skill. Existing cards are preserved.

## Server-authoritative event summon (1200 Shards)

- Divine chance increases over a ten-pull Event cycle: **20/22/25/30/35/40/50/60/75/100%**, equal chance per god. Reset after every god, including duplicates; guaranteed by pull ten.
- Remaining probability: standard roster with Featured Dren rate-up:
  conditional Dren 42.2222%; each other hero 7.2222%.
- Non-divine stage odds (conditional on non-divine): **S1 55% / S2 30% / S3 15%**.
- Non-divine skills roll from the existing Stage-specific rarities, excluding D1–D6.
- Duplicate choices use the existing server-granted keep/replace flow; no skill reroll or evolution on divine heroes.
- All paid summons are idempotent and authorized by verified Shard wallet and save revision.

## Fixed skills and next-round inheritance

| Hero | Own skill | Bonus to next played card |
| --- | --- | --- |
| Zeus | +22% ATK; +18 first hit | +15% ATK |
| Poseidon | +16 first hit; -30% first damage received | -20% on first damage received |
| Hades | Heal 12% of direct damage dealt | Heal 8% of direct damage dealt |
| Athena | -25% of first damage received | +3 percentage points CRIT (capped 25%) |
| Ares | +12% ATK; +15 first hit | +10% ATK |
| Apollo | Heal 45 HP after first direct hit survived | Heal 60 HP after first direct hit survived |

Server consumes each `nextBlessing` exactly once at the next round.
No effects propagate to round 4 or between matches, no HP exceeds max,
and effects only apply if the divine hero was actually played.

## Release checklist

Copy all seven supplied files to the matching paths in
`idle_flutter/assets/idle/cards/olympus/{zeus,poseidon,hades,athena,ares,apollo}.webp`
and `idle_flutter/assets/idle/summon/banners/Banner_Gods_of_olympus.webp`.
The source image `Ares.jpg` must be converted to `ares.webp` preserving the
art. Run Flutter analyzer/tests and Node tests, then build the web frontend
and deploy the Cloudflare Pages + live-PvP Worker versions together.
Releasing only the frontend or only the Worker would cause invalid-card errors.

See `IDLE_OLYMPUS_PITY_ADMIN.md` for the persistent cycle, random stats and migration 0017 admin tools.

## Battle visibility and bot roster

The client consumes the server hand's nextBlessing field and replay activation events. The arena notice identifies the owner and skill, distinguishes the pending next-card bonus from the bonus active on the current card, and resets between rounds/matches. Labels are localized in seven languages.

Bots keep the existing stage distribution and stat rolls. Bronze–Gold have no Stage 3 slots and therefore no gods. Platinum/Diamond/Legend replace an existing Stage 3 slot with a random unique god at 6%/10%/14% per eligible slot, capped at 1/2/3 gods per deck. Fixed Ultra skills and normal combat/bonus rules apply; no outcome or combat RNG manipulation.

Seeded balance simulations now include inherited blessings. Holdout player win rates: 79.60%, 70.80%, 66.93%, 59.03%, 51.93%, 47.87% (Bronze through Legend), within the established targets. Deploy the updated PvP Worker to activate the new bot roster; no migration is required.
