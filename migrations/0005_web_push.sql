-- Extensible opt-in notification transport. No app notification is enabled by default.
CREATE TABLE IF NOT EXISTS push_subscriptions (
  endpoint TEXT PRIMARY KEY,
  uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
  subscription_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_uid ON push_subscriptions(uid);
CREATE TABLE IF NOT EXISTS notification_preferences (
  uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
  topic TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)),
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(uid, topic)
);
CREATE TABLE IF NOT EXISTS notification_events (
  id TEXT PRIMARY KEY,
  uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
  topic TEXT NOT NULL,
  due_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_notification_events_due ON notification_events(due_at, expires_at);
CREATE TABLE IF NOT EXISTS notification_deliveries (
  event_id TEXT NOT NULL REFERENCES notification_events(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL REFERENCES push_subscriptions(endpoint) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK(status IN ('sending','retry','sent','dead')),
  attempts INTEGER NOT NULL DEFAULT 0,
  claimed_until INTEGER NOT NULL DEFAULT 0,
  sent_at INTEGER,
  PRIMARY KEY(event_id, endpoint)
);
-- Generate authoritative reminders from the successful free-roll record.
-- Each free roll restores one charge after 12h. Never trust client-side timers.
CREATE TRIGGER IF NOT EXISTS notification_free_pull_ready
AFTER INSERT ON summon_rolls
WHEN json_extract(NEW.result_json,'$.cost')=0
BEGIN
  INSERT OR IGNORE INTO notification_events(id,uid,topic,due_at,expires_at,created_at)
  VALUES ('free_pull:'||NEW.uid||':'||NEW.roll_id,NEW.uid,'free_pull',
    NEW.created_at+43200000,NEW.created_at+43200000+21600000,NEW.created_at);
END;
-- Backfill only recent free rolls so deploying the feature doesn't spam old players.
INSERT OR IGNORE INTO notification_events(id,uid,topic,due_at,expires_at,created_at)
SELECT 'free_pull:'||uid||':'||roll_id,uid,'free_pull',
  created_at+43200000,created_at+43200000+21600000,created_at
FROM summon_rolls
WHERE created_at > unixepoch()*1000 - 43200000
  AND json_extract(result_json,'$.cost')=0;
