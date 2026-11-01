export function assertActivePlayer(player,{allowMissing=false}={}){
 if(!player&&allowMissing)return;
 if(!player||player.is_banned)throw new Response('Account unavailable',{status:403});
}

export async function requireActiveAccount(env,uid,options){
 const player=await env.DB.prepare('SELECT is_banned FROM players WHERE uid=?')
  .bind(uid).first();
 assertActivePlayer(player,options);
 return player;
}
