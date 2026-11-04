const loadLevel=require('./level_routes.cjs');
/* Level 2 acceptance: read-only telemetry, normal mouse/keyboard input. */
const { chromium } = require('playwright');
const fs = require('node:fs/promises');
const assert = require('node:assert/strict');
const path = require('node:path');
const ROOT = path.resolve(__dirname, '..');
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
 const browser = await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=metal']});
 const context = await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
 const page = await context.newPage();
 const errors=[],checks=[],landings=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const read=()=>page.evaluate(()=>window.lilyPadState);
 const shot=name=>page.screenshot({path:path.join(ROOT,'docs',name),scale:'css'});
 const check=(ok,text)=>{assert(ok,text);checks.push(text);console.log('PASS:',text)};
 const state=expected=>page.waitForFunction(x=>window.lilyPadState?.state===x,expected,{timeout:6000});
 const click=async(x,y)=>{await page.mouse.click(x,y);await sleep(200)};
 let mx=640,my=360;
 const aim=async(target)=>{
  const s=await read(),angle=Math.atan2(-(target[0]-s.position[0]),-(target[1]-s.position[2]));
  const diff=((angle-s.yaw+Math.PI*3)%(Math.PI*2))-Math.PI,pixels=-diff/.0026,steps=Math.max(1,Math.ceil(Math.abs(pixels)/60));
  for(let i=0;i<steps;i++){mx+=pixels/steps;await page.mouse.move(mx,my);await sleep(18)}
  await sleep(160);
 };
 const jumpTo=async(target)=>{
  await aim(target);const s=await read(),distance=Math.hypot(target[0]-s.position[0],target[1]-s.position[2]);
  await page.keyboard.down('w');await sleep(Math.max(60,(distance-4.3)/5.4*1000));
  await page.keyboard.press('Space');await sleep(750);await page.keyboard.up('w');await sleep(280);
 };
 try {
  await page.goto(process.env.GAME_URL || 'http://127.0.0.1:8765/?qa');
  await page.waitForSelector('#loading',{state:'detached'});await state('title');
  await shot('11-level-select.png');
  await click(1110,578);let s=await read();
  check(s.level===2&&s.has_bat&&s.frogs_remaining===6,'Title shortcut selects Frog river with six frogs and a bat');
  await shot('12-frog-title.png');
  await click(220,565);await state('playing');await sleep(550);
  s=await read();check(s.swings===0&&s.grounded,'Starting Level 2 does not spend an attack');
  check(s.decoys.length===4&&s.decoys.every(p=>p.red_frog&&!p.collapsed),'Four red-frog decoys are visible beside the safe route');
  await shot('13-frog-spawn.png');
  await page.mouse.move(mx,my);await sleep(250);
  await shot('20-red-frog-decoys.png');
  // Intentionally choose the red-frog branch using arrow keys, then recover.
  const decoy=[s.decoys[0].position[0],s.decoys[0].position[2]];
  await aim(decoy);s=await read();
  const trapDistance=Math.hypot(decoy[0]-s.position[0],decoy[1]-s.position[2]);
  await page.keyboard.down('ArrowUp');await sleep(Math.max(60,(trapDistance-4.3)/5.4*1000));await page.keyboard.press('Space');
  await page.waitForFunction(()=>window.lilyPadState?.decoy_trips===1,null,{timeout:5000});await page.keyboard.up('ArrowUp');
  s=await read();check(s.decoys[0].collapsed&&s.falling_through,'A real arrow-key jump onto the red-frog pad collapses it');
  await shot('21-decoy-collapse.png');
  await page.keyboard.press('Space');await state('splash');s=await read();
  check(s.falls===1&&s.jumps===1&&s.pad===0,'The trap causes one water fall and cannot be escaped by jumping again');
  check(s.hits===0&&s.frogs_remaining===6,'Red-frog trap contact does not count as defeating a green frog');
  await shot('22-decoy-splash.png');
  await page.keyboard.press('Escape');await state('paused');const trappedPause=await read();await sleep(300);s=await read();
  check(JSON.stringify(s.decoys)===JSON.stringify(trappedPause.decoys),'Pause freezes a collapsing decoy during the splash');
  await click(640,350);await state('playing');await sleep(350);s=await read();
  check(s.falls===1&&s.decoys.every(p=>!p.collapsed)&&s.grounded&&!s.falling_through,'Retry restores the decoys and normal movement at spawn');
  await page.keyboard.press('r');await sleep(500);s=await read();
  check(s.decoy_trips===0&&s.falls===0,'Restart clears trap failures');
  await page.mouse.down();await sleep(1000);await page.mouse.up();await sleep(180);
  s=await read();check(s.state==='playing'&&s.swings===1&&s.hits===0,'Holding left click produces one swing, no distant damage, and no pause');
  await page.keyboard.down('f');await sleep(1000);await page.keyboard.up('f');await sleep(180);
  check((await read()).swings===2,'Holding F does not automatically repeat a swing');
  await page.keyboard.press('r');await sleep(500);
  await page.keyboard.press('f');await sleep(30);await page.keyboard.press('Escape');await state('paused');
  const frozen=await read();await sleep(350);s=await read();
  check(s.swing_remaining===frozen.swing_remaining&&JSON.stringify(s.position)===JSON.stringify(frozen.position),'Escape freezes the bat swing and character');
  await click(640,350);await state('playing');await sleep(700);
  check((await read()).swing_remaining===0,'Resume completes the frozen swing');
  await page.keyboard.press('r');await sleep(500);
  // Poison, cure, and death are exercised through ordinary landings and input.
  await jumpTo([0,-4.85]);s=await read();
  check(s.poisoned&&s.health<100&&s.poison_source_pad===1,'Landing on a green-frog pad applies poison');
  const firstHealth=s.health;await sleep(700);s=await read();
  check(s.health<firstHealth-10,'Poison continuously drains the visible health percentage');
  await shot('23-poisoned.png');
  await page.keyboard.press('Escape');await state('paused');const pausedHealth=(await read()).health;await sleep(400);
  check((await read()).health===pausedHealth,'Pause freezes poison damage');
  await click(640,350);await state('playing');await sleep(250);
  await aim([0,-5.95]);await page.keyboard.press('f');await sleep(500);s=await read();
  check(s.health===100&&!s.poisoned&&s.frogs_remaining===5,'Defeating the poisoning frog fully heals and cures the character');
  await shot('24-health-restored.png');
  await jumpTo([-1.45,-9.75]);s=await read();check(s.poisoned&&s.poison_source_pad===2,'A different living frog can poison again');
  await page.waitForFunction(()=>window.lilyPadState?.health<=25,null,{timeout:6000});await shot('25-low-health.png');
  await state('poison_defeat');s=await read();
  check(s.health===0&&s.poison_deaths===1&&s.falls===0,'Zero health causes a distinct poison death once');
  await shot('26-poison-defeat.png');
  await page.keyboard.press('f');await sleep(180);s=await read();check(s.health===0&&s.frogs_remaining===5,'A dead character cannot heal with a late attack');
  await state('playing');await sleep(250);s=await read();
  check(s.health===100&&!s.poisoned&&s.grounded&&s.frogs_remaining===6,'Poison retry restores full health and all frogs');
  await shot('27-healthy-retry.png');
  await page.keyboard.press('r');await sleep(500);
  // Cross via normal jumps, land near each frog, face it, and swing.
  const level=loadLevel('frog_river');
  const route=level.frogs.map(index=>[level.pads[index][0],level.pads[index][1]-.25]);
  for(let i=0;i<route.length;i++){
   for(let pad=(i===0?1:level.frogs[i-1]+1);pad<level.frogs[i];pad++)await jumpTo(level.pads[pad]);
   const frog=route[i];s=await read();
   const dx=frog[0]-s.position[0],dz=frog[1]-s.position[2],distance=Math.hypot(dx,dz);
   const landing=[frog[0]-dx/distance*1.1,frog[1]-dz/distance*1.1];
   await jumpTo(landing);s=await read();
   console.log('LANDING',i+1,JSON.stringify(s));
   check(s.state==='playing'&&s.falls===0&&s.grounded,'Frog pad '+(i+1)+' reached with normal movement');
   await aim(frog);s=await read();
   const gap=Math.hypot(frog[0]-s.position[0],frog[1]-s.position[2]);
   if(gap>1.8){await page.keyboard.down('w');await sleep((gap-1.65)/5.4*1000+70);await page.keyboard.up('w');await sleep(200)}
   if(i===0)await shot('14-first-frog.png');
   if(i%2===0)await page.keyboard.press('f');else await page.mouse.click(mx,my);
   if(i===0){await sleep(160);await shot('15-bat-impact.png')}
   await sleep(600);s=await read();landings.push(s);
   check(s.frogs_remaining===5-i&&s.hits===i+1,'Bat defeats frog '+(i+1)+' and updates the counter once');
   check(s.health===100&&!s.poisoned,'Defeating frog '+(i+1)+' restores full health');
   if(i===2)await shot('16-frog-mid-course.png');
  }
  await shot('17-river-clear.png');
  await jumpTo(level.flag);await state('won');s=await read();
  check(s.level===2&&s.victories===1&&s.frogs_remaining===0&&s.falls===0,'Complete river crossing defeats all six frogs without falling');
  check(s.decoy_trips===0&&s.decoys.length===4&&s.decoys.every(p=>!p.collapsed),'The safe route wins with every red warning frog left alone');
  check(!(await page.evaluate(()=>!!document.pointerLockElement)),'Level 2 victory releases the mouse');
  await shot('18-frog-victory.png');
  await click(640,350);await state('playing');await sleep(400);s=await read();
  check(s.level===3&&s.chance_pads.length===7&&!s.has_bat&&s.health===100&&!s.poisoned,'Next level advances from Frog river into Lucky lagoon');
  await page.keyboard.press('Escape');await state('paused');await click(640,541);await state('title');
  await click(1110,518);s=await read();check(s.level===1&&!s.has_bat&&s.frogs_remaining===0,'Title can return to the original lagoon without combat');
  await page.setViewportSize({width:1024,height:640});await sleep(300);await shot('19-level-select-small.png');
  const fit=await page.evaluate(()=>[innerWidth===document.documentElement.scrollWidth,innerHeight===document.documentElement.scrollHeight]);
  check(fit.every(Boolean),'Level selection fits a small desktop viewport');
  check(errors.length===0,'Combat browser run has no script or engine errors');
  await fs.writeFile(path.join(ROOT,'docs/combat-browser-results.json'),JSON.stringify({checks,errors,landings,final:s},null,2));
  console.log('RESULT:',checks.length,'checks passed');
 } catch(e) {await shot('combat-test-failure.png').catch(()=>{});console.error('STATE:',await read().catch(()=>null),'ERRORS:',errors);throw e}
 finally {await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
