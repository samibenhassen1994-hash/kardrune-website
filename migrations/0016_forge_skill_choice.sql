-- Additive: old attempts remain final; only explicitly deferred skills are eligible.
CREATE TABLE forge_skill_decisions (
 uid TEXT NOT NULL, request_id TEXT NOT NULL, accept INTEGER NOT NULL CHECK(accept IN (0,1)),
 base_revision INTEGER NOT NULL, created_at INTEGER NOT NULL,
 PRIMARY KEY(uid,request_id), FOREIGN KEY(uid,request_id) REFERENCES forge_attempts(uid,request_id)
);
CREATE TRIGGER forge_pending_guard BEFORE INSERT ON forge_attempts BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM forge_attempts a LEFT JOIN forge_skill_decisions d ON d.uid=a.uid AND d.request_id=a.request_id
 WHERE a.uid=NEW.uid AND json_extract(a.result_json,'$.pendingSkill')=1 AND d.request_id IS NULL) THEN RAISE(ABORT,'FORGE_PENDING') END;
END;
CREATE TRIGGER forge_decision_guard BEFORE INSERT ON forge_skill_decisions BEGIN
 SELECT CASE WHEN COALESCE((SELECT is_banned FROM players WHERE uid=NEW.uid),1)!=0 THEN RAISE(ABORT,'FORGE_BANNED') END;
 SELECT CASE WHEN (SELECT revision FROM demo_saves WHERE uid=NEW.uid) IS NOT NEW.base_revision THEN RAISE(ABORT,'FORGE_CONFLICT') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM forge_attempts WHERE uid=NEW.uid AND request_id=NEW.request_id AND stat='SKILL' AND json_extract(result_json,'$.pendingSkill')=1 AND json_extract(result_json,'$.success')=1) THEN RAISE(ABORT,'FORGE_INVALID') END;
 SELECT CASE WHEN NEW.accept=1 AND NOT EXISTS(SELECT 1 FROM forge_attempts a JOIN skill_grants g ON g.uid=a.uid AND g.card_id=a.card_id
 JOIN demo_saves s ON s.uid=a.uid JOIN json_each(s.save_json,'$.owned') c ON c.value=a.card_id
 WHERE a.uid=NEW.uid AND a.request_id=NEW.request_id AND g.skill_id=json_extract(a.result_json,'$.before.skillId')) THEN RAISE(ABORT,'FORGE_CONFLICT') END;
 SELECT CASE WHEN NEW.accept=1 AND (SELECT json_extract(save_json,'$.pendingDuplicate.rollId') FROM demo_saves WHERE uid=NEW.uid) IS NOT NULL THEN RAISE(ABORT,'FORGE_DUPLICATE') END;
END;
CREATE TRIGGER forge_decision_apply AFTER INSERT ON forge_skill_decisions BEGIN
 UPDATE skill_grants SET
 skill_id=(SELECT json_extract(result_json,'$.proposed.skillId') FROM forge_attempts WHERE uid=NEW.uid AND request_id=NEW.request_id),
 rarity=(SELECT json_extract(result_json,'$.proposed.rarity') FROM forge_attempts WHERE uid=NEW.uid AND request_id=NEW.request_id),updated_at=NEW.created_at
 WHERE NEW.accept=1 AND uid=NEW.uid AND card_id=(SELECT card_id FROM forge_attempts WHERE uid=NEW.uid AND request_id=NEW.request_id);
 UPDATE demo_saves SET save_json=CASE WHEN NEW.accept=1 THEN json_set(save_json,
 '$.skills."'||(SELECT card_id FROM forge_attempts WHERE uid=NEW.uid AND request_id=NEW.request_id)||'"',
 json_object('id',(SELECT json_extract(result_json,'$.proposed.skillId') FROM forge_attempts WHERE uid=NEW.uid AND request_id=NEW.request_id),
 'rarity',(SELECT json_extract(result_json,'$.proposed.rarity') FROM forge_attempts WHERE uid=NEW.uid AND request_id=NEW.request_id),'v',1)) ELSE save_json END,
 revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE uid=NEW.uid;
END;
