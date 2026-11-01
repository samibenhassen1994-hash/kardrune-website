-- Also created automatically by /api/me and /api/name for existing deployments.
-- One row per Firebase UID: after the first choice it cannot be changed by clients.
CREATE TABLE IF NOT EXISTS player_name_choices (
 uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE,
 name TEXT NOT NULL,
 chosen_at INTEGER NOT NULL
);
