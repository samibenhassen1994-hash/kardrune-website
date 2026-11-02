-- Website registration identity shares Firebase UID and Cloudflare D1 with Idle.
-- Existing players are referenced by UID. No unverified self-service game links.
CREATE TABLE IF NOT EXISTS website_accounts (
  uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE,
  joined_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
