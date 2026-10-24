-- Apply once to the existing idle-kardrune D1 database.
-- Decks are for friendly testing only; never grant ranked rewards based on demo data.
CREATE TABLE IF NOT EXISTS pvp_decks (
  uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE,
  cards_json TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS pvp_live_tickets (
  uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE,
  ticket TEXT NOT NULL UNIQUE,
  expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_live_tickets_expires ON pvp_live_tickets(expires_at);
CREATE TABLE IF NOT EXISTS pvp_live_history (
  id TEXT PRIMARY KEY,
  player_a TEXT NOT NULL REFERENCES players(uid),
  player_b TEXT NOT NULL REFERENCES players(uid),
  score_a INTEGER NOT NULL,
  score_b INTEGER NOT NULL,
  winner_uid TEXT,
  completed_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_live_history_player_a ON pvp_live_history(player_a,completed_at);
CREATE INDEX IF NOT EXISTS idx_live_history_player_b ON pvp_live_history(player_b,completed_at);
