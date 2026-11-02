import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=(file)=>readFileSync(new URL('../'+file,import.meta.url),'utf8');
test('portal UI does not embed account secrets',()=>{
 const ui=read('account.js');
 assert.match(ui,/\/api\/config/);
 assert.match(ui,/getIdToken\(\)/);
 assert.doesNotMatch(ui,/FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY/);
 assert.match(ui,/textContent/);
 assert.doesNotMatch(ui,/innerHTML/);
});
test('admin UI is not an authorization mechanism',()=>{
 const api=read('functions/api/portal/admin.js');
 assert.match(api,/requireAdmin\(env,actor.uid\)/);
 assert.match(api,/LIMIT \? OFFSET \?/);
 assert.doesNotMatch(api,/save_json/);
 assert.doesNotMatch(api,/user.email/);
});
test('portal account creation uses verified identity',()=>{
 const api=read('functions/api/portal/_lib.js');
 assert.match(api,/userFromRequest\(request,env\)/);
 assert.match(api,/requireActiveAccount\(env,user.uid\)/);
 assert.match(api,/VALUES \(\?\)/);
 assert.match(api,/INSERT INTO website_accounts/);
});
test('profile does not infer Android registration',()=>{
 const api=read('functions/api/portal/profile.js');
 assert.match(api,/verification_not_connected/);
 assert.match(api,/registered:null/);
 assert.match(api,/WHERE uid=\?/);
});
test('auth and admin pages exist',()=>{
 const page=read('account.html');
 for(const item of ['auth-form','dashboard','admin-section','register','logout']) assert.match(page,new RegExp('id="'+item+'"'));
 assert.match(read('index.html'),/href="account.html"/);
});

test('portal and Idle use identical Firebase named app for shared-origin persistence',()=>{
 const portal=read('account.js');
 const idle=read('idle_flutter/lib/services/firebase_auth_service.dart');
 assert.match(portal,/a\.name==='idle-kardrune-cloud'/);
 assert.match(portal,/},'idle-kardrune-cloud'\)/);
 assert.match(idle,/name == 'idle-kardrune-cloud'/);
 assert.match(idle,/Persistence\.LOCAL/);
});
