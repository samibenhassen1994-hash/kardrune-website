# Android → Idle Arena authentication handoff

This branch adds an optional mobile-only login path to the existing Idle Web
client. Normal browser login remains unchanged. Nothing in this branch is
deployed automatically.

## Cloudflare configuration before release

1. Apply `migrations/0006_mobile_auth_handoff.sql` to the **existing** Pages D1
   database bound as `DB`. Do not create another database. Apply it first in a
   non-production environment for testing, then in production before deploying
   the Pages functions.
2. Confirm the existing `FIREBASE_PROJECT_ID` is `idle-kardrune`.
3. Add these Cloudflare Pages encrypted secrets for the same Firebase project:
   - `FIREBASE_SERVICE_ACCOUNT_EMAIL`: the `client_email` field from a dedicated
     Firebase service account JSON.
   - `FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY`: the matching PEM `private_key`
     field, including its BEGIN/END lines. Preserve actual newlines.
4. Never commit or print the service account JSON, private key, or secret values.
   Grant access to the secrets only to the Pages deployment environment that
   serves `kardrune.com`.
5. Build and package `idle_flutter` with base href `/idle/` using the existing
   website release workflow. Deploy the Web client, Pages functions and D1
   migration together after review. The separate live PvP Worker is unchanged.

## Protocol

- Android sends its current Firebase ID token only in an HTTPS Authorization
  header to `POST /api/mobile-auth/issue`.
- The Pages function verifies the Firebase signature and claims, creates 32
  random bytes, stores only a SHA-256 hash in the existing D1 database, and
  returns a 60-second single-use code.
- Android passes that code only to the embedded `/idle/` page through a
  same-origin WebView message. No ID token, credential or code is in the URL.
- The page posts the code to `/api/mobile-auth/exchange`. D1 atomically deletes
  the row, and the function signs a Firebase custom token for the same UID.
- The page signs in with that token before starting cloud save sync. Mobile
  bootstrap loads an existing remote Idle save without uploading the WebView's
  local guest data. An account with no remote save requires explicit review.

## Verification before production

With a staging Pages deployment and the migration/secrets configured, test a
real Android device: same UID, cards, shards and statistics; logout and account
switch; no network; expired/reused codes; WebSocket PvP and D20 flow. Normal
browser Google/email login must still work. The tests in this branch use fake
D1 and in-memory signing keys; they do not prove production credentials or
network configuration.
