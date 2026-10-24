/* Automatic account-backed demo sync. Competitive inventory remains server-only. */
(function(root){
'use strict';
const $=id=>document.getElementById(id);
const sdk='https://www.gstatic.com/firebasejs/10.14.1/';
const NORMAL_DELAY_MS=5000, IMPORTANT_DELAY_MS=250;
const LAST_USER_KEY='idle-cloud-last-user-v1';
const linkKey=uid=>'idle-cloud-sync-v1:'+uid;
let auth=null,authApi=null,currentUser=null,remoteRevision=0,currentRemote=null;
let getLocal=()=>null,applyLocal=()=>{},status=()=>{};
let accountEpoch=0,syncing=false,queued=false,queuedPriority='normal',autoEnabled=false,autoTimer=null,retryCount=0;
const snapshot=()=>JSON.stringify(getLocal());
function readLink(uid){try{return JSON.parse(localStorage.getItem(linkKey(uid)))}catch{return null}}
function writeLink(uid,revision,data){try{localStorage.setItem(linkKey(uid),JSON.stringify({revision,snapshot:data,enabled:true}))}catch{}}
function lastUser(){try{return localStorage.getItem(LAST_USER_KEY)}catch{return null}}
function rememberUser(uid){try{localStorage.setItem(LAST_USER_KEY,uid)}catch{}}
function autoStatus(value,warning=false){
 const el=$('cloud-auto-status');el.textContent=value;el.classList.toggle('cloud-sync-warning',warning);
}
function message(value){$('cloud-message').textContent=value}
function available(enabled){$('cloud-auth-form').hidden=!enabled;$('cloud-disabled').hidden=enabled}
function stopAuto(){autoEnabled=false;queued=false;queuedPriority='normal';clearTimeout(autoTimer);autoTimer=null;retryCount=0}
function schedule(priority='normal'){
 if(!autoEnabled||!currentUser)return;
 queued=true;
 if(priority==='important')queuedPriority='important';
 clearTimeout(autoTimer);
 autoTimer=setTimeout(syncOnce,queuedPriority==='important'?IMPORTANT_DELAY_MS:NORMAL_DELAY_MS);
}
function accountCheck(uid,epoch){return currentUser?.uid===uid&&accountEpoch===epoch}
async function request(path,method='GET',payload){
 if(!currentUser)throw Error('Sign in first');
 const token=await currentUser.getIdToken();
 const response=await fetch('/api/'+path,{
  method,headers:{authorization:'Bearer '+token,...(payload?{'content-type':'application/json'}:{})},
  body:payload?JSON.stringify(payload):undefined,cache:'no-store'
 });
 const result=await response.json().catch(()=>({error:'Invalid response'}));
 if(!response.ok){const error=new Error(result.error||'Cloud request failed ('+response.status+')');error.status=response.status;throw error}
 return result;
}
function activate(uid,revision,data,info){
 writeLink(uid,revision,data);autoEnabled=true;retryCount=0;
 autoStatus(info||'Automatic backup active');
}
function review(info){
 stopAuto();autoStatus(info,true);message('Choose Upload local save or Load cloud save to resolve the difference.');
}
async function refresh(){
 if(!currentUser)return;
 const uid=currentUser.uid,epoch=accountEpoch;
 const previousUid=lastUser();
 const [me,data]=await Promise.all([request('me'),request('save')]);
 if(!accountCheck(uid,epoch))return;
 currentRemote=data.save;remoteRevision=data.revision;
 $('cloud-identity').textContent=me.player.display_name+' · '+(currentUser.email||'Google');
 $('cloud-signed-in').hidden=false;$('cloud-auth-form').hidden=true;
 $('cloud-save-info').textContent=currentRemote?'Cloud backup available · revision '+remoteRevision:'No cloud save yet';
 status('Signed in');
 root.IDLE_PVP?.setSession({uid},request);
 stopAuto();
 const local=snapshot(),remote=currentRemote===null?null:JSON.stringify(currentRemote);
 const link=readLink(uid);
 const switchedAccount=previousUid&&previousUid!==uid;
 if(currentRemote===null&&remoteRevision===0){
  if(switchedAccount||link?.revision>0){
   review('No cloud save for this account. Review before importing this device’s progress.');
  }else{
   activate(uid,0,local,'Creating your first automatic backup…');
   schedule('important');
  }
 }else if(switchedAccount&&!link){
  review('Different account on this device. Choose which progress to keep.');
 }else{
  const decision=root.IDLE_CLOUD_SYNC.decide(local,remote,remoteRevision,link);
  if(decision==='adopt'||decision==='synced'){
   activate(uid,remoteRevision,local,'Automatic backup active · revision '+remoteRevision);
  }else if(decision==='upload'){
   autoEnabled=true;
   autoStatus('Syncing changes from this device…');
   schedule();
  }else if(decision==='download'){
   review('Newer cloud progress found. Load it to continue syncing safely.');
  }else{
   review('Local and cloud progress differ. Choose Upload or Load to continue.');
  }
 }
 rememberUser(uid);
 if(me.role==='admin'){
  $('cloud-admin').hidden=false;
  $('cloud-admin').onclick=async()=>{
   try{const summary=await request('admin/status');message('ADMIN · Players: '+summary.players+' · Saves: '+summary.demoSaves+' · Matches: '+summary.pvpMatches+' · Tournaments: '+summary.tournaments)}
   catch(e){message(e.message)}
  };
 }else $('cloud-admin').hidden=true;
}
async function run(fn){try{message('');await fn()}catch(error){message(error?.message||'Authentication failed')}}
async function init({getSave,setSave,onState}={}){
 getLocal=getSave||getLocal;applyLocal=setSave||applyLocal;status=onState||status;
 let config;
 try{const res=await fetch('/api/config',{cache:'no-store'});if(!res.ok)throw Error('API unavailable');config=await res.json()}
 catch{available(false);return}
 if(!config?.enabled){available(false);return}
 try{
  const [{initializeApp},{getAuth,GoogleAuthProvider,signInWithPopup,signInWithRedirect,signInWithEmailAndPassword,createUserWithEmailAndPassword,signOut,onAuthStateChanged}]=await Promise.all([
   import(sdk+'firebase-app.js'),import(sdk+'firebase-auth.js')
  ]);
  const app=initializeApp(config.firebase,'idle-kardrune-cloud');
  auth=getAuth(app);
  authApi={GoogleAuthProvider,signInWithPopup,signInWithRedirect,signInWithEmailAndPassword,createUserWithEmailAndPassword,signOut};
  available(true);
  onAuthStateChanged(auth,async user=>{
   accountEpoch++;stopAuto();
   currentUser=user;currentRemote=null;remoteRevision=0;
   if(!user){
    $('cloud-signed-in').hidden=true;$('cloud-auth-form').hidden=false;$('cloud-admin').hidden=true;
    status('Local');root.IDLE_PVP?.setSession(null,null);return;
   }
   await run(refresh);
  });
 }catch(e){available(false);message('Cloud login unavailable: '+e.message)}
}
async function syncOnce(){
 if(!autoEnabled||!currentUser||syncing||!queued)return;
 syncing=true;queued=false;queuedPriority='normal';
 const uid=currentUser.uid,epoch=accountEpoch;
 const localSave=getLocal(),next=JSON.stringify(localSave);
 const link=readLink(uid);
 if(!link||link.revision!==remoteRevision){
  syncing=false;review('Cloud revision changed. Review saves before continuing.');return;
 }
 if(next===link.snapshot){syncing=false;return}
 try{
  const result=await request('save','PUT',{save:localSave,revision:remoteRevision});
  if(!accountCheck(uid,epoch))return;
  remoteRevision=result.revision;currentRemote=localSave;
  writeLink(uid,remoteRevision,next);retryCount=0;
  $('cloud-save-info').textContent='Cloud backup available · revision '+remoteRevision;
  autoStatus('Saved automatically · revision '+remoteRevision);
 }catch(e){
  if(!accountCheck(uid,epoch))return;
  if(e.status===409){review('Cloud progress changed on another device. Load or upload manually.')}
  else{
   retryCount=Math.min(retryCount+1,5);
   autoStatus('Cloud temporarily unavailable. Local save is safe; retrying…',true);
   queued=true;
   clearTimeout(autoTimer);
   autoTimer=setTimeout(syncOnce,Math.min(120000,15000*Math.pow(2,retryCount-1)));
  }
 }finally{
  syncing=false;
  if(queued&&autoEnabled&&retryCount===0)schedule(queuedPriority);
 }
}
function onLocalChange(priority='normal'){schedule(priority)}
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
 $('cloud-sign-out').addEventListener('click',()=>run(async()=>{
  if(currentUser&&autoEnabled){
   const link=readLink(currentUser.uid);
   if(link?.snapshot!==snapshot()){
    queued=true;clearTimeout(autoTimer);
    if(!syncing)await syncOnce();
   }
  }
  await authApi.signOut(auth);
 }));
 $('cloud-upload').addEventListener('click',()=>run(async()=>{
  if(syncing)throw Error('Wait for the current backup to finish');
  if(!confirm('Upload local demo progress to this account? This replaces the current cloud backup if the revision matches.'))return;
  stopAuto();
  const uid=currentUser.uid,epoch=accountEpoch,save=getLocal(),local=JSON.stringify(save);
  const result=await request('save','PUT',{save,revision:remoteRevision});
  if(!accountCheck(uid,epoch))return;
  remoteRevision=result.revision;currentRemote=save;writeLink(uid,result.revision,local);
  message('Local demo progress uploaded. Automatic backup is now active.');
  await refresh();
 }));
 $('cloud-download').addEventListener('click',()=>run(async()=>{
  if(syncing)throw Error('Wait for the current backup to finish');
  const uid=currentUser.uid,epoch=accountEpoch;
  const result=await request('save');
  if(!accountCheck(uid,epoch))return;
  if(!result.save)throw Error('No cloud backup available');
  if(!confirm('Replace local demo progress with cloud backup? Unsynced local changes will be lost.'))return;
  stopAuto();
  applyLocal(result.save);
  writeLink(uid,result.revision,snapshot());
  remoteRevision=result.revision;currentRemote=result.save;
  message('Cloud demo backup loaded. Automatic backup is now active.');
  await refresh();
 }));
 root.addEventListener('online',()=>{if(autoEnabled&&currentUser&&readLink(currentUser.uid)?.snapshot!==snapshot())schedule()});
}
root.IDLE_CLOUD={init,actions,onLocalChange};
})(window);
