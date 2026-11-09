-- Additive only; no starter keys, rewards, purchases, backfill or existing-data rewrite.
CREATE TABLE forge_keys (
 uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
 color TEXT NOT NULL CHECK(color IN ('green','blue','red')),
 quantity INTEGER NOT NULL DEFAULT 0 CHECK(typeof(quantity)='integer' AND quantity>=0),
 PRIMARY KEY(uid,color)
);
CREATE TABLE forge_attempts (
 uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,
 request_id TEXT NOT NULL,
 card_id TEXT NOT NULL,
 color TEXT NOT NULL CHECK(color IN ('green','blue','red')),
 stat TEXT NOT NULL CHECK(stat IN ('ATK','CRT','SKILL')),
 base_revision INTEGER NOT NULL,
 payload TEXT NOT NULL CHECK(json_valid(payload)),
 result_json TEXT NOT NULL CHECK(json_valid(result_json)),
 created_at INTEGER NOT NULL,
 PRIMARY KEY(uid,request_id),
 UNIQUE(uid,base_revision),
 FOREIGN KEY(uid,card_id) REFERENCES skill_grants(uid,card_id)
);
CREATE TRIGGER forge_guard BEFORE INSERT ON forge_attempts BEGIN
 SELECT CASE WHEN COALESCE((SELECT is_banned FROM players WHERE uid=NEW.uid),1)!=0 THEN RAISE(ABORT,'FORGE_BANNED') END;
 SELECT CASE WHEN (SELECT revision FROM demo_saves WHERE uid=NEW.uid) IS NOT NEW.base_revision THEN RAISE(ABORT,'FORGE_CONFLICT') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM demo_saves s,json_each(s.save_json,'$.owned') c WHERE s.uid=NEW.uid AND c.value=NEW.card_id) THEN RAISE(ABORT,'FORGE_CARD') END;
 SELECT CASE WHEN (SELECT json_extract(save_json,'$.pendingDuplicate.rollId') FROM demo_saves WHERE uid=NEW.uid) IS NOT NULL THEN RAISE(ABORT,'FORGE_DUPLICATE') END;
 SELECT CASE WHEN COALESCE((SELECT quantity FROM forge_keys WHERE uid=NEW.uid AND color=NEW.color),0)<1 THEN RAISE(ABORT,'FORGE_KEYS') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM skill_grants WHERE uid=NEW.uid AND card_id=NEW.card_id
 AND attack=json_extract(NEW.result_json,'$.before.attack') AND crit=json_extract(NEW.result_json,'$.before.crit') AND skill_id=json_extract(NEW.result_json,'$.before.skillId')) THEN RAISE(ABORT,'FORGE_CONFLICT') END;
END;
CREATE TRIGGER forge_apply AFTER INSERT ON forge_attempts BEGIN
 UPDATE forge_keys SET quantity=quantity-1 WHERE uid=NEW.uid AND color=NEW.color;
 UPDATE skill_grants SET attack=json_extract(NEW.result_json,'$.after.attack'),crit=json_extract(NEW.result_json,'$.after.crit'),
 skill_id=json_extract(NEW.result_json,'$.after.skillId'),rarity=json_extract(NEW.result_json,'$.after.rarity'),updated_at=NEW.created_at
 WHERE uid=NEW.uid AND card_id=NEW.card_id;
 UPDATE demo_saves SET save_json=CASE NEW.stat
 WHEN 'ATK' THEN json_set(save_json,'$.attacks."'||NEW.card_id||'"',json_extract(NEW.result_json,'$.after.attack'))
 WHEN 'CRT' THEN json_set(save_json,'$.crits."'||NEW.card_id||'"',json_extract(NEW.result_json,'$.after.crit'))
 ELSE json_set(save_json,'$.skills."'||NEW.card_id||'"',json_object('id',json_extract(NEW.result_json,'$.after.skillId'),'rarity',json_extract(NEW.result_json,'$.after.rarity'),'v',1)) END,
 revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE uid=NEW.uid;
END;
