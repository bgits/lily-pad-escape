/* Beginner course acceptance: real keyboard/mouse input and read-only telemetry. */
const {chromium}=require('playwright');
const fs=require('node:fs/promises');
const assert=require('node:assert/strict');
const path=require('node:path');
const ROOT=path.resolve(__dirname,'..');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({channel:'chromium',headless:process.env.PLAYWRIGHT_HEADLESS!=='false',args:['--use-angle=metal']});
 const context=await browser.newContext({viewport:{width:1280,height:720}});
 await context.addInitScript(()=>{
  if(!localStorage.getItem('lily.qa.glide-seeded')){
   localStorage.setItem('lily-pad-escape.fireflies.v1','[1,2,3,7]');
   localStorage.setItem('lily-pad-escape.rapids.v2',JSON.stringify({version:2,distance:2141.3743,time:83.5}));
   localStorage.setItem('lily-pad-escape.secret-perch.v1','1');
   localStorage.setItem('lily.qa.glide-seeded','1');
  }
 });
 const page=await context.newPage(),checks=[],errors=[],snapshots=[],fps=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const read=()=>page.evaluate(()=>window.lilyPadState);
 const state=s=>page.waitForFunction(v=>window.lilyPadState?.state===v,s,{timeout:15000});
 const shot=name=>page.screenshot({path:path.join(ROOT,'docs','glide-'+name+'.png')});
 const check=(ok,message)=>{assert(ok,message);checks.push(message);console.log('PASS:',message)};
 const select=async(i)=>{await page.mouse.click(1110,[454,506,558,610,662][i]);await delay(220)};
 try{
  await page.goto('http://127.0.0.1:8765/?qa');await state('title');await page.bringToFront();
  check(JSON.stringify((await read()).firefly_masks)==='[1,2,3,0,7]','Previous fourth-course collectibles migrate to Level 5');
  await select(4);let s=await read();check(s.level===5&&!s.rapids_beginner&&s.rapids_best_time===83.5,'Level 5 keeps the original harder course and saved time');
  await select(3);s=await read();check(s.level===4&&s.rapids_beginner&&s.rapids_best_time===0,'Level 4 has its own beginner course and empty record');await shot('title');
  await page.setViewportSize({width:1024,height:640});await delay(250);await shot('small-title');await page.setViewportSize({width:1280,height:720});await delay(200);
  await page.mouse.click(220,565);await state('playing');await page.keyboard.down('w');
  const taken=new Set(),start=Date.now();
  while(Date.now()-start<85000){
   s=await read();if(s.state==='won')break;
   assert(s.state==='playing'&&s.falls===0,'Beginner run must stay playable: '+JSON.stringify(s));
   fps.push(s.fps);
   for(const [name,leg,d] of [['hills',0,100],['flight',1,2],['loop',3,45],['spiral',5,65]]){
    if(s.board_leg===leg&&s.board_distance>d&&!taken.has(name)){taken.add(name);snapshots.push(s);await shot(name)}
   }
   if(s.board_leg===6&&s.board_distance>s.board_leg_length-8&&!taken.has('finish')){taken.add('finish');await shot('finish')}
   await delay(70);
  }
  await page.keyboard.up('w');await state('won');s=await read();
  check(s.falls===0&&s.rapids_time>35&&s.rapids_time<65,'Beginner course finishes in under 65 seconds without precision steering');
  check(s.board_inverted&&s.board_spiral&&s.launches===1,'Easy course retains the loop, spiral, and airborne gap');
  check(JSON.stringify(s.firefly_masks)==='[1,2,3,7,7]','All beginner fireflies collect while existing collections remain intact');
  const finishTime=s.rapids_time;await shot('victory');
  await page.mouse.click(640,375);await state('playing');s=await read();
  check(s.level===5&&!s.rapids_beginner&&s.rapids_best_time===83.5,'Next level moves from the easier fourth course to the harder fifth');
  await page.reload();await state('title');await select(3);s=await read();
  check(s.rapids_best_time===finishTime&&JSON.stringify(s.firefly_masks)==='[1,2,3,7,7]','Beginner time and migrated collections persist without repeated migration');
  await page.mouse.click(220,565);await state('playing');await page.keyboard.down('d');await delay(3000);await page.keyboard.up('d');s=await read();
  check(s.falls===0&&s.grounded&&s.board_lateral>5,'Protective rails catch sustained oversteering with normal keyboard input');await shot('rail');
  await page.keyboard.press('Escape');await state('paused');const before=await read();await delay(350);const after=await read();
  check(JSON.stringify(before.position)===JSON.stringify(after.position)&&before.rapids_wave===after.rapids_wave,'Pause freezes the beginner ride and chasing wave');
  await page.evaluate(()=>localStorage.removeItem('lily-pad-escape.river-glide.v1'));
  await page.addInitScript(()=>{const set=Storage.prototype.setItem;Storage.prototype.setItem=function(k,v){if(k==='lily-pad-escape.river-glide.v1')throw new DOMException('Test denial','QuotaExceededError');return set.call(this,k,v)}});
  await page.reload();await state('title');await select(3);await page.mouse.click(220,565);await state('playing');await delay(1500);await page.keyboard.press('r');await delay(250);s=await read();
  check(!s.rapids_saved&&s.rapids_best>10,'Denied beginner saves retain a session record with honest feedback');
  await page.reload();await state('title');await select(3);check((await read()).rapids_best===0,'Denied beginner records do not falsely persist');
  await select(4);check((await read()).rapids_best_time===83.5,'Beginner save failures do not damage the harder-course record');
  check(errors.length===0,'No browser script or engine errors');
  await fs.writeFile(path.join(ROOT,'docs/glide-browser-results.json'),JSON.stringify({checks,errors,finishTime,fps,snapshots},null,2));
 }catch(e){await shot('failure').catch(()=>{});console.error('STATE',await read().catch(()=>null),'ERRORS',errors);throw e}
 finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
