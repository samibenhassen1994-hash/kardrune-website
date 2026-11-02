// Header account widget, shared by marketing pages and the player portal.
// This must use the same Firebase application name as Idle Flutter and account.js.
import { initializeApp, getApps } from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js';
import { getAuth, onAuthStateChanged } from 'https://www.gstatic.com/firebasejs/11.10.0/firebase-auth.js';

const header = document.querySelector('header.site-header, header.top');
if (header) {
  const oldAccountLink = header.querySelector('.home-top-actions a[href="account.html"]');
  // The persistent HTML link can remain if JS fails to load.
  const host = document.createElement('a');
  host.className = 'site-account-link';
  host.href = 'account.html';
  host.setAttribute('aria-label', 'Accedi o apri il tuo account KardRune');
  host.title = 'Account KardRune';

  const avatar = document.createElement('span');
  avatar.className = 'site-account-avatar';
  avatar.setAttribute('aria-hidden', 'true');
  avatar.textContent = '♙';
  const label = document.createElement('span');
  label.className = 'site-account-label';
  label.textContent = 'Accedi';
  host.append(avatar, label);
  header.append(host);
  oldAccountLink?.remove();

  function renderUser(user) {
    avatar.replaceChildren();
    host.classList.toggle('site-account-signed-in', !!user);
    if (!user) {
      avatar.textContent = '♙';
      label.textContent = 'Accedi';
      host.title = 'Accedi o registrati';
      host.setAttribute('aria-label', 'Accedi o registrati a KardRune');
      return;
    }
    const displayName = user.displayName?.trim() || user.email?.split('@')[0] || 'Giocatore';
    label.textContent = displayName;
    avatar.textContent = displayName.slice(0, 1).toLocaleUpperCase();
    host.title = 'Il tuo account: ' + displayName;
    host.setAttribute('aria-label', 'Apri il tuo account KardRune: ' + displayName);
    if (user.photoURL) {
      try {
        const url = new URL(user.photoURL);
        if (url.protocol === 'https:') {
          const picture = document.createElement('img');
          picture.alt = '';
          picture.src = url.href;
          picture.referrerPolicy = 'no-referrer';
          picture.addEventListener('error', () => picture.remove(), { once: true });
          avatar.append(picture);
        }
      } catch { /* Fallback to account initial. */ }
    }
  }

  (async () => {
    try {
      const response = await fetch('/api/config', { cache: 'no-store' });
      if (!response.ok) return;
      const config = await response.json();
      if (!config.enabled || !config.firebase) return;
      const f = config.firebase;
      const app = getApps().find((candidate) => candidate.name === 'idle-kardrune-cloud')
        || initializeApp({
          apiKey: f.apiKey,
          authDomain: f.authDomain,
          projectId: f.projectId,
          appId: f.appId || 'idle-kardrune-web',
        }, 'idle-kardrune-cloud');
      onAuthStateChanged(getAuth(app), renderUser, () => renderUser(null));
    } catch {
      // Site navigation remains usable if the cloud configuration is unavailable.
    }
  })();
}
