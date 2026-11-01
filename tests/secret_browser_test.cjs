/* Achievement acceptance through ordinary input. Telemetry is read-only. */
const {chromium}=require('playwright');
const fs=require('node:fs/promises');
const assert=require('node:assert/strict');
const path=require('node:path');
const ROOT=path.resolve(__dirname,'..');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=metal']});
 const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
 const page=await context.newPage();
 const checks=[],errors=[];let mx=640,my=360;
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const read=()=>page.evaluate(()=>window.lilyPadState);
 const check=(ok,text)=>{assert(ok,text);checks.push(text);console.log('PASS:',text)};
 const state=x=>page.waitForFunction(x=>window.lilyPadState?.state===x,x,{timeout:6000});
 const click=async(x,y)=>{await page.mouse.click(x,y);await sleep(220)};
 const shot=name=>page.screenshot({path:path.join(ROOT,'docs',name),scale:'css'});
 const aim=async(target)=>{const s=await read(),angle=Math.atan2(-(target[0]-s.position[0]),-(target[2]-s.position[2]));const diff=((angle-s.yaw+Math.PI*3)%(Math.PI*2))-Math.PI,pixels=-diff/.0026,steps=Math.max(1,Math.ceil(Math.abs(pixels)/60));for(let i=0;i<steps;i++){mx+=pixels/steps;await page.mouse.move(mx,my);await sleep(18)}await sleep(150)};
 const loaded=async()=>{await page.waitForSelector('#loading',{state:'detached'});await state('title');await sleep(250)};
 try{
  await page.goto(process.env.GAME_URL||'http://127.0.0.1:8765/?qa');await loaded();
  check(!(await read()).secret_unlocked,'A fresh browser starts with the secret locked');await shot('34-secret-locked.png');
  await click(220,565);await state('playing');await sleep(600);await page.mouse.move(mx,my);await sleep(220);
  let s=await read();check(!s.secret_unlocked&&s.grounded,'Spawning on the lily pad does not award the secret');
  const target=s.secret_perches.map(p=>p.position).sort((a,b)=>b[0]-a[0])[0];
  await aim(target);
  await page.keyboard.down('ArrowUp');await sleep(640);await page.keyboard.press('Space');await sleep(820);await page.keyboard.up('ArrowUp');await sleep(300);
  s=await read();console.log('PILLAR LANDING:',JSON.stringify(s));
  check(s.secret_unlocked&&s.secret_unlock_count===1&&s.grounded&&s.falls===0,'A normal arrow-key jump from spawn lands on the secret pillar and earns one badge');
  check(s.hoodie==='b69add'&&s.secret_notice_time>0,'Unlock equips the Moonflower hoodie and shows its celebration');
  check(s.secret_saved&&s.victories===0&&s.pad===0,'Achievement saves without advancing course progress');await shot('35-secret-perch-unlocked.png');
  const perchPosition=s.position;await sleep(900);s=await read();check(s.grounded&&Math.hypot(...s.position.map((v,i)=>v-perchPosition[i]))<.02&&s.secret_unlock_count===1,'The pillar supports standing without repeated awards');
  await page.keyboard.press('Escape');await state('paused');const timer=(await read()).secret_notice_time;await sleep(350);check((await read()).secret_notice_time===timer,'Pause freezes the reward celebration');
  await click(640,541);await state('title');await shot('36-secret-badge-wardrobe.png');
  await click(220,490);check((await read()).hoodie==='e58f76','An original hoodie remains selectable after unlocking');
  await click(1100,230);check((await read()).hoodie==='b69add','The earned hoodie can be re-equipped from its badge card');
  await page.reload();await loaded();s=await read();check(s.secret_unlocked&&s.secret_unlock_count===0,'Browser refresh retains the badge without awarding it again');
  await click(1100,230);check((await read()).hoodie==='b69add','Saved reward remains wearable after refresh');await shot('37-secret-reloaded.png');
  await click(327,437);await state('customizing');let tab=(await read()).wardrobe.controls.tab_Tops;await click(tab.x,tab.y);
  check(!(await read()).wardrobe.controls.top_color_3.disabled,'A genuinely earned Secret Perch badge unlocks Moonflower in the full wardrobe');
  const cancel=(await read()).wardrobe.controls.cancel;await click(cancel.x,cancel.y);await state('title');
  await click(1110,578);check((await read()).secret_unlocked&&(await read()).level===2,'Changing levels retains the badge');
  await click(220,565);await state('playing');await sleep(450);await page.keyboard.press('r');await sleep(300);check((await read()).secret_unlocked&&(await read()).hoodie==='b69add','Restart retains the badge and outfit');
  await page.keyboard.press('Escape');await state('paused');await click(640,541);await state('title');await page.setViewportSize({width:1024,height:640});await sleep(300);await shot('38-secret-small.png');
  check(await page.evaluate(()=>innerWidth===document.documentElement.scrollWidth&&innerHeight===document.documentElement.scrollHeight),'Badge and wardrobe fit the smaller desktop viewport');
  // Simulate a browser denying storage, without changing game state or granting rewards.
  await context.addInitScript(()=>Object.defineProperty(window,'localStorage',{get(){throw new DOMException('Storage disabled','SecurityError')}}));
  await page.setViewportSize({width:1280,height:720});await page.reload();await loaded();
  check(!(await read()).secret_unlocked,'Denied browser storage still loads a playable locked profile');
  await click(220,565);await state('playing');await sleep(600);mx=640;my=360;await page.mouse.move(mx,my);await sleep(220);await aim(target);
  await page.keyboard.down('ArrowUp');await sleep(640);await page.keyboard.press('Space');await sleep(820);await page.keyboard.up('ArrowUp');await sleep(300);
  s=await read();check(s.secret_unlocked&&!s.secret_saved&&s.hoodie==='b69add','When storage is denied, a real landing still earns and equips the reward for this visit');await shot('39-secret-storage-unavailable.png');
  check(errors.length===0,'Secret achievement has no browser or engine errors');
  await fs.writeFile(path.join(ROOT,'docs/secret-browser-results.json'),JSON.stringify({checks,errors,landingPosition:perchPosition,target},null,2));console.log('RESULT:',checks.length,'secret checks passed');
 }catch(e){await shot('secret-test-failure.png').catch(()=>{});console.error('STATE:',await read().catch(()=>null),'ERRORS:',errors);throw e}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
