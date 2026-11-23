const link = document.querySelector('#admin-arena');
const endpoint = '/api/admin/arena-access';
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function gameAuth() {
  // FlutterFire initializes this named app and chooses its persistence.
  // Calling getAuth before initializeAuth would initialize a competing provider.
  while (true) {
    const app = window.firebase_core?.getApps().find(a => a.name === 'idle-kardrune-cloud');
    if (app?.container?.getProvider('auth').isInitialized() && window.firebase_auth) {
      return window.firebase_auth.getAuth(app);
    }
    await sleep(500);
  }
}

async function mount() {
  const auth = await gameAuth();
  let generation = 0;
  let confirmedUid;
  async function access(user, method) {
    for (const refresh of [false, true]) {
      const token = await user.getIdToken(refresh);
      const result = await fetch(endpoint, {method, cache:'no-store', headers:{Authorization:'Bearer '+token}});
      if (result.status !== 401 || refresh) return result;
    }
  }
  async function verify(user) {
    const run = ++generation;
    if (!user || confirmedUid !== user.uid) link.hidden = true;
    if (!user) {
      confirmedUid = undefined;
      await fetch(endpoint,{method:'DELETE'}).catch(()=>{});
      return;
    }
    for (const delay of [0, 1000, 3000]) {
      if (delay) await sleep(delay);
      if (run !== generation || user !== auth.currentUser) return;
      try {
        const r = await access(user,'GET');
        if (run !== generation || user !== auth.currentUser) return;
        if (r.ok || r.status === 401 || r.status === 403) {
          confirmedUid = r.ok ? user.uid : undefined;
          link.hidden = !r.ok;
          return;
        }
      } catch {}
    }
  }
  auth.onIdTokenChanged(verify);
  window.addEventListener('focus', () => verify(auth.currentUser));
  link.onclick = async event => {
    event.preventDefault();
    const user = auth.currentUser;
    if (!user || confirmedUid !== user.uid) return;
    try {
      const r = await access(user,'POST');
      if (user !== auth.currentUser) return;
      if (r.ok) {location.assign(link.href);return;}
      if (r.status === 401 || r.status === 403) {await verify(user);return;}
    } catch {}
    if (user === auth.currentUser) window.alert('Apertura temporaneamente non riuscita. Riprova.');
  };
}
mount().catch(()=>{link.hidden=true;});
