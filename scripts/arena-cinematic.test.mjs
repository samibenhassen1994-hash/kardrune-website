import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {SKILL_CINEMATICS,frameUV} from '../idle/combat3d/skill-cinematics.mjs';
const cfg=SKILL_CINEMATICS.DivineJudgment;
assert(cfg.animationRate>=1.5&&cfg.animationRate<=2);
assert(cfg.cutinEnd<cfg.impact&&cfg.impact<cfg.duration);
for(const effect of cfg.effects){
 const base=new URL('../idle/combat3d/vfx/zeus/'+effect.id+'_add_1024',import.meta.url).href;
 const atlas=JSON.parse(readFileSync(new URL(base+'.atlas.json')));
 const meta=JSON.parse(readFileSync(new URL(base+'.flipbook.json')));
 const png=readFileSync(new URL(base+'.png'));
 assert.equal(png.readUInt32BE(16),atlas.meta.size.w);assert.equal(png.readUInt32BE(20),atlas.meta.size.h);
 assert.equal(meta.frames,Object.keys(atlas.frames).length);assert.equal(meta.blend,'additive');
 assert(effect.at>=0&&effect.end<=cfg.duration&&effect.at<effect.end);
 for(const record of Object.values(atlas.frames)){
  const [x,y,w,h]=frameUV(record.frame,atlas.meta.size);
  assert(x>=0&&y>=0&&w>0&&h>0&&x+w<=1&&y+h<=1);
  assert(record.pivot.x===meta.pivot[0]&&record.pivot.y===meta.pivot[1]);
 }
}
console.log('PASS original atlas dimensions, every UV frame, pivots, additive blending and timeline');
