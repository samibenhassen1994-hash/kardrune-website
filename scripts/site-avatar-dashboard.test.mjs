import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=(p)=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const pages=['index.html','conquest.html','story.html','idle.html','playground.html','dice-roller.html','gacha-calculator.html','card-creator.html','loot-generator.html','battle-simulator.html','heroes-wiki.html','account.html'];
test('account avatar entry point is present on all site pages',()=>{
  for(const page of pages){
    assert.match(read(page),/src="site-account-nav\.js"/,page);
  }
});
test('shared Firebase session is reused without creating a second user',()=>{
  const nav=read('site-account-nav.js');
  assert.match(nav,/idle-kardrune-cloud/);
  assert.match(nav,/onAuthStateChanged/);
  assert.match(nav,/host\.href = 'account\.html'/);
  assert.doesNotMatch(nav,/createUserWithEmailAndPassword|signInAnonymously/);
});
test('regular player overview stays owner-scoped',()=>{
  const profile=read('functions/api/portal/profile.js');
  assert.match(profile,/portalUser\(request,env,\{register:true\}\)/);
  assert.match(profile,/WHERE player_a=\? OR player_b=\?/);
  assert.match(profile,/bind\(user\.uid,user\.uid\)/);
  assert.match(profile,/verification_not_connected/);
});
test('player dashboard uses safe DOM text and original Idle link',()=>{
  const js=read('account.js');
  const html=read('account.html');
  assert.match(js,/showPlayerInsights\(data\)/);
  assert.match(js,/\.textContent=/);
  assert.doesNotMatch(js,/innerHTML/);
  assert.match(html,/id="player-insight-stats"/);
  assert.match(html,/id="recent-matches"/);
  assert.match(js,/https:\/\/kardrune\.com\/idle\//);
});
