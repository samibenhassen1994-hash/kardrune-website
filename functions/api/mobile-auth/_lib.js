const encoder = new TextEncoder();

export function base64url(bytes) {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

export async function codeHash(code) {
  return base64url(new Uint8Array(
    await crypto.subtle.digest('SHA-256', encoder.encode(code)),
  ));
}

export function randomCode() {
  return base64url(crypto.getRandomValues(new Uint8Array(32)));
}

export async function customToken(uid, env) {
  const email = env.FIREBASE_SERVICE_ACCOUNT_EMAIL;
  const pem = env.FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY;
  if (!email || !pem || !env.FIREBASE_PROJECT_ID) {
    throw new Response('Mobile authentication not configured', {status: 503});
  }
  const der = Uint8Array.from(
    atob(pem.replace(/-----[^-]+-----/g, '').replace(/\s/g, '')),
    c => c.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    'pkcs8', der, {name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256'}, false, ['sign'],
  );
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(encoder.encode(JSON.stringify({alg: 'RS256', typ: 'JWT'})));
  const payload = base64url(encoder.encode(JSON.stringify({
    iss: email, sub: email,
    aud: 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
    iat: now, exp: now + 300, uid,
  })));
  const body = `${header}.${payload}`;
  const signature = new Uint8Array(await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, encoder.encode(body),
  ));
  return `${body}.${base64url(signature)}`;
}
