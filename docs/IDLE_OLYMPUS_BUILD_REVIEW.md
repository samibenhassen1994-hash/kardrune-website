# Olympus build review — 2026-11-14

Base: `fc1dbe489ec048e7db404851f2478fcc763f010b` (PR #90).

## GitHub Actions evidence

- Runs `42812644206` and `42809896837` started successfully, then failed in the deterministic test step. The failing `live_match_app_test.dart` fixture supplied only three deck cards after matchmaking began requiring nine. Build and packaging steps were skipped. The logs report respectively 186/185 passing tests and one failing test; these failures predate Olympus.
- Run `43096258918` is queued with timestamps unchanged since 2026-11-11 20:28:26 UTC, zero jobs and zero check runs in suite `116707387151`. No compiler ran.
- Two Olympus runs (`43096043582`, `43096005111`) are also queued. No in-progress or pending runs were returned. The main workflow uses `ubuntu-latest`, and its concurrency group is scoped by ref; the Olympus workflow has no concurrency lock. Repository Actions are enabled and all actions allowed.
- No GitHub diagnostic identifies billing, quota, or runner availability as the cause. The authenticated billing usage API returned 404, so account spending limits cannot be verified here. Do not report exhausted minutes as established fact. An account owner should inspect Billing/Actions budgets and GitHub Actions service status, then contact GitHub Support with the above run IDs if no account restriction is shown. No run was repeatedly restarted.

## Fixes

- Nine-card PvP fixture; active Olympus banner and 33-card collection assertions.
- Remove twelve redundant `const` analyzer findings in the Olympus catalog.
- Reject invalid divine evolutions during local save import, preserve valid divine and legacy cards, and display collection capacity 33.
- Explicitly clear next-card blessings on match initialization; test consumption only in the following round.
- Inject optional RNG into server summon helpers for exact boundary tests; production retains cryptographic RNG. Rates, cost, stats and skills are unchanged.
- Update Olympus CI from its retired feature branch to main and PRs; enable PR Web builds without committing compiled files from PR events. Pin the tested Flutter version and Node 22, verify generated skills, and run Node API/security tests. Strict analyzer remains enabled.
- Update a pre-existing marketing-header test to assert the current direct-child selector rather than an obsolete selector.

## Validation

- Flutter 3.47.5 / Dart 3.13.4: pub get and strict analyze passed; all 188 non-golden Flutter tests passed.
- `flutter build web --release --base-href /idle/` passed (including the Wasm dry run); output remains in the ignored local build directory, not published.
- 122 Node tests passed, including PvP, bots, skills, API/database protections and scripts.
- Regenerating the Dart skill catalog produces no semantic diff.
- Event RNG boundary tests cover exactly 100 divine outcomes per 1,000 primary tickets, all six fixed Ultra grants, 55/30/15 normal stages and Dren's rate-up branch. Cloud merge and Forge rejection tested.
- Server round integration covers Athena's +3 CRIT blessing, next-round consumption, no round-three reuse and clearing stale blessings at match start.
- Reproducible seed 17, 2,000 duels per god with alternating initiative: Zeus 1,441 wins, Poseidon 928, Hades 875, Athena 809, Ares 1,119, Apollo 879. Zeus remains strongest in this comparison; no balance values changed.

## Release

No production deployment, main merge, database writes or migrations performed.
After PR approval and merge, publish the verified Web build through the normal Pages pipeline and deploy the matching PvP Worker together. The online Worker must recognize Olympus IDs and next-card blessings before players use those cards. No new D1 migration is required by this fix. If Actions remains queued, resolve its external scheduling/account restriction before relying on automatic packaging.
