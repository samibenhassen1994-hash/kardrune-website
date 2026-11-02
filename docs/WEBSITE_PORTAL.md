# KardRune website portal (pilot)
- Public page: `/account.html`, linked from the homepage.
- Authentication: existing Firebase Web project returned by `/api/config`.
- Data: same Cloudflare D1 binding `DB` already used by Idle KardRune.
- Create table with `migrations/0011_website_accounts.sql` (the endpoint also runs a safe CREATE TABLE IF NOT EXISTS).
- `/api/portal/profile`: bearer token verified server-side. Player metadata, verified Idle save, PvP match count, tournament count. The Android game remains **unverified** because no authenticated Android-game lookup is deployed in this repo.
- `/api/portal/admin`: strictly read-only, verified Firebase token AND D1 `player_roles.role = 'admin'`. User search and pagination; no emails or game saves in the admin list. The number of demo saves is not the number of active monthly players.
- **Admin bootstrap**: after signing up yourself, get your verified Firebase UID using Firebase Authentication console. In D1 SQL console, use
  `INSERT INTO player_roles(uid,role) VALUES ('YOUR_VERIFIED_UID','admin') ON CONFLICT(uid) DO UPDATE SET role='admin';`
  Never ship a magic admin email, password, or self-service admin endpoint.
- Requires production Cloudflare Pages Function support, Firebase variables `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN` and D1 `DB`. Ensure `kardrune.com` is authorized in Firebase Authentication.
- Account signup on the website creates only the portal account, **not** game enrollment. Idle registered requires actual D1 gameplay rows. Users may need to log in again in Idle with the same Firebase identity.
- Do not publish until testing Firebase email signup, Google login, incorrect password, password reset, sign-out, blocked user, admin vs non-admin API calls, no-data account, and mobile layout. Do not assume Android game membership from matching email.
- Browser smoke tests: `node --test scripts/website-portal.test.mjs`.
