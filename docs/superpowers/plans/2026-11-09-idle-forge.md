# Idle Forge Implementation Plan

Goal: authenticated, persistent forge with server RNG and supplied assets; branch only, no production migration/deploy.
Architecture: existing Firebase auth, D1 skill_grants as authority, additive inventory/attempt receipts and guarded SQLite triggers for atomic key debit + stat mutation + save revision. Existing combat and save merge read these grants; no alternate card system.

- [ ] Backend: pure rules with existing caps/skill weights, additive 0015 migration, idempotent API, SQL/concurrency tests.
- [ ] Flutter: Forge navigation, supplied video/keys, tap and drag slots, server inventory/cards, retry-safe request ID, authoritative save application, seven languages.
- [ ] Validation: targeted Flutter, Node and SQLite tests, analyzer, release build; commits + draft PR, no main merge.

Approved increments: ATK +1–5, CRT +1–2 percentage points; truncate at remaining cap, reject at cap before consumption. No keys are granted or sold. No RED-ARCO ID exists; use catalog rarities, including ultra as the rarest. Stage cards are separate IDs and no existing evolution API exists: do not invent cross-stage transfer. Grants and attempt audit remain stored per owned card permanently.
