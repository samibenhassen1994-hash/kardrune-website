# Rune Clans V1 release

- Apply `migrations/0014_idle_clans.sql` exactly once to the existing D1 binding after backup/schema verification. This session does not apply remote migrations.
- Publish the Pages build and Functions together. No PvP Worker change is required. API endpoints return `CLAN_UNAVAILABLE` while the tables are missing.
- `/api/clans`: GET list (`offset`, 20/page), detail (`id` or `invite`, member offset), authenticated current membership (`me=1`); POST authenticated `create`, `join`, `leave`.
- Mutation receipts keyed by authenticated UID and request ID are committed in the same D1 transaction as the action. Retried joins cannot resurrect a membership after leaving. A unique membership UID prevents competing joins.
- Creation is limited to once per hour per account, including after dissolution. Names are NFKC-normalized and lowercased for uniqueness. Five emblems are drawn locally in Flutter.
- Leaving requires confirmation. Leadership passes to the earliest joined member (UID tie-break); an empty clan dissolves. These rules run in SQL triggers in the same transaction.
- Invites use opaque UUIDs, persist across authentication redirects and open a preview; joining always requires an explicit authenticated action. Sharing falls back to clipboard.
- No game saves, wallets, rankings or combat rules are changed. No fake players or demo clans are inserted.

Validation: SQLite migration/foreign keys, transactional creation/join/leave/retry/rate limiting, concurrent competing joins, endpoint authentication guard, seven-language Flutter forms at 320px and invite/login flow. Real Firebase/D1, installed-PWA deep links and native share sheets require a post-migration device check.

## Admin deletion and PWA invitations

- Game administrators (`player_roles.role=admin`), not clan founders, can delete any clan after confirmation. The authenticated API checks the role and the DELETE statement checks it again. Clan memberships cascade; player records, saves, wallets and creation-rate limits remain intact. No new migration is needed.
- The clan view uses the Arena background and a translucent frosted panel.
- `launch_handler: navigate-existing` reuses an installed app window where supported; it cannot force iOS to capture an external URL. Clans > Open clan invite accepts a copied link inside the installed PWA, reusing its existing authenticated session without transferring tokens or requiring browser login.
- Validation: 8 backend tests and 48 Flutter tests (including seven-language 320px forms, admin confirmation and pasted invite/session reuse); analyzer clean. Physical iPhone link handling still needs manual verification.

## Compact clan window and deck power

The clan dialog now leaves an outside dismiss area. The creation dialog scrolls with keyboard insets; Next/Done move focus or close the keyboard. Five supplied WebP emblems retain the existing dragon/wolf/phoenix/shield/raven IDs.

Member taps open a public profile (name, avatar, clan, computed power only). No UID, email, wallet, inventory or save JSON is exposed. The API reads the existing saved deck and save, without writing any data.

Power v1 is a display-only estimate, not a win prediction or combat input: sum up to nine distinct owned cards. Per card: `100 * stage + round(effectiveATK * (1 + effectiveCRIT/100)) + skillBonus`. Skill bonuses by existing rarity: common 10, uncommon 20, rare 35, epic 50, legendary 75, ultra 100. Invalid skills give no bonus. Existing Stage limits apply; unknown/unowned cards are ignored. JS and Dart use the same integer rounding. User bar uses the saved local deck; the editor previews its current selection; public profiles use the saved cloud deck. Unsynchronized local changes can therefore differ until cloud save completes.

Verification: 66 targeted Flutter tests, including keyboard at 320x568 in seven languages, dismissal, profiles, admin and deck flows; 13 SQLite/API/power/mobile-auth tests. A physical Android keyboard still needs a manual check. No new D1 migration.
