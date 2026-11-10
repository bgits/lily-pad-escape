const loadLevel=require('./level_routes.cjs');
/* All nine fireflies through normal controls. No teleports or seeded outcomes. */
const {chromium}=require('playwright');
const fs=require('node:fs/promises');
const path=require('node:path');
const assert=require('node:assert/strict');
const ROOT=path.resolve(__dirname,'..');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:process.env.PLAYWRIGHT_HEADLESS !== "false",channel:process.env.PLAYWRIGHT_CHANNEL || 'chrome',args:['--use-angle=metal']});
 const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
 const page=await context.newPage();const checks=[],errors=[],landings=[];let mx=640,my=360;
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const read=()=>page.evaluate(()=>window.lilyPadState);
 const state=x=>page.waitForFunction(x=>window.lilyPadState?.state===x,x,{timeout:6000});
 const check=(ok,text)=>{assert(ok,text);checks.push(text);console.log('PASS:',text)};
 const shot=name=>page.screenshot({path:path.join(ROOT,'docs',name),scale:'css'});
 const click=async(x,y)=>{await page.mouse.click(x,y);mx=x;my=y;await sleep(200)};
 const aim=async target=>{
  for(let correction=0;correction<2;correction++){
   const s=await read(),angle=Math.atan2(-(target[0]-s.position[0]),-(target[1]-s.position[2]));
   const diff=((angle-s.yaw+Math.PI*3)%(Math.PI*2))-Math.PI;
   if(Math.abs(diff)<.015)return;
   const pixels=-diff/.0026,steps=Math.max(1,Math.ceil(Math.abs(pixels)/60));
   for(let i=0;i<steps;i++){mx+=pixels/steps;await page.mouse.move(mx,my);await sleep(18)}
   await sleep(160);
  }
 };
 const jumpTo=async(target,label)=>{
  await aim(target);let s=await read();const before=s.falls,distance=Math.hypot(target[0]-s.position[0],target[1]-s.position[2]);
  await page.keyboard.down('ArrowUp');await sleep(Math.max(60,(distance-4.3)/5.4*1000));await page.keyboard.press('Space');
  for(let i=0;i<18;i++){await sleep(50);s=await read();if(Math.hypot(target[0]-s.position[0],target[1]-s.position[2])<1.15){await page.keyboard.up('ArrowUp');break}}
  await page.keyboard.up('ArrowUp');await sleep(650);s=await read();
  landings.push({label,state:s});check(s.grounded&&s.falls===before&&s.state!=='splash',label+' lands safely');
 };
 const collectCheck=async id=>{await page.waitForFunction(id=>window.lilyPadState?.fireflies[id].collected,id,{timeout:2500});const s=await read();check(s.fireflies_saved&&s.fireflies[id].collected,'Level '+s.level+' firefly '+(id+1)+' is collected and saved')};
 const movingTrip=async returnTo=>{
  let s=await read();const home=s.drifting_pads[0].home;
  await aim([home[0],home[2]]);
  await page.waitForFunction(()=>window.lilyPadState?.drifting_pads[0].clock%8<.25,null,{timeout:11000});
  await jumpTo([home[0],home[2]],'Level '+s.level+' drifting-pad jump');await collectCheck(0);
  const before=(await read()).position;await sleep(1800);s=await read();
  check(s.grounded&&s.falls===0&&Math.hypot(s.position[0]-before[0],s.position[2]-before[2])>1,'Level '+s.level+' drifting pad carries the idle player');
  await shot('52-drifting-pad-level-'+s.level+'.png');
  if(s.level===1){
   await page.keyboard.press('Escape');await state('paused');const paused=await read();await sleep(500);s=await read();
   check(JSON.stringify(s.drifting_pads)===JSON.stringify(paused.drifting_pads)&&JSON.stringify(s.position)===JSON.stringify(paused.position),'Browser pause freezes the pad and rider exactly');
   await click(640,350);await state('playing');await sleep(500);
  }
  await aim(returnTo);
  await page.waitForFunction(()=>window.lilyPadState?.drifting_pads[0].clock%8<.25,null,{timeout:11000});
  await jumpTo(returnTo,'Return from the drifting pad');
 };
 const defeat=async (id,pad)=>{
  await jumpTo([pad[0],pad[1]+1.0],'Frog '+(id+1)+' approach');
  for(let attempt=0;attempt<3;attempt++){
   let s=await read();if(!s.frogs[id].alive)break;
   const frog=s.frogs[id].position;await aim([frog[0],frog[2]]);
   s=await read();const gap=Math.hypot(frog[0]-s.position[0],frog[2]-s.position[2]);
   await page.keyboard.down('ArrowUp');await sleep(Math.max(90,(gap-1.5)/5.4*1000+70));await page.keyboard.up('ArrowUp');await sleep(160);
   await page.keyboard.press('f');await sleep(520);
  }
  const s=await read();check(!s.frogs[id].alive&&s.health===100&&!s.poisoned,'Aimed swing defeats hopping frog '+(id+1)+' and heals');
 };
 try{
  await page.goto(process.env.GAME_URL||'http://127.0.0.1:8765/?qa');await page.waitForSelector('#loading',{state:'detached'});await state('title');await page.bringToFront();
  check((await read()).firefly_masks.every(x=>x===0),'Isolated browser starts with an empty collection');
  await shot('53-fireflies-title.png');await click(220,565);await state('playing');await sleep(550);
  await jumpTo([0,-5.35],'Sunlit first pad');await movingTrip([0,-5.35]);
  await jumpTo([1.5,-9.8],'Sunlit second pad');await jumpTo([-2.2,-12.3],'Sunlit hidden flower pad');await collectCheck(1);await shot('54-hidden-firefly-branch.png');
  await jumpTo([1.5,-9.8],'Return to Sunlit route');
  const sunlit=loadLevel('sunlit_lagoon'),river=loadLevel('frog_river'),lucky=loadLevel('lucky_lagoon');
  for(const p of sunlit.pads.slice(3))await jumpTo(p,'Sunlit crossing');
  await jumpTo(sunlit.fireflies[2],'Sunlit shore firefly');await collectCheck(2);await jumpTo(sunlit.flag,'Sunlit flag');await state('won');
  check((await read()).firefly_masks[0]===7,'Sunlit Lagoon completes with all three fireflies');
  await click(640,350);await state('playing');await sleep(550);
  await defeat(0,[0,-5.7]);await movingTrip([0,-5.7]);await defeat(1,[-1.8,-10.7]);await jumpTo(river.pads[3],'Frog River rest pad');
  await jumpTo([5.3,-15.7],'Frog River flower branch');await collectCheck(1);await jumpTo([.8,-15.7],'Return to Frog River');
  for(let i=4;i<river.pads.length;i++){const frog=river.frogs.indexOf(i);if(frog>=0)await defeat(frog,river.pads[i]);else await jumpTo(river.pads[i],'Frog River crossing');}
  await jumpTo(river.fireflies[2],'Frog River shore firefly');await collectCheck(2);await jumpTo(river.flag,'Frog River flag');await state('won');
  check((await read()).firefly_masks[1]===7,'Frog River completes with all three fireflies');
  await click(640,350);await state('playing');await sleep(550);
  const bypass=(await read()).bypass_pads.map(p=>[p.position[0],p.position[2]]);
  for(const p of bypass.slice(0,3))await jumpTo(p,'Lucky Lagoon first solid branch');
  await jumpTo([1.8,-11.2],'Lucky Lagoon rest pad');await movingTrip([1.8,-11.2]);
  for(const p of bypass.slice(3,6))await jumpTo(p,'Lucky Lagoon second solid branch');
  await jumpTo([-4.9,-23.6],'Lucky Lagoon hidden flower pad');await collectCheck(1);await jumpTo(bypass[5],'Return to solid branch');
  await jumpTo(lucky.pads[4],'Lucky Lagoon rest pad');
  for(let branch=0;branch<5;branch++){for(const p of bypass.slice(6+branch*2,8+branch*2))await jumpTo(p,'Lucky Lagoon solid bypass');const next=6+branch*2;if(next<lucky.pads.length)await jumpTo(lucky.pads[next],'Lucky Lagoon rest pad');}await jumpTo(lucky.fireflies[2],'Lucky Lagoon shore firefly');await collectCheck(2);
  await jumpTo(lucky.flag,'Lucky Lagoon flag');await state('won');let s=await read();
  check(s.firefly_masks.slice(0,3).every(x=>x===7),'All nine fireflies are reachable with normal controls');
  check(s.chance_rolls===0&&s.falls===0,'Lucky Lagoon collects everything and wins without random rolls or falls');
  await shot('55-all-fireflies-victory.png');await page.reload();await page.waitForSelector('#loading',{state:'detached'});await state('title');await page.bringToFront();s=await read();
  check(s.firefly_masks.slice(0,3).every(x=>x===7)&&s.fireflies.every(f=>f.collected),'All nine pickups survive browser reload without duplicate spawns');
  await shot('56-saved-firefly-collection.png');await click(1110,558);s=await read();check(s.level===3&&s.fireflies.every(f=>f.collected),'Changing levels restores the correct saved collection');
  await page.setViewportSize({width:1024,height:640});await sleep(250);await shot('57-collection-small.png');
  check(await page.evaluate(()=>innerWidth===document.documentElement.scrollWidth&&innerHeight===document.documentElement.scrollHeight),'Collection UI fits a smaller viewport');
  check(errors.length===0,'Exploration playthrough has no browser or engine errors');
  await fs.writeFile(path.join(ROOT,'docs/exploration-browser-results.json'),JSON.stringify({checks,errors,landings,final:s},null,2));console.log('RESULT:',checks.length,'checks passed');
 }catch(e){await shot('exploration-test-failure.png').catch(()=>{});console.error('STATE:',JSON.stringify(await read().catch(()=>null)),'ERRORS:',errors);throw e}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
