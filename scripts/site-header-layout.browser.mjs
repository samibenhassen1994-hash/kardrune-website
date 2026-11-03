// Browser regression for all website header layouts, signed in and signed out.
// Run: npm install --no-save playwright && npx playwright install chromium
//      node scripts/site-header-layout.browser.mjs
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
import assert from 'node:assert/strict';
import {chromium} from 'playwright';

const root=resolve(import.meta.dirname,'..');
const types={'.html':'text/html','.css':'text/css','.js':'text/javascript','.png':'image/png','.jpg':'image/jpeg','.webp':'image/webp','.svg':'image/svg+xml'};
const server=createServer(async(req,res)=>{
  const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  const filename=resolve(root,'.'+pathname.replace(/\/$/,'/index.html'));
  if(!filename.startsWith(root+sep)){res.writeHead(403).end();return}
  try{
    const bytes=await readFile(filename);
    res.writeHead(200,{'Content-Type':types[extname(filename)]||'application/octet-stream'}).end(bytes);
  }catch{res.writeHead(404).end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const port=server.address().port;
const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
try{
  const pages=['index.html','conquest.html','story.html','playground.html','idle.html'];
  const widths=[320,375,768,859,1024,1120,1121,1280,1410,1600,1900,1920,2200];
  const issues=[];
  for(const path of pages){
    for(const width of widths){
      for(const signedIn of [false,true]){
        const page=await browser.newPage({viewport:{width,height:800}});
        // Static layout can be tested without depending on external Firebase, fonts,
        // or analytics. The same DOM insertion used by site-account-nav.js follows.
        await page.route('https://**/*',route=>route.abort());
        await page.goto(`http://127.0.0.1:${port}/${path}`,{waitUntil:'domcontentloaded'});
        await page.evaluate((signedIn)=>{
          const header=document.querySelector('header.site-header');
          if(!header)return;
          const oldAccountLink=header.querySelector('.home-top-actions a[href="account.html"]');
          const host=document.createElement('a');
          host.className='site-account-link';
          host.href='account.html';
          const avatar=document.createElement('span');
          avatar.className='site-account-avatar';
          avatar.textContent=signedIn?'S':'♙';
          const label=document.createElement('span');
          label.className='site-account-label';
          label.textContent=signedIn?'AnExtremelyLongDisplayNameForLayout':'Accedi';
          host.append(avatar,label);
          let actions=header.querySelector(':scope > .home-top-actions');
          if(!actions && header.classList.contains('site-header')){
            actions=header.querySelector(':scope > .site-header-actions');
            if(!actions){
              actions=document.createElement('div');
              actions.className='site-header-actions';
              const cta=header.querySelector(':scope > .nav-cta');
              if(cta)actions.append(cta);
              header.append(actions);
            }
          }
          (actions||header).append(host);
          oldAccountLink?.remove();
        },signedIn);
        const result=await page.evaluate(()=>{
          const header=document.querySelector('.site-header');
          const selectors=[':scope > .brand',':scope > .menu-button',':scope > .nav-links',':scope > .nav-cta',':scope > .home-top-actions',':scope > .site-header-actions'];
          const rect=element=>{
            const style=getComputedStyle(element);
            if(style.display==='none'||style.visibility==='hidden'||style.position==='fixed')return null;
            const r=element.getBoundingClientRect();
            return r.width&&r.height?{left:r.left,right:r.right,top:r.top,bottom:r.bottom,width:r.width}:null;
          };
          const children=selectors.map(s=>header.querySelector(s)).filter(Boolean).map(e=>({name:e.className,box:rect(e)})).filter(e=>e.box);
          const all=[];
          const pairs=els=>{
            for(let a=0;a<els.length;a++)for(let b=a+1;b<els.length;b++){
              const x=els[a].box,y=els[b].box;
              const overlapX=Math.min(x.right,y.right)-Math.max(x.left,y.left);
              const overlapY=Math.min(x.bottom,y.bottom)-Math.max(x.top,y.top);
              if(overlapX>2&&overlapY>3) all.push(`${els[a].name} overlaps ${els[b].name} by ${overlapX.toFixed(1)}px`);
            }
          };
          pairs(children);
          for(const group of header.querySelectorAll(':scope > .home-top-actions, :scope > .site-header-actions')){
            const inner=[...group.children].map(e=>({name:e.className,box:rect(e)})).filter(e=>e.box);
            pairs(inner);
          }
          const brand=header.querySelector('.brand');
          if(!brand || brand.getBoundingClientRect().width<30)all.push('brand clipped');
          for(const item of children){
            if(item.box.left< -2 || item.box.right>innerWidth+2) all.push(`${item.name} outside viewport`);
          }
          return {errors:all,navHidden:getComputedStyle(header.querySelector('.nav-links')).display==='none'};
        });
        if(result.errors.length)issues.push({path,width,signedIn,...result});
        if(width<=1900 && width>=768 && result.navHidden){
          await page.locator('.menu-button').click();
          const open=await page.locator('.nav-links').evaluate(e=>({display:getComputedStyle(e).display,visibility:getComputedStyle(e).visibility,r:e.getBoundingClientRect().toJSON()}));
          if(open.display==='none'||open.r.right>width+2||open.r.left<0)issues.push({path,width,signedIn,error:'mobile/intermediate menu inaccessible',open});
        }
        await page.close();
      }
    }
  }
  if(issues.length){console.error(JSON.stringify(issues.slice(0,40),null,2));throw Error(`${issues.length} responsive header collisions`)}
  console.log(`PASS: ${pages.length*widths.length*2} header variants, including account, CTA and dropdown positions`);
}finally{
  await browser.close();
  await new Promise(r=>server.close(r));
}
