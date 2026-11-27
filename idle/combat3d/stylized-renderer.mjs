import * as T from './vendor/three.module.js';

// Shared art direction for all GLB characters. No geometry/animation edits.
export function createStylizedRenderer(renderer, scene) {
  renderer.toneMapping = T.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1;
  scene.fog = new T.FogExp2(0x77675f, .009);
  scene.add(new T.HemisphereLight(0xfffcf5, 0x70617b, .65));
  for (const [position, color, intensity] of [
    [[-3, 7, 5], 0xfff8ef, 1.25], [[4, 4, 2], 0xf1f0ff, .32],
  ]) {
    const light = new T.DirectionalLight(color, intensity);
    light.position.set(...position); scene.add(light);
  }
  // A filtered, continuous four-value ramp avoids harsh bands and mobile aliasing.
  const data = new Uint8Array(128 * 4);
  for (let i = 0; i < 128; i++) {
    const x = i / 127;
    const smooth = (a, b) => { const t = T.MathUtils.clamp((x-a)/(b-a),0,1);return t*t*(3-2*t); };
    const value = .26 + .22*smooth(.15,.4) + .26*smooth(.43,.68) + .26*smooth(.72,.98);
    data.set([value*255,value*255,value*255,255],i*4);
  }
  const ramp = new T.DataTexture(data,128,1,T.RGBAFormat);
  ramp.minFilter = ramp.magFilter = T.LinearFilter;
  ramp.generateMipmaps = false; ramp.needsUpdate = true;
  const anisotropy = Math.min(4,renderer.capabilities.getMaxAnisotropy());
  const actors = {value:[new T.Vector2(-100,-100),new T.Vector2(-100,-100)]};
  const originals = new Set();
  function tuneTexture(map) {
    if (!map) return;
    map.anisotropy=anisotropy;map.needsUpdate=true;
  }
  function characters(root) {
    const cache = new Map();
    root.traverse(object => {
      if (!object.isMesh) return;
      const convert = source => {
        if(cache.has(source))return cache.get(source);
        originals.add(source);
        const m = new T.MeshToonMaterial({
          name:source.name+'_SoftToon',color:source.color?.clone()||new T.Color('white'),
          map:source.map,gradientMap:ramp,normalMap:source.normalMap,
          normalScale:source.normalScale?.clone().multiplyScalar(.65)||new T.Vector2(.65,.65),
          normalMapType:source.normalMapType,
          aoMap:source.aoMap,aoMapIntensity:Math.min(source.aoMapIntensity??1,.7),
          emissive:source.emissive?.clone()||new T.Color('black'),
          emissiveMap:source.emissiveMap,emissiveIntensity:Math.min(source.emissiveIntensity??1,.35),
          alphaMap:source.alphaMap,alphaTest:source.alphaTest,transparent:source.transparent,
          opacity:source.opacity,side:source.side,vertexColors:source.vertexColors,
          depthWrite:source.depthWrite,depthTest:source.depthTest,
        });
        tuneTexture(m.map);tuneTexture(m.normalMap);
        m.onBeforeCompile=shader=>{
          shader.fragmentShader=shader.fragmentShader.replace('#include <color_fragment>',`#include <color_fragment>
            float paintedLuma=dot(diffuseColor.rgb,vec3(.2126,.7152,.0722));
            diffuseColor.rgb=max(vec3(0.),mix(vec3(paintedLuma),diffuseColor.rgb,1.03));
          `);
          shader.fragmentShader=shader.fragmentShader.replace('#include <opaque_fragment>',`
            float silhouette=smoothstep(.05,.65,max(dot(normal,normalize(vViewPosition)),0.));
            outgoingLight*=mix(vec3(.73,.70,.80),vec3(1.),silhouette);
            #include <opaque_fragment>
          `);
        };
        m.customProgramCacheKey=()=> 'kardrune-soft-toon-v1';
        cache.set(source,m);return m;
      };
      object.material=Array.isArray(object.material)?object.material.map(convert):convert(object.material);
    });
  }
  function arena(root) {
    const seen=new Set();
    root.traverse(object=>{
      if(!object.isMesh)return;
      for(const m of [].concat(object.material)){
        if(seen.has(m))continue;seen.add(m);
        m.metalness=Math.min(m.metalness??0,.08);m.roughness=Math.max(m.roughness??1,.85);
        if(m.normalScale)m.normalScale.multiplyScalar(.6);tuneTexture(m.map);
        m.onBeforeCompile=shader=>{
          shader.uniforms.contactActors=actors;
          shader.vertexShader='varying vec3 contactWorld; varying float contactUp;\n'+shader.vertexShader;
          shader.vertexShader=shader.vertexShader.replace('#include <worldpos_vertex>',`#include <worldpos_vertex>
            contactWorld=(modelMatrix*vec4(transformed,1.)).xyz;
            contactUp=normalize(mat3(modelMatrix)*objectNormal).y;
          `);
          shader.fragmentShader='uniform vec2 contactActors[2]; varying vec3 contactWorld; varying float contactUp;\n'+shader.fragmentShader;
          shader.fragmentShader=shader.fragmentShader.replace('#include <opaque_fragment>',`
            float contact=0.;
            for(int i=0;i<2;i++){
              vec2 d=(contactWorld.xz-contactActors[i])/vec2(.72,.5);
              contact=max(contact,exp(-dot(d,d)*1.65)*.32);
            }
            contact*=smoothstep(.65,.92,contactUp)*(1.-smoothstep(.07,.32,abs(contactWorld.y)));
            outgoingLight*=mix(vec3(1.),vec3(.56,.5,.65),contact*2.);
            #include <opaque_fragment>
          `);
        };
        m.customProgramCacheKey=()=> 'kardrune-ground-contact-v1';m.needsUpdate=true;
      }
    });
  }
  function update(fighters) {
    for(const [i,id] of ['hero','zeus'].entries()){
      const f=fighters[id];if(f?.model.visible)actors.value[i].set(f.model.position.x,f.model.position.z);
      else actors.value[i].set(-100,-100);
    }
  }
  // Texture ownership stays with the meshes; dispose replaced PBR material objects only.
  function dispose(){originals.forEach(m=>m.dispose());ramp.dispose();}
  return {characters,arena,update,dispose};
}
