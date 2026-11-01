/* Real random outcomes, normal input only; no seed override or game-state setters. */
const {chromium}=require('playwright');
const fs=require('node:fs/promises');
const assert=require('node:assert/strict');
const path=require('node:path');
const ROOT=path.resolve(__dirname,'..');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=metal']});
 const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:1});
 const checks=[],errors=[],attempts=[],skillLandings=[];let won=false,sawSink=false,sawHold=false,mx=640,my=360,sinkProbes=0;
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const read=()=>page.evaluate(()=>window.lilyPadState);
 const check=(ok,text)=>{assert(ok,text);checks.push(text);console.log('PASS:',text)};
 const state=x=>page.waitForFunction(x=>window.lilyPadState?.state===x,x,{timeout:6000});
 const click=async(x,y)=>{await page.mouse.click(x,y);mx=x;my=y;await sleep(200)};
 const shot=name=>page.screenshot({path:path.join(ROOT,'docs',name),scale:'css'});
 const aim=async(target)=>{const s=await read(),angle=Math.atan2(-(target[0]-s.position[0]),-(target[1]-s.position[2]));const diff=((angle-s.yaw+Math.PI*3)%(Math.PI*2))-Math.PI,pixels=-diff/.0026,steps=Math.max(1,Math.ceil(Math.abs(pixels)/60));for(let i=0;i<steps;i++){mx+=pixels/steps;await page.mouse.move(mx,my);await sleep(18)}await sleep(150)};
 const jumpTo=async(target)=>{await aim(target);const s=await read(),distance=Math.hypot(target[0]-s.position[0],target[1]-s.position[2]);await page.keyboard.down('ArrowUp');await sleep(Math.max(60,(distance-4.3)/5.4*1000));await page.keyboard.press('Space');await sleep(750);await page.keyboard.up('ArrowUp');await sleep(240)};
 const precisionJumpTo=async(target)=>{
  await aim(target);const s=await read(),distance=Math.hypot(target[0]-s.position[0],target[1]-s.position[2]);
  await page.keyboard.down('ArrowUp');await sleep(Math.max(60,(distance-4.3)/5.4*1000));await page.keyboard.press('Space');
  for(let i=0;i<18;i++){
   await sleep(50);const now=await read();
   if(Math.hypot(target[0]-now.position[0],target[1]-now.position[2])<1.15){await page.keyboard.up('ArrowUp');break}
  }
  await page.keyboard.up('ArrowUp');await sleep(650);
 };
 try{
  await page.goto(process.env.GAME_URL||'http://127.0.0.1:8765/?qa');await page.waitForSelector('#loading',{state:'detached'});await state('title');
  await click(1110,638);let s=await read();check(s.level===3&&s.chance_pads.length===2,'Third title option selects Lucky lagoon');await shot('28-lucky-title.png');
  await click(220,565);await state('playing');await sleep(550);await page.mouse.move(mx,my);await sleep(250);await shot('29-yellow-frog-spawn.png');
  check((await read()).chance_rolls===0,'Yellow pads remain unresolved until contact');
  // Complete the permanent route using ordinary controls, before sampling luck.
  // Telemetry is read-only; no seeds, forced outcomes, or teleports in the browser.
  s=await read();check(s.bypass_pads.length===6,'Six smaller permanent pads offer a path around both yellow frogs');
  const bypass=s.bypass_pads.map(p=>[p.position[0],p.position[2]]);
  const skillRoute=[...bypass.slice(0,3),[1.8,-11.2],...bypass.slice(3),[2,-22.2],[2,-28.7]];
  for(let i=0;i<skillRoute.length;i++){
   await precisionJumpTo(skillRoute[i]);s=await read();skillLandings.push(s);
   check(s.grounded&&s.falls===0&&Math.hypot(s.position[0]-skillRoute[i][0],s.position[2]-skillRoute[i][1])<1.4,'Skill-route landing '+(i+1)+' reaches solid ground without a retry');
   check(s.chance_rolls===0&&s.chance_pads.every(p=>!p.resolved),'Skill-route landing '+(i+1)+' does not depend on a random pad');
   if(i===1){await shot('49-skill-route-small-pads.png');await page.keyboard.press('Escape');await state('paused');const before=(await read()).position;await sleep(500);check(JSON.stringify((await read()).position)===JSON.stringify(before),'Pause holds the player on a small precision pad');await click(640,350);await state('playing');await sleep(500)}
   if(i===4)await shot('50-skill-route-second-branch.png');
  }
  check(s.state==='won'&&s.victories===1&&s.chance_rolls===0&&s.falls===0,'A full nine-jump crossing wins with zero random rolls and zero falls');
  await shot('51-skill-route-victory.png');
  await click(640,350);await state('playing');await sleep(550);
  const route=[[0,-5.7],[1.8,-11.2],[.2,-16.7],[2,-22.2],[2,-28.7]];
  for(let attempt=1;attempt<=24&&!won;attempt++){
   const before=await read();const log={attempt,landings:[]};attempts.push(log);
   for(let i=0;i<route.length;i++){
    await jumpTo(route[i]);s=await read();log.landings.push(s);
    if(s.falling_through||s.falls>before.falls||s.state==='splash'){
     await state('splash');s=await read();
     sawSink=true;check(s.chance_sinks===before.chance_sinks+1&&s.falls===before.falls+1,'An unlucky yellow landing causes one water fall');await shot('30-unlucky-pad.png');
     await state('playing');await sleep(350);s=await read();check(s.chance_pads.every(p=>!p.resolved&&!p.collapsed),'Retry resets both yellow pads for fresh rolls');break;
    }
    check(s.grounded&&s.health===100&&!s.poisoned,'Level 3 landing '+(i+1)+' is supported and never poisonous');
    if(i===0||i===2){
     const pad=s.chance_pads.find(p=>p.pad===i+1);check(pad?.resolved&&!pad.collapsed,'Yellow pad '+(i+1)+' rolled solid');
     if(!sawHold){sawHold=true;await shot('31-yellow-pad-holds.png');const rolls=s.chance_rolls;await sleep(800);await page.keyboard.press('Space');await sleep(1100);s=await read();check(s.chance_rolls===rolls&&s.falls===before.falls,'Waiting and jumping again do not reroll a solid yellow pad')}
    }
    if(s.state==='won'){won=true;break}
   }
  }
  check(won,'A complete five-gap Lucky lagoon crossing succeeds with real random rolls');
  await shot('32-lucky-victory.png');s=await read();check(s.victories===1&&s.chance_pads.every(p=>p.resolved&&!p.collapsed),'Victory follows two held yellow pads');
  await click(640,350);await state('playing');await sleep(350);s=await read();check(s.level===3&&s.chance_rolls===0&&s.chance_pads.every(p=>!p.resolved),'Final-level replay resets both outcomes and counters');
  // A first-try win is valid. Sample fresh attempts to also exercise browser sinking.
  for(let probe=0;probe<12&&!sawSink;probe++){
   sinkProbes++;const before=await read();await jumpTo(route[0]);s=await read();
   if(s.falling_through||s.falls>before.falls||s.state==='splash'){
    await state('splash');s=await read();sawSink=true;
    check(s.chance_sinks===before.chance_sinks+1&&s.falls===before.falls+1,'An unlucky yellow landing causes one water fall');await shot('30-unlucky-pad.png');
    await state('playing');await sleep(350);s=await read();check(s.chance_pads.every(p=>!p.resolved&&!p.collapsed),'Retry resets both yellow pads for fresh rolls');
   }else{check(s.grounded&&s.chance_pads[0].resolved&&!s.chance_pads[0].collapsed,'A fresh yellow-pad roll may also stay solid');await page.keyboard.press('r');await sleep(400)}
  }
  await page.keyboard.press('Escape');await state('paused');await click(640,541);await state('title');await page.setViewportSize({width:1024,height:640});await sleep(250);await shot('33-three-levels-small.png');
  const fit=await page.evaluate(()=>innerWidth===document.documentElement.scrollWidth&&innerHeight===document.documentElement.scrollHeight);check(fit,'Three level choices fit the smaller desktop viewport');check(errors.length===0,'Lucky lagoon has no browser or engine errors');
  await fs.writeFile(path.join(ROOT,'docs/lucky-browser-results.json'),JSON.stringify({checks,errors,skillLandings,sawSink,sawHold,attempts,sinkProbes},null,2));console.log('RESULT:',checks.length,'checks passed across one skill crossing,',attempts.length,'shortcut attempts and',sinkProbes,'sink probes. Sink observed:',sawSink);
 }catch(e){await shot('lucky-test-failure.png').catch(()=>{});console.error('STATE:',await read().catch(()=>null),'ERRORS:',errors);throw e}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
