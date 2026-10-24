# Idle KardRune: Friendly PvP test deployment

## Deployment steps
1. On the existing **idle-kardrune** Cloudflare D1 database (bound as `DB`), apply `migrations/0002_pvp_friendly.sql` **once**. In Windows PowerShell after downloading the repository migration: `npx.cmd wrangler d1 execute idle-kardrune --remote --file=0002_pvp_friendly.sql`.
2. Confirm `pvp_friendly_queue` and `pvp_friendly_matches` exist in D1 console.
3. Confirm Cloudflare Pages `kardrune-website` has deployed the new `main` commit with Pages Functions enabled.
4. Sign in to **two distinct Firebase accounts**, each on a different browser/device. In each account select a card in Cards, allow automatic cloud save, and confirm a demo backup is available.
5. Open Tournament on each device. Press **Find Online Rival** on the first account, then on the second. The second can form a match and the first will find it via 10-second polling.
6. Inspect the server-calculated replay, then press **Stop Search / New Match** on both devices before repeating.

## Safety / limitations
- Friendly PvP is a functional **async test mode**, **not live turn-by-turn PvP**. Both card snapshots are read from authenticated users' D1 demo saves when joining. The server computes the deterministic battle and persists its replay.
- Since the demo still permits arbitrary Shards, inventory and stats through the browser, friendly results carry **no rewards, rating changes, or tournament qualification**. Never treat them as competitive authoritative inventory.
- The server validates Firebase tokens on every request and does not accept uploaded damage or match outcomes. Atomic D1 batch statements ensure two simultaneous matchmakers cannot claim the same waiting ticket twice.
- Waiting tickets older than five minutes are ignored; leave and join again if search has expired. This prototype uses polling every 10 seconds, with low write usage.
- Cloudflare D1 Free quotas and Pages Functions request quotas apply. No billing should be enabled for this phase.
- Ranked PvP and tournaments need **server-issued** cards and Shards, secure summons/rewards, rate limiting, eligibility checks, abandonment handling, anti-abuse, analytics, player reports and error recovery before release.
