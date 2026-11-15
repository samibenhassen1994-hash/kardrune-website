-- Optional admin-only testing tool. No grants or existing-data changes on install.
CREATE TABLE admin_test_resource_grants (
 uid TEXT NOT NULL REFERENCES players(uid),
 request_id TEXT NOT NULL,
 base_revision INTEGER NOT NULL,
 shards INTEGER NOT NULL CHECK(typeof(shards)='integer' AND shards BETWEEN 0 AND 100000),
 keys_each INTEGER NOT NULL CHECK(typeof(keys_each)='integer' AND keys_each BETWEEN 0 AND 1000),
 created_at INTEGER NOT NULL,
 PRIMARY KEY(uid,request_id),
 CHECK(shards>0 OR keys_each>0)
);
CREATE TRIGGER admin_test_resources_guard BEFORE INSERT ON admin_test_resource_grants BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM player_roles WHERE uid=NEW.uid AND role='admin') THEN RAISE(ABORT,'ADMIN_FORBIDDEN') END;
 SELECT CASE WHEN COALESCE((SELECT is_banned FROM players WHERE uid=NEW.uid),1)!=0 THEN RAISE(ABORT,'ADMIN_FORBIDDEN') END;
 SELECT CASE WHEN (SELECT revision FROM demo_saves WHERE uid=NEW.uid) IS NOT NEW.base_revision THEN RAISE(ABORT,'ADMIN_CONFLICT') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM skill_wallets WHERE uid=NEW.uid) THEN RAISE(ABORT,'ADMIN_NO_WALLET') END;
END;
CREATE TRIGGER admin_test_resources_apply AFTER INSERT ON admin_test_resource_grants BEGIN
 UPDATE skill_wallets SET shards=shards+NEW.shards,updated_at=NEW.created_at WHERE uid=NEW.uid;
 INSERT INTO forge_keys(uid,color,quantity) VALUES(NEW.uid,'green',NEW.keys_each),(NEW.uid,'blue',NEW.keys_each),(NEW.uid,'red',NEW.keys_each)
 ON CONFLICT(uid,color) DO UPDATE SET quantity=forge_keys.quantity+excluded.quantity;
 UPDATE demo_saves SET save_json=json_set(save_json,'$.shards',(SELECT shards FROM skill_wallets WHERE uid=NEW.uid)),revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE uid=NEW.uid;
END;
