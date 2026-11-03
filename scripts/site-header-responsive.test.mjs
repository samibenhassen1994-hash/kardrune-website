import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read = path => readFileSync(new URL('../'+path,import.meta.url),'utf8');
test('signed-in account joins header install actions instead of squeezing logo',()=>{
  const js = read('site-account-nav.js');
  assert.match(js,/header\.querySelector\('\.home-top-actions'\)/);
  assert.match(js,/\(actions \|\| header\)\.append\(host\)/);
  assert.match(js,/oldAccountLink\?\.remove\(\)/);
});
test('brand is not shrinkable and crowded desktop nav is compact',()=>{
  const css=read('styles.css');
  assert.match(css,/\.site-header > \.brand \{[^}]*flex:\s*0 0 auto/s);
  assert.match(css,/@media \(min-width: 1121px\) and \(max-width: 1700px\)/);
  assert.match(css,/@media \(min-width: 1121px\) and \(max-width: 1350px\)/);
  assert.match(css,/\.page-home \.home-top-actions \.site-account-label\s*\{\s*display: none;/);
});
test('homepage navigation and install actions remain in the HTML',()=>{
 const html=read('index.html');
 assert.match(html,/class="brand"/);
 assert.match(html,/class="nav-links"/);
 assert.match(html,/class="home-top-actions"/);
 assert.match(html,/src="site-account-nav\.js"/);
});
