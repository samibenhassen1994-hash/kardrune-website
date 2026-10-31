# PvP Initiative, UI Motion, Balance and Security Design

## Intent

Add requested interaction polish without redesigning the game, make live PvP initiative and rewards server-authoritative, then harden competitive/economic state and apply stage-specific effective stat limits without deleting historical progress.

## Confirmed behavior

- The Summon content panel enters from below when the section opens.
- Deck Builder offers an Auto Deck action that selects up to nine owned cards by highest effective attack, with deterministic tie-breaking.
- Every skill has a recognizable animation identity derived from its existing `vfx` family plus skill-specific color/motion/text treatment; skill rules do not change.
- Only the live-match winner receives 100 Shards. Draws and losers receive zero. Ranked rewards remain disabled.
- Both players see a dice intro. The server generates both rolls, resolves ties, and declares the authoritative Round 1 starter.
- Direct attacks alternate within every duel. The round starter alternates each round: winner of the dice starts Round 1, the other player starts Round 2, and the dice winner starts Round 3.
- The dice sprite is reused from `Idlekardrune-assets/assets/dice_comparison/kr_v2`; no client-provided roll influences the result.

## Balance and security follow-up

- Stage 1 effective range: ATK 25–50, CRIT 0–8%.
- Stage 2 effective range: ATK 40–75, CRIT 4–16%.
- Stage 3 effective range: ATK 60–100, CRIT 8–25%.
- New Summon grants are generated inside the range. Existing stored values are preserved but clamped at every gameplay/server boundary.
- Flutter and server share equivalent centralized bounds and tests.
- `/api/save` cannot modify competitive/economic authority; PvP rewards are winner-only, idempotent and rate/farming protected; banned accounts cannot call economic endpoints.

## Approaches

1. Client-only presentation and clamping: rejected because it is bypassable and contradicts server authority.
2. Rewrite historical saves and grants: rejected because it risks data loss and destroys historical values.
3. Preserve raw history, apply centralized effective bounds at generation and every trusted boundary: selected because it is compatible, enforceable and reversible.

## Constraints

- No economy, HP, skill, Summon probability or cost changes beyond the explicitly requested winner reward and stat ranges.
- Firebase/D1 compatibility stays intact.
- First delivery is pushed to `main`; balance/security work is pushed to a new branch without merge or deployment.

