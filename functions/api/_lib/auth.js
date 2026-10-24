// Validate Firebase-issued ID tokens on Cloudflare Workers (RS256).
const JWKS='https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const imported=new Map();
function fromBase64url(x){const y=x.replace(/-/g,'+').replace(/_/g,'/');return Uint8Array.from(atob(y.padEnd(Math.ceil(y.length/4)*4,'=')),c=>c.charCodeAt(0))}
export async function userFromRequest(request,env){
 const project=env.FIREBASE_PROJECT_ID;
 if(!project)throw new Response('Authentication not configured',{status:503});
 const header=request.headers.get('authorization')||'';
 if(!header.startsWith('Bearer '))throw new Response('Sign in required',{status:401});
 const token=header.slice(7);const parts=token.split('.');
 if(parts.length!==3||parts.some(p=>p.length>6000))throw new Response('Invalid token',{status:401});
 let head,payload;
 try{head=JSON.parse(new TextDecoder().decode(fromBase64url(parts[0])));payload=JSON.parse(new TextDecoder().decode(fromBase64url(parts[1])))}catch{throw new Response('Invalid token',{status:401})}
 const now=Math.floor(Date.now()/1000);
 if(head.alg!=='RS256'||typeof head.kid!=='string'||head.kid.length>150||payload.aud!==project||payload.iss!=='https://securetoken.google.com/'+project||typeof payload.sub!=='string'||!payload.sub||payload.sub.length>128||typeof payload.exp!=='number'||payload.exp<=now||typeof payload.iat!=='number'||payload.iat>now||payload.auth_time>now)throw new Response('Invalid token',{status:401});
 let cache=imported.get(head.kid);
 if(!cache||cache.expires<Date.now()){
  const res=await fetch(JWKS);
  if(!res.ok)throw new Response('Auth verification unavailable',{status:503});
  const keys=await res.json();const jwk=keys.keys?.find(k=>k.kid===head.kid&&k.kty==='RSA'&&k.alg==='RS256');
  if(!jwk)throw new Response('Unknown signing key',{status:401});
  const key=await crypto.subtle.importKey('jwk',jwk,{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['verify']);
  cache={key,expires:Date.now()+3600_000};imported.set(head.kid,cache);
 }
 const signed=new TextEncoder().encode(parts[0]+'.'+parts[1]);
 if(!await crypto.subtle.verify('RSASSA-PKCS1-v1_5',cache.key,fromBase64url(parts[2]),signed))throw new Response('Invalid signature',{status:401});
 return {uid:payload.sub,name:typeof payload.name==='string'?payload.name.slice(0,40):'Runebearer',email:payload.email||null};
}
export function failure(error){if(error instanceof Response)return error;console.error('Cloud API failure',error);return new Response('Server error',{status:500})}
export const json=(data,status=200)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store'}});
