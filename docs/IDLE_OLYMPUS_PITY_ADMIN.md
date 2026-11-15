# Olympus progressive cycle and admin test grants

## Rules

Event costs 1,200 Shards. God chances for pulls 1–10 are 20%, 22%, 25%, 30%, 35%, 40%, 50%, 60%, 75%, 100%. All six gods are equally likely. The cycle resets only after pull ten; an earlier god or duplicate does not reset it. Normal fallback stages and Dren rate-up are unchanged.

The server derives the position from the authenticated user's existing immutable Event summon receipts (cost 1200). Historical Event pulls count. Standard/Featured/free pulls do not count. Duplicate decisions do not consume another pull, and retrying a roll ID cannot advance the counter. Existing revision guards serialize competing summons. No pity migration or writable client counter is needed.

New gods roll ATK 60–100 and CRIT 8–25 inclusive using the same secure Stage 3 RNG as regular cards. HP stays 430, one form and the fixed Ultra skill remain unchanged. Existing cards are not rewritten. The Worker accepts the entire Stage 3 interval, including previous max-stat grants.

The Event UI shows the next pull and server chance, refreshes after a pull, and requires sign-in for the persistent Event cycle. All new labels are translated in seven languages.

## Admin tool

Profile shows a shield tool only after server authorization via `player_roles.role=admin`. It grants only to the authenticated admin, not a target UID. Each request can add 0–100,000 Shards and 0–1,000 keys of **each** color, with at least one nonzero amount. Defaults are 12,000 Shards and 50 keys each.

Migration `0017_admin_test_resources.sql` creates an audit ledger and atomic triggers. Role, ban status, save revision, integer bounds and wallet existence are enforced. Wallet, keys and save revision update in the same insert transaction. Request IDs prevent duplicate credits; the UI persists a pending request across dialog/app reopening and updates the cloud wallet after success.

## Activation

No remote migration or production deployment was performed in this work. Before activating the admin tool, back up D1 and apply 0017 once. Without it the tool remains disabled. Publish the Worker accepting random divine stats before enabling the updated Pages API/UI. Merge/build through the normal release process; no new Firebase project or service is involved.

## Verification

125 Node tests passed, including real SQLite checks of migration/atomicity, role/banned-account guards, idempotency, isolation, all ten exact RNG thresholds and cycle persistence/reset. The 188 existing non-golden Flutter tests passed; three additional widget scenarios cover admin visibility, successful credited wallet and guaranteed-pull UI reset. Seven-language coverage passed. Flutter analyzer and Web release build passed. No real Shards or keys were credited during testing.
