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
