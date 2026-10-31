import {userFromRequest,json,failure} from './auth.js';
import {effectiveCardStats} from '../../../shared/card_stat_limits.js';
import {requireActiveAccount} from './account_status.js';
const HP=[0,240,340,430];
const HEROES=new Set(['sam','lira','rhea','dren','tor','aria','kael','neris','nyra']);
export async function context(request,env){
 const user=await userFromRequest(request,env);
 if(!env.DB)throw new Response('Database unavailable',{status:503});
 await requireActiveAccount(env,user.uid);
 return user;
}
export function choice(save){
 if(!save||typeof save!=='object'||!Array.isArray(save.owned))return null;
 const id=save.active;
 if(typeof id!=='string'||!save.owned.includes(id))return null;
 const [hero,stageText]=id.split(':'),stage=Number(stageText);
 const attack=save.attacks?.[id],crit=save.crits?.[id];
 if(!HEROES.has(hero)||!Number.isInteger(stage)||stage<1||stage>3||!Number.isInteger(attack)||attack<1||attack>100||!Number.isInteger(crit)||crit<0||crit>25)return null;
 const effective=effectiveCardStats(stage,attack,crit);
 return {id,hero,stage,...effective,maxHp:HP[stage]};
}
export async function cardFromCloud(env,uid){
 const row=await env.DB.prepare('SELECT save_json FROM demo_saves WHERE uid=?').bind(uid).first();
 if(!row)return null;
 try{return choice(JSON.parse(row.save_json))}catch{return null}
}
export function fight(a,b,random=Math.random){
 const hp=[a.maxHp,b.maxHp],cards=[a,b],log=[];
 let turn=random()<.5?0:1;
 for(let i=0;i<1000&&hp[0]>0&&hp[1]>0;i++){
  const crit=random()<cards[turn].crit/100;
  const damage=cards[turn].attack*(crit?2:1),target=1-turn;
  hp[target]=Math.max(0,hp[target]-damage);
  log.push({actor:turn,damage,crit,remainingHp:hp[target]});
  turn=target;
 }
 return {winner:hp[0]===0?1:0,log};
}
export {json,failure};
