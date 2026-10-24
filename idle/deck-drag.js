/* Inventory -> nine-slot deck: standard mouse/touch events, never native iOS drag. */
(function(root){
'use strict';
function attach(artwork,id,{image,slots,onDrop}){
 if(!artwork)return;
 let gesture=null,preview=null,scrollTask=null;
 const getSlots=()=>[...slots.querySelectorAll('.deck-slot')];
 function clearMarks(){getSlots().forEach(el=>el.classList.remove('drag-over'))}
 function hit(x,y){
  const r=slots.getBoundingClientRect();
  if(x<r.left||x>r.right||y<r.top-8||y>r.bottom+8)return null;
  const el=document.elementFromPoint(x,y)?.closest('.deck-slot');
  return el&&slots.contains(el)?el:null;
 }
 function sync(x,y){
  if(!gesture)return;
  gesture.x=x;gesture.y=y;
  if(!preview)return;
  preview.style.left=x+'px';preview.style.top=y+'px';
  const hovered=hit(x,y);
  clearMarks();if(hovered)hovered.classList.add('drag-over');
  const r=slots.getBoundingClientRect();
  const inArea=x>=r.left&&x<=r.right&&y>=r.top-12&&y<=r.bottom+12;
  preview.classList.toggle('over-slot',inArea);
  if(inArea){const slot=getSlots()[0];if(slot){const b=slot.getBoundingClientRect();preview.style.width=b.width+'px';preview.style.height=b.height+'px'}}
  else{preview.style.width='112px';preview.style.height='146px'}
 }
 function beginVisual(){
  if(preview)return;
  preview=document.createElement('div');preview.className='deck-custom-ghost';preview.setAttribute('aria-hidden','true');
  const img=document.createElement('img');img.src=image;img.alt='';img.draggable=false;preview.append(img);
  document.body.append(preview);
  artwork.closest('.hero-card')?.classList.add('deck-touch-dragging');
  scrollTask=setInterval(()=>{
   if(!gesture||!preview)return;
   const edge=105,y=gesture.y,up=y<edge?Math.min(19,(edge-y)*.25):0;
   const down=y>innerHeight-edge?Math.min(19,(y-(innerHeight-edge))*.25):0;
   if(up||down){root.scrollBy(0,down-up);sync(gesture.x,gesture.y)}
  },30);
 }
 function update(x,y){if(!gesture)return;if(Math.hypot(x-gesture.sx,y-gesture.sy)>4)beginVisual();sync(x,y)}
 function finish(x,y,cancel=false){
  if(!gesture)return;
  const hadDrag=Boolean(preview),slot=!cancel&&hadDrag?hit(x,y):null;
  if(slot)onDrop(id,Number(slot.dataset.slot));
  if(hadDrag){
   const card=artwork.closest('.hero-card');
   if(card){const until=Date.now()+500;const suppress=e=>{
    card.removeEventListener('click',suppress,true);
    if(Date.now()<until){e.stopImmediatePropagation();e.preventDefault()}
   };card.addEventListener('click',suppress,true);setTimeout(()=>card.removeEventListener('click',suppress,true),510)}
  }
  clearInterval(scrollTask);scrollTask=null;
  preview?.remove();preview=null;clearMarks();
  artwork.closest('.hero-card')?.classList.remove('deck-touch-dragging');
  const mode=gesture.mode;gesture=null;
  if(mode==='touch'){
   document.removeEventListener('touchmove',touchMove);
   document.removeEventListener('touchend',touchEnd);
   document.removeEventListener('touchcancel',touchCancel);
   if(!hadDrag&&!cancel)artwork.click();
  }else{
   document.removeEventListener('mousemove',mouseMove);
   document.removeEventListener('mouseup',mouseUp);
  }
 }
 function touchMove(e){
  if(!gesture)return;e.preventDefault();
  const t=[...e.touches].find(t=>t.identifier===gesture.identifier);
  if(t)update(t.clientX,t.clientY);
 }
 function touchEnd(e){
  if(!gesture)return;e.preventDefault();
  const t=[...e.changedTouches].find(t=>t.identifier===gesture.identifier);
  if(t)finish(t.clientX,t.clientY);else finish(gesture.x,gesture.y,true);
 }
 function touchCancel(){if(gesture)finish(gesture.x,gesture.y,true)}
 function mouseMove(e){if(gesture)update(e.clientX,e.clientY)}
 function mouseUp(e){if(gesture){finish(e.clientX,e.clientY);e.preventDefault()}}
 artwork.addEventListener('touchstart',e=>{
  if(gesture||e.touches.length!==1)return;
  e.preventDefault();const t=e.touches[0];
  gesture={mode:'touch',identifier:t.identifier,sx:t.clientX,sy:t.clientY,x:t.clientX,y:t.clientY};
  document.addEventListener('touchmove',touchMove,{passive:false});
  document.addEventListener('touchend',touchEnd,{passive:false});
  document.addEventListener('touchcancel',touchCancel);
 },{passive:false});
 artwork.addEventListener('mousedown',e=>{
  if(gesture||e.button!==0)return;
  e.preventDefault();gesture={mode:'mouse',sx:e.clientX,sy:e.clientY,x:e.clientX,y:e.clientY};
  document.addEventListener('mousemove',mouseMove);
  document.addEventListener('mouseup',mouseUp);
 });
 artwork.addEventListener('dragstart',e=>e.preventDefault());
}
root.IDLE_DECK_DRAG={attach};
})(window);
