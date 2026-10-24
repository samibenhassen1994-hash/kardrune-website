import {json} from './_lib/auth.js';
export function onRequestGet({env}){
 const projectId=env.FIREBASE_PROJECT_ID||'',apiKey=env.FIREBASE_API_KEY||'',authDomain=env.FIREBASE_AUTH_DOMAIN||'';
 return json({enabled:Boolean(projectId&&apiKey&&authDomain&&env.DB),firebase:projectId&&apiKey&&authDomain?{projectId,apiKey,authDomain,appId:env.FIREBASE_APP_ID||undefined}:null});
}
