# Idle KardRune — Cloudflare D1 + Firebase Spark

## Why this is a foundation, not production PvP
This is an **opt-in cloud backup of legacy local demo data**, not a competitive inventory. It must not grant PvP cards, shards, ranking, or currency. The local UI's Shards editor remains demo-only. Competitive Summon, reward issuance, matches and tournaments must be server-authoritative before enabling ranked play.

## Configure Cloudflare (Free)
1. In Cloudflare dashboard, create D1 database named `idle-kardrune`. Copy its database ID.
2. Cloudflare Pages > kardrune website project > Settings > Bindings > add D1 database binding named **DB**, select the new D1 DB; set for production and preview as appropriate.
3. Apply `migrations/0001_idle.sql` in D1 SQL console (one-time).
4. Add Pages environment variables `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, and (optional) `FIREBASE_APP_ID`. Redeploy.
5. Ensure Pages builds from GitHub **with Functions support** (build output at repo root, no build command). Test `/api/config` then `/api/me` after sign-in.
6. Use only free plans and check quotas. Never add Firebase admin private keys or service account secrets to GitHub.

## Configure Firebase Authentication (Spark)
1. Create a **separate Firebase project** for Idle KardRune; create a Web app; copy only web SDK config (not service account credentials).
2. Authentication > Sign-in method: enable **Email/Password** and **Google**.
3. Authentication > Settings > Authorized domains: add `kardrune.com` and any Cloudflare Pages preview domain used for testing.
4. In Cloudflare Pages add Firebase projectId, apiKey and authDomain. `FIREBASE_AUTH_DOMAIN` generally is `<project-id>.firebaseapp.com`.
5. Do not upgrade to Blaze or enable billing if zero cost is mandatory. Certain services and quotas will be unavailable; design features to degrade gracefully.

## Secure administration
After creating a legitimate user and checking its Firebase UID, add role in D1 SQL console **manually** (using own UID):
`INSERT INTO player_roles(uid,role) VALUES ('FIREBASE_UID_FROM_YOUR_ACCOUNT','admin');`
The application does not ship default admin credentials, an admin signup route, or client-writeable role fields. Restrict all debug mutations on backend. The admin status endpoint is read-only, and available only to granted admin role.

## Cloud saves
Players can register with Google or email/password, sign in, download an existing demo save, or upload their current local demo progress deliberately. These are user actions, not automatic merging. Account switch and version conflicts never silently overwrite saves. Database backups require operational planning before public launch.

## Data model for future competitive features
- `players`: public-ish profile metadata and account UIDs.
- `demo_saves`: noncompetitive snapshot, single-owner access.
- `competitive_inventory` + `currency_ledger`: server-issued cards and auditable currency.
- `pvp_queue` and `pvp_matches`: pairing and authoritative results with server-chosen seed.
- `tournaments` and `tournament_entries`: registration and events.
- `player_roles` + `admin_audit`: backend-enforced admin and auditing.

## Next milestones
1. Deploy and test Auth + D1 binding; validate Google and email login on phone.
2. Implement server-generated summons, rewards, and migration policy from local demo.
3. Build server-controlled matchmaking and asynchronous autoplay battle simulations, never client-reported wins.
4. Add tournament scheduling, anti-abuse / rate limits, moderation and privacy/data deletion support.
