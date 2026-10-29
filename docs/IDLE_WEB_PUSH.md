# KardRune extensible Web Push

Implemented in branch `feature/idle-web-push-foundation`, not deployed.

## Architecture
- Cloudflare Pages Functions: authenticated subscription API and opt-in topic preferences.
- Cloudflare D1: subscription endpoints (multiple devices per account), preferences, scheduled notification events, per-device delivery deduplication.
- Flutter web / Service Worker: permission on user gesture, PushManager subscription and notification click.
- Dedicated Cloudflare Worker Cron (every five minutes): sends due notifications even when all player tabs/PWAs are closed.

## Setup (requires manual configuration; no billing required for suitable free-tier usage)
1. Run `migrations/0005_web_push.sql` against the **existing** D1 database bound as `DB` to Pages. Use staging first and backup before production migration.
2. Generate a VAPID keypair securely, e.g. `npx web-push generate-vapid-keys` on a trusted machine. Never commit private key.
3. Set `VAPID_PUBLIC_KEY` on both Cloudflare Pages and Worker. Set `VAPID_PRIVATE_KEY` (secret) and `VAPID_SUBJECT=mailto:...` only on Worker; do **not** expose private key to Pages/browser.
4. Replace D1 `database_id` in `push_worker/wrangler.toml` with the existing D1 database ID, not a new empty database. Deploy in `push_worker` with `npm install`, `npx wrangler secret put VAPID_PRIVATE_KEY`, `npm run deploy`. Configure Worker public vars in Cloudflare dashboard or Wrangler. Review cron and CPU/request quotas on Free.
5. Deploy the updated Pages Functions and Flutter web bundle through normal CI. Verify `GET /api/notifications/vapid` returns `enabled: true`.
6. On HTTPS, sign in, tap the bell to authorize, then use one free summon; after 12h (+ cron interval) verify one push while the PWA is closed. Test multiple devices, opt-out, and invalid subscriptions. Apple iOS/iPadOS Web Push requires the web app added to Home Screen and compatible OS/browser.

## Notifications added
`free_pull`: emitted from the server-side `summon_rolls` free-pull insert trigger, due 12h after each successful free roll (independently), only when user opted in.

## Extending
1. Add topic to `functions/api/notifications/_lib.js` TOPICS.
2. Add payload copy and safe URL to `push_worker/src/index.js` topics.
3. Insert immutable events with unique IDs and server-authoritative due_at/expires_at from the corresponding game transaction.
4. Add user-facing topic toggle. Never grant rewards from notification delivery.

## Limitations
- Web Push timing is best-effort: cron is every five minutes and push delivery depends on browser/OS.
- Browser push permissions can be denied; guest/local-only gameplay has no remote push.
- Push service acceptance is not proof that the OS displayed the notification.
- Existing local timers are fallback while the app is open.
- This does not send Android native app notifications.
- No deploy or end-to-end mobile push test has been executed.
