import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {LEAGUES,rankProgress,isRankedResult} from '../functions/api/_lib/ranked_leagues.js';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
test('six monotonic leagues with defined milestone rewards',()=>{
 assert.deepEqual(LEAGUES.map(l=>l.points),[0,100,250,500,900,1500]);
 assert.deepEqual(LEAGUES.map(l=>l.reward),[0,150,300,500,850,1500]);
 assert.equal(rankProgress(0).league,'Bronze');
 assert.equal(rankProgress(99).remaining,1);
 assert.equal(rankProgress(100).league,'Silver');
 assert.equal(rankProgress(1499).league,'Diamond');
 assert.equal(rankProgress(1500).next,null);
});
test('ranked scores count completed real victories only',()=>{
 const base={player_a:'a',player_b:'b',winner_uid:'a',reason:'completed'};
 assert.equal(isRankedResult(base,'a'),true);
 assert.equal(isRankedResult(base,'b'),false);
 assert.equal(isRankedResult({...base,reason:'opponent_disconnected'},'a'),false);
 assert.equal(isRankedResult({...base,reason:'replay_timeout'},'a'),false);
 assert.equal(isRankedResult({...base,player_b:'a'},'a'),false);
});
test('points come from server history only and rewards require revision',()=>{
 const db=read('functions/api/_lib/ranked_store.js');
 const claim=read('functions/api/pvp/league-claim.js');
 const migration=read('migrations/0012_idle_pvp_leagues.sql');
 assert.match(db,/reason='completed'/);
 assert.match(db,/opponent_n<=3/);
 assert.match(db,/daily_n<=10/);
 assert.match(db,/pvp_live_history/);
 assert.match(claim,/userFromRequest/);
 assert.match(claim,/expected_revision/);
 assert.match(migration,/PRIMARY KEY\(uid,league\)/);
 assert.match(migration,/pvp_league_revision_guard/);
});
