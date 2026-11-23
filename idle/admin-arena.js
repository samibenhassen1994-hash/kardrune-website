import {initializeApp,getApps} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js';
import {getAuth,onAuthStateChanged} from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-auth.js';
const link=document.querySelector('#admin-arena');
const endpoint='/api/admin/arena-access';
async function init() {
  const {firebase:f}=await (await fetch('/api/config',{cache:'no-store'})).json();
  const name='idle-kardrune-cloud';
  const app=getApps().find(a=>a.name===name)||initializeApp({...f,appId:f.appId||'idle-kardrune-web'},name);
  const auth=getAuth(app);
  const access=async (user,method)=>fetch(endpoint,{method,cache:'no-store',headers:{Authorization:'Bearer '+await user.getIdToken()}});
  onAuthStateChanged(auth,async user=>{
    link.hidden=true;
    if (!user) {await fetch(endpoint,{method:'DELETE'});return;}
    try {const result=await access(user,'GET');link.hidden=!(result.ok && user===auth.currentUser);}
    catch {link.hidden=true;}
  });
  link.onclick=async event=>{
    event.preventDefault();
    const user=auth.currentUser;
    try {if(user && (await access(user,'POST')).ok && user===auth.currentUser) {location.assign(link.href);return;}}
    catch {}
    link.hidden=true;
  };
}
init().catch(()=>{link.hidden=true;});
