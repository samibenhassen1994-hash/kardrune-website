/* Nine physical slots, compact server deck. */
(function(root){
'use strict';
const N=9;
function cards(slots){return slots.filter(id=>typeof id==='string'&&id.length>0)}
function normalize(input,owned){
 const allowed=new Set(owned||[]),seen=new Set(),out=Array(N).fill(null);
 if(!Array.isArray(input))return out;
 for(let i=0;i<Math.min(N,input.length);i++){
  const id=input[i];
  if(typeof id==='string'&&allowed.has(id)&&!seen.has(id)){out[i]=id;seen.add(id)}
 }
 return out;
}
function put(current,id,slot,owned){
 const state=normalize(current,owned);
 if(!(owned||[]).includes(id))throw Error('Card is not owned');
 const target=Number.isInteger(slot)&&slot>=0&&slot<N?slot:state.indexOf(null);
 if(target<0)throw Error('All nine slots are full');
 const from=state.indexOf(id);
 if(from===target)return state;
 const replaced=state[target];
 if(from>=0){state[from]=replaced||null;state[target]=id;return state}
 if(replaced){const empty=state.indexOf(null);if(empty<0)throw Error('All nine slots are full');state[empty]=replaced}
 state[target]=id;return state;
}
function remove(current,slot,owned){const out=normalize(current,owned);if(slot>=0&&slot<N)out[slot]=null;return out}
root.IDLE_DECK_LAYOUT={cards,normalize,put,remove};
})(window);
