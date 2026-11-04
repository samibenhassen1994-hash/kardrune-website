-- Preparation only: does not activate bots or modify historical results.
-- Requires the existing ranked schema/backfill to be initialized first.
-- Deliberately fails rather than replacing or recalculating historical ranks.
CREATE TABLE IF NOT EXISTS pvp_match_starts (
 match_id TEXT NOT NULL, uid TEXT NOT NULL REFERENCES players(uid),
 points INTEGER NOT NULL CHECK(points>=0), PRIMARY KEY(match_id,uid)
);
CREATE TABLE IF NOT EXISTS pvp_ranked_results (
 match_id TEXT NOT NULL, uid TEXT NOT NULL REFERENCES players(uid),
 human_match_id TEXT REFERENCES pvp_live_history(id),
 bot_match_id TEXT REFERENCES pvp_bot_history(id),
 delta INTEGER NOT NULL, day INTEGER NOT NULL, completed_at INTEGER NOT NULL,
 PRIMARY KEY(match_id,uid),
 CHECK((human_match_id IS NOT NULL)+(bot_match_id IS NOT NULL)=1),
 CHECK(match_id=COALESCE(human_match_id,bot_match_id))
);
-- Bot identifiers deliberately have no FK to players.
CREATE TABLE IF NOT EXISTS pvp_bot_history (
 id TEXT PRIMARY KEY,
 uid TEXT NOT NULL REFERENCES players(uid),
 bot_id TEXT NOT NULL UNIQUE,
 bot_name TEXT NOT NULL,
 player_score INTEGER NOT NULL CHECK(player_score BETWEEN 0 AND 3),
 bot_score INTEGER NOT NULL CHECK(bot_score BETWEEN 0 AND 3),
 outcome TEXT NOT NULL CHECK(outcome IN ('win','loss','draw','void')),
 reason TEXT NOT NULL,
 start_points INTEGER NOT NULL CHECK(start_points>=0),
 completed_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_bot_history_player ON pvp_bot_history(uid,completed_at);
CREATE INDEX IF NOT EXISTS idx_ranked_results_day ON pvp_ranked_results(uid,day,delta);
-- Seed only the ledger; preexisting points remain untouched.
INSERT OR IGNORE INTO pvp_ranked_results
 SELECT match_id,uid,match_id,NULL,25,day,completed_at FROM pvp_ranked_wins;
CREATE TRIGGER IF NOT EXISTS ranked_result_apply AFTER INSERT ON pvp_ranked_results
BEGIN
 INSERT INTO pvp_rankings(uid,wins,points,updated_at)
 VALUES(NEW.uid,CASE WHEN NEW.delta=25 THEN 1 ELSE 0 END,MAX(0,NEW.delta),NEW.completed_at)
 ON CONFLICT(uid) DO UPDATE SET
 wins=wins+CASE WHEN NEW.delta=25 THEN 1 ELSE 0 END,
 points=MAX(0,points+NEW.delta),updated_at=NEW.completed_at;
END;
DROP TRIGGER IF EXISTS ranked_win_increment;
CREATE TRIGGER ranked_win_increment AFTER INSERT ON pvp_ranked_wins
BEGIN
 INSERT OR IGNORE INTO pvp_ranked_results
 VALUES(NEW.match_id,NEW.uid,NEW.match_id,NULL,25,NEW.day,NEW.completed_at);
END;
DROP TRIGGER IF EXISTS ranked_from_verified_match;
CREATE TRIGGER ranked_from_verified_match AFTER INSERT ON pvp_live_history
WHEN NEW.reason IN('completed','opponent_disconnected','replay_timeout') AND NEW.winner_uid IN (NEW.player_a,NEW.player_b) AND NEW.player_a<>NEW.player_b
BEGIN
 INSERT OR IGNORE INTO pvp_ranked_wins(match_id,uid,opponent_uid,day,completed_at)
 SELECT NEW.id,NEW.winner_uid,CASE WHEN NEW.winner_uid=NEW.player_a THEN NEW.player_b ELSE NEW.player_a END,
 CAST(NEW.completed_at/86400000 AS INTEGER),NEW.completed_at
 WHERE NEW.reason='completed' AND (SELECT COUNT(*) FROM pvp_ranked_results WHERE uid=NEW.winner_uid AND day=CAST(NEW.completed_at/86400000 AS INTEGER) AND delta=25)<10
 AND (SELECT COUNT(*) FROM pvp_ranked_wins WHERE uid=NEW.winner_uid AND day=CAST(NEW.completed_at/86400000 AS INTEGER)
 AND opponent_uid=CASE WHEN NEW.winner_uid=NEW.player_a THEN NEW.player_b ELSE NEW.player_a END)<3;
 INSERT OR IGNORE INTO pvp_ranked_results
 SELECT NEW.id,s.uid,NEW.id,NULL,
 CASE WHEN s.points>=900 THEN -20 WHEN s.points>=500 THEN -15 WHEN s.points>=250 THEN -10 WHEN s.points>=100 THEN -5 ELSE 0 END,
 CAST(NEW.completed_at/86400000 AS INTEGER),NEW.completed_at
 FROM pvp_match_starts s WHERE s.match_id=NEW.id AND s.uid IN(NEW.player_a,NEW.player_b) AND s.uid<>NEW.winner_uid;
END;
CREATE TRIGGER IF NOT EXISTS ranked_from_bot_match AFTER INSERT ON pvp_bot_history
WHEN (NEW.reason='completed' AND NEW.outcome IN('win','loss'))
 OR (NEW.reason IN('opponent_disconnected','replay_timeout') AND NEW.outcome='loss')
BEGIN
 INSERT OR IGNORE INTO pvp_ranked_results
 SELECT NEW.id,NEW.uid,NULL,NEW.id,
 CASE WHEN NEW.outcome='win' THEN 25 WHEN NEW.start_points>=900 THEN -20 WHEN NEW.start_points>=500 THEN -15
 WHEN NEW.start_points>=250 THEN -10 WHEN NEW.start_points>=100 THEN -5 ELSE 0 END,
 CAST(NEW.completed_at/86400000 AS INTEGER),NEW.completed_at
 WHERE NEW.outcome='loss' OR (SELECT COUNT(*) FROM pvp_ranked_results WHERE uid=NEW.uid
 AND day=CAST(NEW.completed_at/86400000 AS INTEGER) AND delta=25)<10;
END;

-- Separate FK preserves integrity without inventing a real player or wallet.
CREATE TABLE IF NOT EXISTS pvp_bot_reward_claims (
 uid TEXT NOT NULL REFERENCES players(uid),
 match_id TEXT NOT NULL REFERENCES pvp_bot_history(id),
 base_revision INTEGER NOT NULL,
 response_json TEXT NOT NULL,
 claimed_at INTEGER NOT NULL,
 PRIMARY KEY(uid,match_id)
);
CREATE TRIGGER IF NOT EXISTS bot_reward_guard
BEFORE INSERT ON pvp_bot_reward_claims
BEGIN
 SELECT CASE WHEN NOT EXISTS (
  SELECT 1 FROM pvp_bot_history WHERE id=NEW.match_id AND uid=NEW.uid
  AND outcome='win' AND reason='completed'
 ) THEN RAISE(ABORT,'ineligible bot reward') END;
 SELECT CASE WHEN (SELECT revision FROM demo_saves WHERE uid=NEW.uid) IS NOT NEW.base_revision
  THEN RAISE(ABORT,'pvp reward revision conflict') END;
 SELECT CASE WHEN (
  (SELECT COUNT(*) FROM pvp_reward_claims WHERE uid=NEW.uid AND claimed_at>=NEW.claimed_at-86400000)+
  (SELECT COUNT(*) FROM pvp_bot_reward_claims WHERE uid=NEW.uid AND claimed_at>=NEW.claimed_at-86400000)
 )>=10 THEN RAISE(ABORT,'pvp reward rate limit: daily') END;
END;
CREATE TRIGGER IF NOT EXISTS human_reward_shared_quota_guard
BEFORE INSERT ON pvp_reward_claims
BEGIN
 SELECT CASE WHEN (
  (SELECT COUNT(*) FROM pvp_reward_claims WHERE uid=NEW.uid AND claimed_at>=NEW.claimed_at-86400000)+
  (SELECT COUNT(*) FROM pvp_bot_reward_claims WHERE uid=NEW.uid AND claimed_at>=NEW.claimed_at-86400000)
 )>=10 THEN RAISE(ABORT,'pvp reward rate limit: daily') END;
END;
INSERT OR REPLACE INTO pvp_ranked_meta(key,value) VALUES('bot_results_v1','ready');
