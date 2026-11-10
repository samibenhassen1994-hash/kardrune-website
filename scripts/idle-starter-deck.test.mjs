import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {STARTER_IDS,starterAdditions,starterSave,ensureStarterCards,fillDeck} from '../functions/api/_lib/starter_deck.js';
function fixture(){
 const db=new DatabaseSync(':memory:');db.exec(`PRAGMA foreign_keys=ON;CREATE TABLE players(uid TEXT PRIMARY KEY);INSERT INTO players VALUES('u');
 CREATE TABLE demo_saves(uid TEXT PRIMARY KEY REFERENCES players(uid),save_json TEXT,revision INTEGER,updated_at TEXT);
 CREATE TABLE skill_grants(uid TEXT REFERENCES players(uid),card_id TEXT,attack INTEGER,crit INTEGER,skill_id TEXT,rarity TEXT,skill_version INTEGER,source TEXT,roll_id TEXT,updated_at INTEGER,PRIMARY KEY(uid,card_id));`);
 const adapter={prepare(q){let args=[];return{bind(...a){args=a;return this},async first(){return db.prepare(q).get(...args)||null},async all(){return {results:db.prepare(q).all(...args)}},async run(){const r=db.prepare(q).run(...args);return {meta:{changes:r.changes}}}}},async batch(stmts){const out=[];db.exec('BEGIN');try{for(const stmt of stmts)out.push(await stmt.run());db.exec('COMMIT')}catch(e){db.exec('ROLLBACK');throw e}return out}};
 return {db,env:{DB:adapter}};
}
const empty={owned:[],attacks:{},crits:{},skills:{},shards:1500};
test('fresh player gets nine persistent Stage 1 grants and deck',()=>{
 const {db}=fixture(),grants=starterAdditions(empty,[],()=>0),save=starterSave(empty,grants,[]);
 assert.deepEqual(grants.map(g=>g.card_id),STARTER_IDS);
 assert.ok(grants.every(g=>g.attack===25&&g.crit===0&&g.skill_id==='C1'&&g.rarity==='common'));
 db.prepare('INSERT INTO demo_saves VALUES(?,?,1,NULL)').run('u',JSON.stringify(save));
 for(const g of grants)db.prepare('INSERT INTO skill_grants VALUES(?,?,?,?,?,?,?,?,?,?)').run('u',g.card_id,g.attack,g.crit,g.skill_id,g.rarity,1,'initial',null,0);
 assert.equal(db.prepare('SELECT COUNT(*) n FROM skill_grants').get().n,9);
 assert.deepEqual(fillDeck([],save,grants),STARTER_IDS);
 assert.deepEqual(db.prepare('PRAGMA foreign_key_check').all(),[]);db.close();
});
test('existing owner retains verified stats; only missing Stage 1 cards added once',async()=>{
 const {db,env}=fixture();const save={...empty,owned:['sam:1'],attacks:{'sam:1':49},crits:{'sam:1':7},skills:{'sam:1':{id:'C2',rarity:'common',v:1}}};
 db.prepare('INSERT INTO demo_saves VALUES(?,?,1,NULL)').run('u',JSON.stringify(save));
 db.prepare('INSERT INTO skill_grants VALUES(?,?,?,?,?,?,?,?,?,?)').run('u','sam:1',49,7,'C2','common',1,'initial',null,0);
 const first=await ensureStarterCards(env,'u',{save_json:JSON.stringify(save),revision:1},[{card_id:'sam:1',attack:49,crit:7,skill_id:'C2',rarity:'common',skill_version:1}]);
 assert.equal(first.row.revision,2);assert.equal(db.prepare('SELECT COUNT(*) n FROM skill_grants').get().n,9);
 const after=JSON.parse(db.prepare('SELECT save_json FROM demo_saves').get().save_json);
 assert.equal(after.attacks['sam:1'],49);assert.equal(after.crits['sam:1'],7);assert.equal(after.owned.length,9);
 assert.deepEqual(fillDeck(['sam:1'],after,first.grants),STARTER_IDS);
 await ensureStarterCards(env,'u',first.row,first.grants);
 assert.equal(db.prepare('SELECT COUNT(*) n FROM skill_grants').get().n,9);
 assert.equal(db.prepare('SELECT revision FROM demo_saves').get().revision,2);
 assert.deepEqual(db.prepare('PRAGMA foreign_key_check').all(),[]);db.close();
});
test('an existing nine-card collection is not granted extra cards',()=>{
 const owned=['sam:1','lira:1','rhea:1','dren:1','tor:1','aria:2','kael:2','neris:2','nyra:2'];
 const grants=owned.map(card_id=>({card_id}));
 assert.deepEqual(starterAdditions({...empty,owned},grants),[]);
 assert.deepEqual(fillDeck([], {...empty,owned},grants),owned);
});
