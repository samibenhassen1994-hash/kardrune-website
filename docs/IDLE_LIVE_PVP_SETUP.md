# Idle KardRune — Live deck PvP (Free-tier beta)

## Gameplay
- Each player chooses up to **nine distinct cards they own** for the deck.
- After matchmaking both players receive **three cards** from their shuffled, unused deck.
- Each secretly plays one card; the server waits for both choices.
- The two chosen cards fight using fixed stage HP (240/340/430), exact ATK damage, and 2× CRIT.
- The clients animate the hit replay and acknowledge the end of the animation, then the server deals the next hand.
- Played cards cannot be used again in the same match. One round win = one point; highest score wins after no cards are left.
- This is **live input and synchronized round progression**, with individual hits replayed as an animation after both players choose. This is not synchronized per-hit animation over the wire.
- **No ranked ratings, rewards or entry to tournaments**: demo inventories are client-editable.

## One-time setup by Cloudflare account owner

1. In Cloudflare D1 Console, open the existing database `idle-kardrune`. Execute the statements from `migrations/0003_live_pvp.sql` and verify the three tables `pvp_decks`, `pvp_live_tickets`, `pvp_live_history` exist. This migration is safe to re-run.
2. From the repo root on Windows PowerShell, deploy the **dedicated Worker**:
   ```powershell
   cd C:\Users\samib\Projects\kardrune-website
   cd live-pvp
   npx.cmd wrangler deploy
   ```
   If your local clone is not present, clone `https://github.com/samibenhassen1994-hash/kardrune-website` first. The Worker configuration uses a SQLite-backed Durable Object, available on Cloudflare Workers Free. Do not enable Workers Paid.
3. Wrangler prints a `https://idle-kardrune-live-pvp.<your-subdomain>.workers.dev` URL after deployment. Copy it and change the scheme from `https://` to `wss://`.
4. In Cloudflare Pages project `kardrune-website` → **Settings → Variables and secrets → Production**, add `LIVE_PVP_URL` as **Text**, e.g. `wss://idle-kardrune-live-pvp.<your-subdomain>.workers.dev`. Do not append `/connect`. Redeploy Pages production so the Pages Function gets the new variable.
5. In the game, sign in with **two distinct Firebase accounts**, and save progress to D1 for both. In Tournament → Live Card Duel, select up to nine cards and save the deck. Press **Find Live Match** on both devices.
6. Both players must choose one of their three cards. After both have chosen, an animated round replay appears; subsequent hands appear once both animations finish.

## Free plan and security notes
- SQLite-backed Durable Objects are supported on Workers Free; exceeding any free quota can disable operations, with no automatic billing when remaining on Free.
- The dedicated Worker validates single-use tickets stored in D1 and accepts WebSocket connections only from `https://kardrune.com` and `https://www.kardrune.com`.
- The matchmaking coordinator currently uses one non-hibernating global Durable Object for beta testing. It can lose active sessions on instance restart and consumes Free tier duration while connected. For broad launch, upgrade the implementation to the hibernation WebSocket API with durable state, per-match rooms, turn deadlines, reconnect/resume support and rate limiting.
- Card attributes come from the user's D1 demo save, so **nothing here is cheat-resistant ranked PvP**. Before competitive rollout, server-issued inventory, economy validation and audited admin mutations are required.
- Do not put Firebase private credentials or D1 secrets in GitHub.
