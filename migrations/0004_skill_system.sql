-- Server grants are the only skill/stat source accepted by live PvP.
-- Snapshot all existing cards before clients can submit new online saves.
CREATE TABLE IF NOT EXISTS skill_legacy_cards (
  uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
  card_id TEXT NOT NULL,
  PRIMARY KEY(uid,card_id)
);
INSERT OR IGNORE INTO skill_legacy_cards(uid,card_id)
SELECT s.uid,cards.value FROM demo_saves AS s,json_each(s.save_json,'$.owned') AS cards
WHERE cards.type='text';
CREATE TABLE IF NOT EXISTS skill_grants (
  uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
  card_id TEXT NOT NULL,
  attack INTEGER NOT NULL CHECK(attack BETWEEN 1 AND 100),
  crit INTEGER NOT NULL CHECK(crit BETWEEN 0 AND 25),
  skill_id TEXT,
  rarity TEXT,
  skill_version INTEGER NOT NULL DEFAULT 1,
  source TEXT NOT NULL CHECK(source IN ('legacy','initial','summon')),
  roll_id TEXT,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(uid,card_id)
);
INSERT OR IGNORE INTO skill_grants(uid,card_id,attack,crit,skill_id,rarity,skill_version,source,roll_id,updated_at)
SELECT s.uid, cards.value,
  json_extract(s.save_json,'$.attacks."'||cards.value||'"'),
  json_extract(s.save_json,'$.crits."'||cards.value||'"'),
  NULL,NULL,1,'legacy',NULL,unixepoch()*1000
FROM demo_saves AS s, json_each(s.save_json,'$.owned') AS cards
WHERE cards.type='text'
  AND json_extract(s.save_json,'$.attacks."'||cards.value||'"') BETWEEN 1 AND 100
  AND json_extract(s.save_json,'$.crits."'||cards.value||'"') BETWEEN 0 AND 25;
CREATE TABLE IF NOT EXISTS summon_rolls (
  uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
  roll_id TEXT NOT NULL,
  base_revision INTEGER NOT NULL,
  state TEXT NOT NULL CHECK(state IN ('applied','pending','decided')),
  result_json TEXT NOT NULL,
  decision_json TEXT,
  created_at INTEGER NOT NULL,
  PRIMARY KEY(uid,roll_id),
  UNIQUE(uid,base_revision)
);
CREATE INDEX IF NOT EXISTS idx_skill_grants_uid ON skill_grants(uid);
CREATE TABLE IF NOT EXISTS skill_wallets (
  uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE,
  shards INTEGER NOT NULL CHECK(shards BETWEEN 0 AND 999999999),
  updated_at INTEGER NOT NULL
);
INSERT OR IGNORE INTO skill_wallets(uid,shards,updated_at)
SELECT uid,MIN(999999999,MAX(0,CAST(json_extract(save_json,'$.shards') AS INTEGER))),unixepoch()*1000
FROM demo_saves;
CREATE TABLE IF NOT EXISTS practice_rolls (
  uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
  roll_id TEXT NOT NULL,
  base_revision INTEGER NOT NULL,
  result_json TEXT NOT NULL,
  PRIMARY KEY(uid,roll_id),
  UNIQUE(uid,base_revision)
);
CREATE TABLE IF NOT EXISTS practice_daily (
  uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE,
  day TEXT NOT NULL,
  count INTEGER NOT NULL CHECK(count BETWEEN 0 AND 10)
);
INSERT OR IGNORE INTO practice_daily(uid,day,count)
SELECT uid,COALESCE(json_extract(save_json,'$.practiceDaily.day'),''),
  MIN(10,MAX(0,CAST(COALESCE(json_extract(save_json,'$.practiceDaily.count'),0) AS INTEGER)))
FROM demo_saves;
CREATE TRIGGER IF NOT EXISTS summon_roll_revision_guard
BEFORE INSERT ON summon_rolls
BEGIN
  SELECT CASE WHEN (SELECT revision FROM demo_saves WHERE uid=NEW.uid) IS NOT NEW.base_revision
    THEN RAISE(ABORT,'summon revision conflict') END;
  SELECT CASE WHEN COALESCE((SELECT shards FROM skill_wallets WHERE uid=NEW.uid),-1) < json_extract(NEW.result_json,'$.cost')
    THEN RAISE(ABORT,'insufficient verified shards') END;
END;
CREATE TRIGGER IF NOT EXISTS summon_decision_revision_guard
BEFORE UPDATE OF state ON summon_rolls
WHEN NEW.state='decided'
BEGIN
  SELECT CASE WHEN (SELECT revision FROM demo_saves WHERE uid=NEW.uid) IS NOT json_extract(NEW.decision_json,'$.revision')
    THEN RAISE(ABORT,'decision revision conflict') END;
END;
CREATE TRIGGER IF NOT EXISTS practice_roll_revision_guard
BEFORE INSERT ON practice_rolls
BEGIN
  SELECT CASE WHEN (SELECT revision FROM demo_saves WHERE uid=NEW.uid) IS NOT NEW.base_revision
    THEN RAISE(ABORT,'practice revision conflict') END;
END;
ALTER TABLE pvp_live_history ADD COLUMN reason TEXT;
CREATE TABLE IF NOT EXISTS pvp_reward_claims (
  uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
  match_id TEXT NOT NULL REFERENCES pvp_live_history(id),
  base_revision INTEGER NOT NULL,
  response_json TEXT NOT NULL,
  PRIMARY KEY(uid,match_id)
);
CREATE TRIGGER IF NOT EXISTS pvp_reward_revision_guard
BEFORE INSERT ON pvp_reward_claims
BEGIN
  SELECT CASE WHEN (SELECT revision FROM demo_saves WHERE uid=NEW.uid) IS NOT NEW.base_revision
    THEN RAISE(ABORT,'pvp reward revision conflict') END;
END;
