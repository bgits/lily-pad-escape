const loadLevel=require('./level_routes.cjs');
/* Actual Web-export tests. The only game bridge is read-only QA telemetry.
   Course traversal uses mouse motion plus W/Space; no position setters or teleports. */
const { chromium } = require('playwright');
const fs = require('node:fs/promises');
const assert = require('node:assert/strict');
const path = require('node:path');
const ROOT = path.resolve(__dirname, '..');
const URL = process.env.GAME_URL || 'http://127.0.0.1:8765/?qa';
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
 const browser = await chromium.launch({headless:true, channel:'chrome', args:['--use-angle=metal']});
 const context = await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
 const page = await context.newPage();
 const errors=[], checks=[], landings=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const read=()=>page.evaluate(()=>window.lilyPadState);
 const shot=name=>page.screenshot({path:path.join(ROOT,'docs',name),scale:'css'});
 const check=(ok,description)=>{assert(ok,description);checks.push(description);console.log('PASS:',description)};
 const state=expected=>page.waitForFunction(expected=>window.lilyPadState?.state===expected,expected,{timeout:5000});
 const click=async(x,y)=>{await page.mouse.click(x,y);await sleep(180)};
 const restart=async()=>{await page.keyboard.press('r');await sleep(350)};
 try {
  await page.goto(URL);
  await page.waitForSelector('#loading',{state:'detached'});
  await state('title');
  check(!(await page.evaluate(()=>!!document.pointerLockElement)),'Title starts with the mouse released');
  await shot('01-title.png');
  await click(200,437);await page.keyboard.type('Pip',{delay:80});await sleep(180);check((await read()).player_name==='Pip','Optional name accepts ordinary typed characters');
  check((await read()).hoodie==='f3cc58','The default outfit is visible on the title screen');
  await click(220,565);await state('playing');await sleep(600);
  check(await page.evaluate(()=>!!document.pointerLockElement),'Play captures the mouse from a deliberate click');
  await shot('02-gameplay.png');
  await click(640,360);await state('paused');check((await read()).state==='paused','Left click pauses without needing a keyboard');await click(640,350);await state('playing');await sleep(350);
  // Sample the actual browser renderer and a settled frame rate.
  const environment=await page.evaluate(()=>{const gl=document.getElementById('canvas').getContext('webgl2');const ext=gl.getExtension('WEBGL_debug_renderer_info');return{userAgent:navigator.userAgent,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),viewport:[innerWidth,innerHeight],devicePixelRatio}});
  const fps=[];for(let i=0;i<8;i++){await sleep(250);fps.push((await read()).fps)}
  await page.keyboard.down('Space');await sleep(1600);await page.keyboard.up('Space');await sleep(180);
  let s=await read();check(s.jumps===1&&s.grounded,'Held Space causes one jump without automatic repeats');
  await restart();await page.keyboard.down('w');await sleep(280);s=await read();const straight=Math.hypot(s.velocity[0],s.velocity[2]);await page.keyboard.up('w');
  await restart();await page.keyboard.down('w');await page.keyboard.down('d');await sleep(280);s=await read();const diagonal=Math.hypot(s.velocity[0],s.velocity[2]);await page.keyboard.up('w');await page.keyboard.up('d');
  check(Math.abs(straight-diagonal)<.02&&Math.abs(diagonal-5.4)<.02,'Browser diagonal and straight speeds are both 5.4 m/s');
  await restart();await page.keyboard.press('Space');await sleep(180);await page.keyboard.press('Escape');await state('paused');
  const frozen=await read();await sleep(350);s=await read();check(!frozen.grounded&&JSON.stringify(frozen.position)===JSON.stringify(s.position),'Escape freezes an airborne jump');
  check(!(await page.evaluate(()=>!!document.pointerLockElement)),'Pause releases the mouse');await shot('08-pause.png');
  await click(640,477);check((await read()).muted,'Mute button mutes the audio bus');await click(640,477);check(!(await read()).muted,'Sound button restores audio');
  await click(640,350);await state('playing');await sleep(950);s=await read();check(s.grounded&&s.jumps===1,'Resume continues the jump and lands safely');
  // Focus loss while a movement key is held, followed by key release in another tab.
  await restart();await page.keyboard.down('w');await sleep(100);const other=await context.newPage();await other.goto('about:blank');await other.bringToFront();await state('paused');await other.keyboard.up('w');await other.close();await page.bringToFront();
  await click(640,350);await state('playing');await sleep(650);s=await read();check(Math.hypot(s.velocity[0],s.velocity[2])<.01,'Losing focus pauses and does not leave a movement key stuck');
  await page.evaluate(()=>document.exitPointerLock());await state('paused');check((await read()).state==='paused','Losing pointer lock pauses the game');await click(640,350);await state('playing');
  await restart();
  for(let i=1;i<=3;i++){
   await page.keyboard.down('s');await state('splash');await page.keyboard.up('s');const stamp=Date.now();s=await read();check(s.falls===i,'Water fall '+i+' triggers exactly one failure');if(i===1)await shot('09-splash.png');
   await state('playing');await sleep(180);s=await read();check(s.falls===i&&Math.hypot(s.position[0],s.position[2]-.55)<.05&&s.grounded,'Water fall '+i+' returns to the starting pad');check(Date.now()-stamp<1500,'Water fall '+i+' retries in about one second');
  }
  await restart();check((await read()).falls===0&&(await read()).pad===0,'R resets failures and progress');
  // Aim the camera at each center, then traverse using ordinary input.
  let mx=640,my=360;await page.mouse.move(mx,my);await sleep(180);
  const level=loadLevel('sunlit_lagoon'),route=[...level.pads.slice(1),level.flag];
  for(let index=0;index<route.length;index++){
   const target=route[index];s=await read();assert.equal(s.state,'playing');
   const dx=target[0]-s.position[0],dz=target[1]-s.position[2],distance=Math.hypot(dx,dz),angle=Math.atan2(-dx,-dz);
   const diff=((angle-s.yaw+Math.PI*3)%(Math.PI*2))-Math.PI,pixels=-diff/.0026,steps=Math.max(1,Math.ceil(Math.abs(pixels)/60));
   for(let i=0;i<steps;i++){mx+=pixels/steps;await page.mouse.move(mx,my);await sleep(18)}
   await sleep(150);await page.keyboard.down('w');await sleep(Math.max(60,(distance-4.3)/5.4*1000));await page.keyboard.press('Space');await sleep(750);await page.keyboard.up('w');await sleep(260);
   s=await read();landings.push({target:index+1,...s});check(s.falls===0&&s.grounded,'Normal-input landing '+(index+1)+' succeeds');
   if(index<level.pads.length-1)check(s.pad===index+1,'HUD correctly identifies pad '+(index+1));
   if(index===0)await shot('03-first-landing.png');if(index===1)await shot('04-pad-two.png');if(index===4)await shot('05-mid-course.png');
  }
  await state('won');s=await read();check(s.victories===1&&s.jumps===route.length&&s.falls===0,'Extended course completes with zero falls');check(!(await page.evaluate(()=>!!document.pointerLockElement)),'Victory releases the mouse');await shot('06-victory.png');
  const won=await read();await page.keyboard.press('Space');await sleep(250);s=await read();check(s.victories===1&&JSON.stringify(s.position)===JSON.stringify(won.position),'Victory fires once and freezes gameplay');
  await click(640,350);await state('playing');await sleep(350);s=await read();check(s.level===2&&s.has_bat&&s.frogs_remaining===6&&s.swings===0,'Next level button starts Frog river with the bat and six frogs');
  check(s.player_name==='Pip'&&s.hoodie==='f3cc58','Next level preserves the customized adventurer');
  await page.keyboard.press('Escape');await state('paused');await click(640,541);await state('title');await click(1110,518);await click(220,565);await state('playing');await sleep(350);s=await read();check(s.level===1&&s.victories===0&&s.jumps===0&&s.pad===0&&s.falls===0&&s.grounded,'Returning to the lagoon starts a fresh session');
  await page.keyboard.press('Escape');await state('paused');await click(640,413);await state('playing');check((await read()).pad===0,'Pause menu Start over works');
  await page.keyboard.press('Escape');await state('paused');await click(640,541);await state('title');check((await read()).state==='title','Back to title works');
  await page.setViewportSize({width:1024,height:640});await sleep(350);await shot('10-small-desktop.png');
  const fit=await page.evaluate(()=>({width:innerWidth,height:innerHeight,scrollWidth:document.documentElement.scrollWidth,scrollHeight:document.documentElement.scrollHeight}));check(fit.width===fit.scrollWidth&&fit.height===fit.scrollHeight,'Small desktop viewport has no page overflow');
  await page.setViewportSize({width:1280,height:720});await sleep(200);
  check(errors.length===0,'Browser console has no script or engine errors');
  await fs.writeFile(path.join(ROOT,'docs/playthrough.json'),JSON.stringify(landings,null,2));
  await fs.writeFile(path.join(ROOT,'docs/browser-test-results.json'),JSON.stringify({checks,errors,environment,fps,straight,diagonal,landings},null,2));
  console.log('RESULT:',checks.length,'checks passed. FPS samples:',fps,'Environment:',JSON.stringify(environment));
 } catch(e) {await shot('test-failure.png').catch(()=>{});console.error('STATE:',await read().catch(()=>null),'ERRORS:',errors);throw e}
 finally {await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
