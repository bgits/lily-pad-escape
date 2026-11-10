/* Full WebGL playthrough: read-only QA telemetry; real keyboard/mouse controls. */
const {chromium}=require('playwright');
const fs=require('node:fs/promises');
const assert=require('node:assert/strict');
const path=require('node:path');
const ROOT=path.resolve(__dirname,'..');
const PREFIX=process.env.RAPIDS_ARTIFACT_PREFIX||'hoverboard';
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:process.env.PLAYWRIGHT_HEADLESS !== 'false',channel:process.env.PLAYWRIGHT_CHANNEL || 'chromium',args:['--use-angle=metal']});
 const context=await browser.newContext({viewport:{width:1280,height:720}});
 const page=await context.newPage();
 const focus=async()=>{await page.bringToFront();await delay(100)};
 const checks=[],errors=[],runs=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const read=()=>page.evaluate(()=>window.lilyPadState);
 const shot=name=>page.screenshot({path:path.join(ROOT,'docs',PREFIX+'-'+name+'.png')});
 const check=(ok,msg)=>{assert(ok,msg);checks.push(msg);console.log('PASS:',msg)};
 const wait=state=>page.waitForFunction(s=>window.lilyPadState?.state===s,state,{timeout:15000});
 const hazards=[[0,95,-1],[0,185,1],[2,55,-1],[4,55,1],[8,90,-.9],[8,210,.9],[8,320,-.9],[9,110,-1],[11,55,1],[11,135,-1],[13,55,1]];
 let steering=0;
 async function steer(axis){
  if(axis===steering)return;
  if(steering)await page.keyboard.up(steering<0?'a':'d');
  if(axis)await page.keyboard.down(axis<0?'a':'d');
  steering=axis;
 }
 async function traverse(fast){
  await page.keyboard.press('r');await delay(250);await page.keyboard.down('w');
  const start=Date.now(),fps=[],snapshots=[],taken=new Set();let peak=0,lastLeg=-1;
  while(Date.now()-start<130000){
   let s=await read();
   if(s.state==='paused'){
    console.log('FOCUS PAUSE: bringing browser back to foreground');
    await steer(0);await page.keyboard.up('w');await focus();await page.mouse.click(640,350);await wait('playing');await page.keyboard.down('w');s=await read();
   }
   if(s.state==='won')break;
   assert(s.state==='playing'&&s.falls===0,'Route must remain playable without falls: '+JSON.stringify(s));
   let target=0;
   for(const [leg,d,lateral] of hazards)if(leg===s.board_leg&&d-s.board_distance<35&&d-s.board_distance> -10)target=-Math.sign(lateral)*(leg===8?1.6:2.1);
   if(s.board_leg===2&&s.board_distance<50)target=2.6;
   if(fast&&s.board_leg===6&&s.board_distance>25&&s.board_distance<95)target=1.3;
   if(s.board_leg===13&&s.board_distance>10&&s.board_distance<65)target=-2.6;
   if(s.board_leg===4&&s.board_distance>s.board_leg_length-30)target=fast?-3:3;
   if(s.board_leg===5)target=fast?-8:8;
   // Predict stopping distance so digital keys can settle on a narrow lane.
   const error=target-s.board_lateral;
   const stopping=s.board_lateral_velocity*Math.abs(s.board_lateral_velocity)/44+s.board_lateral_velocity*.12;
   const axis=Math.abs(error-stopping)<.25?0:Math.sign(error-stopping);
   await steer(axis);
   peak=Math.max(peak,s.board_speed);fps.push(s.fps);
   if(s.board_leg!==lastLeg){console.log('LEG',fast,s.board_leg,s.rapids_time,s.board_lateral);lastLeg=s.board_leg}
   const captures=[['rolling',0,120],['first-flight',1,8],['loop',3,60],['fork',5,8],['branch',6,30],['merge',7,8],['spiral',8,160],['canyon-flight',10,12],['home',13,80],['finish',13,120]];
   for(const [name,leg,d] of captures)if(s.board_leg===leg&&s.board_distance>d&&!taken.has(name)){
    taken.add(name);snapshots.push(s);if(!fast||name==='branch')await shot((fast?'fast-':'wide-')+name);
   }
   await delay(35);
  }
  await steer(0);await page.keyboard.up('w');await wait('won');const result=await read();
  check(result.falls===0,(fast?'Fast':'Wide')+' route completes using normal browser controls');
  check(result.board_inverted&&result.board_spiral,'Actual upside-down loop and full spiral complete in the browser');
  check(result.launches===3,'All three gaps use airborne launches');
  check(peak>24&&peak<=34.1,'Browser hoverboard speed stays fast and bounded');
  check(result.board_route===(fast?'fast':'wide'),'Steering selects the intended branch');
  if(fast)check(result.firefly_masks[4]===7,'All three Rapids fireflies are reachable while riding');
  await shot(fast?'fast-victory':'wide-victory');
  runs.push({fast,seconds:result.rapids_time,peak,fps,snapshots});
  console.log('RUN',fast,result.rapids_time,peak);
 }
 try{
  await page.goto('http://127.0.0.1:8765/?qa');await page.waitForSelector('#loading',{state:'detached'});await wait('title');await focus();
  await page.mouse.click(1110,662);await delay(300);check((await read()).level===5,'Fifth menu option selects River Rapids');await shot('title');
  await page.mouse.click(220,565);await wait('playing');await delay(250);await shot('start');
  await page.keyboard.press('Escape');await wait('paused');let before=await read();await delay(350);let after=await read();
  check(JSON.stringify(before.position)===JSON.stringify(after.position)&&before.rapids_time===after.rapids_time&&before.rapids_wave===after.rapids_wave,'Pause freezes the rider, wave and timer');
  await page.mouse.click(640,350);await wait('playing');
  if(process.env.PLAYWRIGHT_HEADLESS==='false'){
  const other=await context.newPage();await other.goto('about:blank');await other.bringToFront();await wait('paused');
  check((await read()).state==='paused','Changing browser tabs safely pauses the automatic-camera ride');
  await other.close();await focus();await page.mouse.click(640,350);await wait('playing');
  }
  await traverse(false);
  await page.mouse.click(640,375);await wait('playing');
  await traverse(true);
  check(runs[1].seconds<runs[0].seconds,'Narrow shortcut rewards precision with a faster finish');
  const saved=await read();await page.reload();await wait('title');await focus();await page.mouse.click(1110,662);await delay(250);const restored=await read();
  check(restored.rapids_best_time===saved.rapids_best_time&&restored.rapids_best_time>0,'Best time persists across browser reload');
  await page.setViewportSize({width:1024,height:640});await delay(300);await shot('small-title');
  await page.setViewportSize({width:1280,height:720});
  await page.evaluate(()=>localStorage.setItem('lily-pad-escape.rapids.v2',JSON.stringify({version:2,distance:'bad',time:-1})));
  await page.reload();await wait('title');await focus();
  check((await read()).rapids_best===0&&(await read()).rapids_best_time===0,'Malformed records fall back safely');
  await page.addInitScript(()=>{const set=Storage.prototype.setItem;Storage.prototype.setItem=function(k,v){if(k==='lily-pad-escape.rapids.v2')throw new DOMException('Test storage denial','QuotaExceededError');return set.call(this,k,v)}});
  await page.reload();await wait('title');await focus();await page.mouse.click(1110,662);await delay(200);await page.mouse.click(220,565);await wait('playing');
  await page.keyboard.down('w');await page.keyboard.down('Shift');await delay(1700);await page.keyboard.up('Shift');
  const boosted=await read();check(boosted.board_speed>30&&boosted.board_energy<40,'Boost changes speed and consumes energy with real keyboard input');
  await page.keyboard.up('w');await page.keyboard.down('s');await delay(900);await page.keyboard.up('s');
  check((await read()).board_speed<16,'Brake reduces hoverboard speed');
  await page.keyboard.press('r');await delay(250);
  let denied=await read();check(!denied.rapids_saved&&denied.rapids_best>5,'Blocked storage retains a session record and reports failure');
  await page.reload();await wait('title');check((await read()).rapids_best===0,'Blocked writes do not falsely claim persistence');
  check(errors.length===0,'No browser script or engine errors');
  await fs.writeFile(path.join(ROOT,'docs/'+PREFIX+'-browser-results.json'),JSON.stringify({checks,errors,runs},null,2));
 }catch(e){await shot('test-failure').catch(()=>{});console.error('STATE',await read().catch(()=>null),'ERRORS',errors);throw e}
 finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
