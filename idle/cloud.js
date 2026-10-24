/* Optional cloud login and intentionally manual demo backup. No competitive entitlement. */
(function(root){
'use strict';
const $=id=>document.getElementById(id);
let auth=null,currentUser=null,remoteRevision=0,currentRemote=null,authApi=null;
let getLocal=()=>null,applyLocal=()=>{},status=()=>{};
let syncing=false,queued=false,autoEnabled=false,knownSnapshot=null,accountEpoch=0,autoTimer=null;
const snapshot=()=>JSON.stringify(getLocal());
const linkKey=uid=>'idle-cloud-sync-v1:'+uid;
function readLink(uid){try{return JSON.parse(localStorage.getItem(linkKey(uid)))}catch{return null}}
function writeLink(uid,rev,snap){try{localStorage.setItem(linkKey(uid),JSON.stringify({revision:rev,snapshot:snap,enabled:true}))}catch{}}
function autoStatus(text){$('cloud-auto-status').textContent=text}
function stopAuto(){autoEnabled=false;queued=false;clearTimeout(autoTimer);$('cloud-autosave-toggle').textContent='Enable automatic backup'}
function schedule(){if(!autoEnabled||!currentUser)return;queued=true;clearTimeout(autoTimer);autoTimer=setTimeout(syncOnce,1100)}
const sdk='https://www.gstatic.com/firebasejs/10.14.1/';
function message(text){$('cloud-message').textContent=text}
function available(enabled){
 $('cloud-auth-form').hidden=!enabled;
 $('cloud-disabled').hidden=enabled;
}
async function request(path,method='GET',payload){
 if(!currentUser)throw Error('Sign in first');
 const token=await currentUser.getIdToken();
 const response=await fetch('/api/'+path,{method,headers:{'authorization':'Bearer '+token,...(payload?{'content-type':'application/json'}:{})},body:payload?JSON.stringify(payload):undefined,cache:'no-store'});
 const result=await response.json().catch(()=>({error:'Invalid response'}));
 if(!response.ok)throw Error(result.error||'Cloud request failed ('+response.status+')');
 return result;
}
async function refresh(){
 if(!currentUser)return;
 const [me,data]=await Promise.all([request('me'),request('save')]);
 currentRemote=data.save;remoteRevision=data.revision;
 $('cloud-identity').textContent=me.player.display_name+' · '+(currentUser.email||'Google');
 $('cloud-signed-in').hidden=false;$('cloud-auth-form').hidden=true;
 $('cloud-save-info').textContent=currentRemote?'Cloud backup available · revision '+remoteRevision:'No cloud save yet';
 status('Signed in');
 const link=readLink(currentUser.uid),local=snapshot(),remote=currentRemote===null?null:JSON.stringify(currentRemote);
 const decision=root.IDLE_CLOUD_SYNC.decide(local,remote,remoteRevision,link);
 stopAuto();
 if(link?.enabled&&['synced','upload','download','adopt'].includes(decision)){
  if(decision==='download'){
   autoStatus('Newer cloud data available. Load it manually to avoid overwriting local play.');
  }else{
   autoEnabled=true;
   knownSnapshot=decision==='adopt'?local:link.snapshot;
   $('cloud-autosave-toggle').textContent='Disable automatic backup';
   autoStatus('Automatic backup enabled');
   if(decision==='upload')schedule();
   if(decision==='adopt')writeLink(currentUser.uid,remoteRevision,local);
  }
 }else autoStatus('Automatic backup off · review local/cloud saves first.');
 if(me.role==='admin'){
  $('cloud-admin').hidden=false;
  $('cloud-admin').onclick=async()=>{
   try{const data=await request('admin/status');message('ADMIN · Players: '+data.players+' · Saves: '+data.demoSaves+' · Matches: '+data.pvpMatches+' · Tournaments: '+data.tournaments)}catch(e){message(e.message)}
  };
 }else $('cloud-admin').hidden=true;
}
async function run(fn){try{message('');await fn()}catch(error){message(error?.message||'Authentication failed')}}
async function init({getSave,setSave,onState}={}){
 getLocal=getSave||getLocal;applyLocal=setSave||applyLocal;status=onState||status;
 let config;
 try{const res=await fetch('/api/config',{cache:'no-store'});if(!res.ok)throw Error('API unavailable');config=await res.json()}catch{available(false);return}
 if(!config?.enabled){available(false);return}
 try{
  const [{initializeApp},{getAuth,GoogleAuthProvider,signInWithPopup,signInWithRedirect,signInWithEmailAndPassword,createUserWithEmailAndPassword,signOut,onAuthStateChanged}]=await Promise.all([
   import(sdk+'firebase-app.js'),import(sdk+'firebase-auth.js')]);
  const app=initializeApp(config.firebase,'idle-kardrune-cloud');
  auth=getAuth(app);
  authApi={GoogleAuthProvider,signInWithPopup,signInWithRedirect,signInWithEmailAndPassword,createUserWithEmailAndPassword,signOut};
  available(true);
  onAuthStateChanged(auth,async user=>{
   accountEpoch++;stopAuto();currentUser=user;currentRemote=null;remoteRevision=0;
   if(!user){$('cloud-signed-in').hidden=true;$('cloud-auth-form').hidden=false;status('Local');return}
   await run(refresh);
  });
 }catch(e){available(false);message('Cloud login unavailable: '+e.message)}
}
async function syncOnce(){
 if(!autoEnabled||!currentUser||syncing||!queued)return;
 syncing=true;queued=false;
 const uid=currentUser.uid,epoch=accountEpoch;
 const next=snapshot();
 const link=readLink(uid);
 if(!link||link.revision!==remoteRevision){stopAuto();autoStatus('Revision changed. Manual review needed.');syncing=false;return}
 if(next===link.snapshot){syncing=false;return}
 try{
  const result=await request('save','PUT',{save:getLocal(),revision:remoteRevision});
  if(epoch!==accountEpoch||uid!==currentUser?.uid)return;
  remoteRevision=result.revision;knownSnapshot=next;writeLink(uid,remoteRevision,next);
  $('cloud-save-info').textContent='Cloud backup available · revision '+remoteRevision;
  autoStatus('Saved automatically · revision '+remoteRevision);
 }catch(e){
  if(epoch!==accountEpoch)return;
  stopAuto();autoStatus(e.message.includes('conflict')?'Cloud save changed on another device. Review and load it manually.':'Backup paused: '+e.message);
 }finally{syncing=false;if(queued&&autoEnabled)schedule()}
}
function onLocalChange(){schedule()}
function actions(){
 $('cloud-google').addEventListener('click',()=>run(async()=>{
  const provider=new authApi.GoogleAuthProvider();
  try{await authApi.signInWithPopup(auth,provider)}
  catch(e){if(e.code==='auth/popup-blocked'||e.code==='auth/operation-not-supported-in-this-environment')await authApi.signInWithRedirect(auth,provider);else throw e}
 }));
 $('cloud-email-form').addEventListener('submit',e=>{
  e.preventDefault();run(async()=>{
   const email=$('cloud-email').value.trim(),password=$('cloud-password').value;
   if(password.length<6)throw Error('Password must be at least 6 characters');
   if($('cloud-email-mode').value==='register')await authApi.createUserWithEmailAndPassword(auth,email,password);
   else await authApi.signInWithEmailAndPassword(auth,email,password);
  });
 });
 $('cloud-sign-out').addEventListener('click',()=>run(()=>authApi.signOut(auth)));
 $('cloud-autosave-toggle').addEventListener('click',()=>run(async()=>{
  if(!currentUser)return;
  if(autoEnabled){stopAuto();autoStatus('Automatic backup disabled');try{localStorage.removeItem(linkKey(currentUser.uid))}catch{}return}
  const local=snapshot(),remote=currentRemote===null?null:JSON.stringify(currentRemote);
  if(remote===null){autoStatus('Upload your first local save to initialize automatic backup.');return}
  if(local!==remote){autoStatus('Local and cloud saves differ. Use Upload or Load first, then enable backup.');return}
  knownSnapshot=local;writeLink(currentUser.uid,remoteRevision,local);autoEnabled=true;
  $('cloud-autosave-toggle').textContent='Disable automatic backup';autoStatus('Automatic backup enabled');
 }));
 $('cloud-upload').addEventListener('click',()=>run(async()=>{
  if(!confirm('Upload local demo progress to this account? This replaces the current cloud backup if the revision matches.'))return;
  const result=await request('save','PUT',{save:getLocal(),revision:remoteRevision});
  remoteRevision=result.revision;currentRemote=getLocal();
  message('Demo saved to cloud (not eligible for ranked PvP).');await refresh();
 }));
 $('cloud-download').addEventListener('click',()=>run(async()=>{
  const result=await request('save');if(!result.save)throw Error('No cloud backup available');
  if(!confirm('Replace local demo progress with cloud backup? Local unsynced changes will be lost.'))return;
  applyLocal(result.save);
  message('Cloud demo backup loaded.');await refresh();
 }));
}
root.IDLE_CLOUD={init,actions,onLocalChange};
})(window);
