-- Replace only the rate guard. Existing claims, Shards and match history remain intact.
DROP TRIGGER IF EXISTS pvp_reward_rate_guard;
CREATE TRIGGER pvp_reward_rate_guard
BEFORE INSERT ON pvp_reward_claims
BEGIN
  SELECT CASE WHEN (
    SELECT COUNT(*) FROM pvp_reward_claims c
    WHERE c.uid=NEW.uid AND c.claimed_at>=NEW.claimed_at-86400000
  )>=10 THEN RAISE(ABORT,'pvp reward rate limit: daily') END;
END;
