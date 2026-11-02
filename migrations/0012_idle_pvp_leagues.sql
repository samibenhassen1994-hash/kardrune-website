-- Idle PvP ranking. Only the live server writes match history.
-- League rewards are claimed once per Firebase UID and threshold.
CREATE TABLE IF NOT EXISTS pvp_league_claims (
 uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
 league TEXT NOT NULL,
 points_at_claim INTEGER NOT NULL,
 expected_revision INTEGER NOT NULL,
 shards INTEGER NOT NULL CHECK(shards > 0),
 claimed_at INTEGER NOT NULL,
 PRIMARY KEY(uid,league)
);
CREATE INDEX IF NOT EXISTS idx_pvp_live_winner_ranked ON pvp_live_history(winner_uid,completed_at);

CREATE TRIGGER IF NOT EXISTS pvp_league_revision_guard
BEFORE INSERT ON pvp_league_claims
WHEN (SELECT revision FROM demo_saves WHERE uid=NEW.uid) IS NOT NEW.expected_revision
BEGIN
 SELECT RAISE(ABORT,'league revision conflict');
END;
