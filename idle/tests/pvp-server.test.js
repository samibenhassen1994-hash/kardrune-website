'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const code=fs.readFileSync(require('node:path').join(__dirname,'../../functions/api/_lib/pvp.js'),'utf8')
 .replace(/^import .*;$/gm,'').replace('export async function context','async function context')
 .replace('export function choice','function choice').replace('export async function cardFromCloud','async function cardFromCloud')
 .replace('export function fight','function fight').replace('export {json,failure};','');
const {choice,fight}=new Function('return (function(){'+code+';return {choice,fight}})()')();
test('only valid owned active cards can enter queue',()=>{
 const base={owned:['sam:1'],active:'sam:1',attacks:{'sam:1':40},crits:{'sam:1':4}};
 assert.deepEqual(choice(base),{id:'sam:1',hero:'sam',stage:1,attack:40,crit:4,maxHp:240});
 assert.equal(choice({...base,active:'dren:3'}),null);
 assert.equal(choice({...base,attacks:{'sam:1':0}}),null);
 assert.equal(choice({...base,crits:{'sam:1':26}}),null);
});
test('server duel uses exact attack, doubled critical and fixed stage HP',()=>{
 const a={id:'sam:1',attack:58,crit:25,maxHp:240};
 const b={id:'dren:1',attack:1,crit:0,maxHp:240};
 let sequence=[0,.99,.99,.99,0];
 let index=0;
 const result=fight(a,b,()=>sequence[index++]??.99);
 assert.equal(result.log[0].damage,58);
 assert.equal(result.log[0].remainingHp,182);
 assert.equal(result.log[2].damage,58);
 assert.equal(result.log[4].damage,116);
 assert.equal(result.winner,0);
});
