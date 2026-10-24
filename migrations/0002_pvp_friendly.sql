-- Run once in the existing idle-kardrune D1 database after 0001_idle.sql.
-- Friendly PvP ONLY: snapshots derive from untrusted demo saves; no ranked rewards.
CREATE TABLE IF NOT EXISTS pvp_friendly_queue (
 uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE,
 ticket TEXT NOT NULL,
 card_json TEXT NOT NULL,
 joined_at INTEGER NOT NULL,
 match_id TEXT
);
CREATE INDEX IF NOT EXISTS idx_pvp_friendly_waiting ON pvp_friendly_queue(match_id,joined_at);
CREATE TABLE IF NOT EXISTS pvp_friendly_matches (
 id TEXT PRIMARY KEY,
 player_a TEXT NOT NULL REFERENCES players(uid),
 player_b TEXT NOT NULL REFERENCES players(uid),
 card_a_json TEXT NOT NULL,
 card_b_json TEXT NOT NULL,
 replay_json TEXT NOT NULL,
 winner_uid TEXT NOT NULL,
 created_at INTEGER NOT NULL,
 CHECK(player_a <> player_b),
 CHECK(winner_uid = player_a OR winner_uid = player_b)
);
CREATE INDEX IF NOT EXISTS idx_pvp_friendly_player_a ON pvp_friendly_matches(player_a,created_at);
CREATE INDEX IF NOT EXISTS idx_pvp_friendly_player_b ON pvp_friendly_matches(player_b,created_at);
