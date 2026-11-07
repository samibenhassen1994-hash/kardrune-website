-- Rune Clans V1. Apply explicitly; existing player data is never rewritten.
CREATE TABLE idle_clans (
 id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 24),
 name_key TEXT NOT NULL UNIQUE, description TEXT NOT NULL CHECK(length(description)<=160),
 emblem INTEGER NOT NULL CHECK(emblem BETWEEN 0 AND 4),
 owner_uid TEXT NOT NULL REFERENCES players(uid), invite_code TEXT NOT NULL UNIQUE,
 created_at INTEGER NOT NULL
);
CREATE TABLE idle_clan_members (
 uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE,
 clan_id TEXT NOT NULL REFERENCES idle_clans(id) ON DELETE CASCADE,
 joined_at INTEGER NOT NULL
);
CREATE INDEX idle_clan_members_order ON idle_clan_members(clan_id,joined_at,uid);
CREATE TABLE idle_clan_creation_limits (uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE, last_at INTEGER NOT NULL);
CREATE TABLE idle_clan_requests (
 uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
 request_id TEXT NOT NULL, payload TEXT NOT NULL, clan_id TEXT NOT NULL,
 done INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL,
 PRIMARY KEY(uid,request_id)
);
CREATE TRIGGER idle_clan_create_guard BEFORE INSERT ON idle_clans BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM idle_clan_members WHERE uid=NEW.owner_uid)
 THEN RAISE(ABORT,'CLAN_ALREADY_MEMBER') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM idle_clan_creation_limits WHERE uid=NEW.owner_uid AND last_at>NEW.created_at-3600000)
 THEN RAISE(ABORT,'CLAN_CREATE_LIMIT') END;
END;
CREATE TRIGGER idle_clan_create_member AFTER INSERT ON idle_clans BEGIN
 INSERT INTO idle_clan_members VALUES(NEW.owner_uid,NEW.id,NEW.created_at);
 INSERT INTO idle_clan_creation_limits VALUES(NEW.owner_uid,NEW.created_at)
 ON CONFLICT(uid) DO UPDATE SET last_at=excluded.last_at;
END;
CREATE TRIGGER idle_clan_member_left AFTER DELETE ON idle_clan_members BEGIN
 UPDATE idle_clans SET owner_uid=(SELECT uid FROM idle_clan_members WHERE clan_id=OLD.clan_id ORDER BY joined_at,uid LIMIT 1)
 WHERE id=OLD.clan_id AND owner_uid=OLD.uid AND EXISTS(SELECT 1 FROM idle_clan_members WHERE clan_id=OLD.clan_id);
 DELETE FROM idle_clans WHERE id=OLD.clan_id AND NOT EXISTS(SELECT 1 FROM idle_clan_members WHERE clan_id=OLD.clan_id);
END;
