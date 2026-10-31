ALTER TABLE pvp_reward_claims ADD COLUMN claimed_at INTEGER NOT NULL DEFAULT 0;

-- D1 serializes writes, so enforcing limits inside this trigger closes the
-- read/check/write race between concurrent reward requests.
CREATE TRIGGER IF NOT EXISTS pvp_reward_rate_guard
BEFORE INSERT ON pvp_reward_claims
BEGIN
  SELECT CASE WHEN (
    SELECT COUNT(*) FROM pvp_reward_claims c
    WHERE c.uid=NEW.uid AND c.claimed_at>=NEW.claimed_at-86400000
  )>=10 THEN RAISE(ABORT,'pvp reward rate limit: daily') END;

  SELECT CASE WHEN (
    SELECT COUNT(*)
    FROM pvp_reward_claims c
    JOIN pvp_live_history old_match ON old_match.id=c.match_id
    WHERE c.uid=NEW.uid
      AND c.claimed_at>=NEW.claimed_at-86400000
      AND CASE WHEN old_match.player_a=NEW.uid THEN old_match.player_b ELSE old_match.player_a END=(
        SELECT CASE WHEN current_match.player_a=NEW.uid THEN current_match.player_b ELSE current_match.player_a END
        FROM pvp_live_history current_match WHERE current_match.id=NEW.match_id
      )
  )>=3 THEN RAISE(ABORT,'pvp reward rate limit: opponent') END;
END;
