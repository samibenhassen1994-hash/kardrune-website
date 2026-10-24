/* Non-disruptive installed PWA update notice. User chooses when to reload. */
(function(root){
'use strict';
const BUILD='idle-kardrune-shell-v25';
const banner=document.getElementById('idle-update-banner');
const button=document.getElementById('idle-update-action');
let checking=false;
function show(){if(banner)banner.hidden=false}
async function check(){
 if(checking||!navigator.onLine)return;
 checking=true;
 try{
  const response=await fetch('./sw.js?check='+Date.now(),{cache:'no-store'});
  if(!response.ok)return;
  const script=await response.text();
  const latest=script.match(/idle-kardrune-shell-v\d+/)?.[0];
  if(latest&&latest!==BUILD){
   show();
   if('serviceWorker' in navigator)navigator.serviceWorker.getRegistration('./').then(reg=>reg?.update()).catch(()=>{});
  }
 }catch{}finally{checking=false}
}
button?.addEventListener('click',()=>{root.location.reload()});
document.addEventListener('visibilitychange',()=>{if(!document.hidden)check()});
root.addEventListener('online',check);
root.addEventListener('pageshow',check);
setInterval(()=>{if(!document.hidden)check()},120000);
setTimeout(check,2500);
})(window);
