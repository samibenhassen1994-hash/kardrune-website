CREATE TABLE IF NOT EXISTS mobile_auth_handoffs (
  code_hash TEXT PRIMARY KEY,
  uid TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_mobile_auth_handoffs_expiry
  ON mobile_auth_handoffs(expires_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_mobile_auth_handoffs_uid
  ON mobile_auth_handoffs(uid);
CREATE UNIQUE INDEX IF NOT EXISTS idx_mobile_auth_handoffs_uid
  ON mobile_auth_handoffs(uid);
