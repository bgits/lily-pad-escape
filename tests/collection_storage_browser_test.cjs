/* Isolated-browser save migration/failure checks and readable behavior captures. */
const {chromium}=require('playwright');
const fs=require('node:fs/promises'),path=require('node:path'),assert=require('node:assert/strict');
const ROOT=path.resolve(__dirname,'..'),sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:process.env.PLAYWRIGHT_HEADLESS !== "false",channel:process.env.PLAYWRIGHT_CHANNEL || 'chrome',args:['--use-angle=metal']});
 const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
 const page=await context.newPage();const checks=[],errors=[];let mx=640,my=360;
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const read=()=>page.evaluate(()=>window.lilyPadState);
 const check=(ok,text)=>{assert(ok,text);checks.push(text);console.log('PASS:',text)};
 const state=x=>page.waitForFunction(x=>window.lilyPadState?.state===x,x,{timeout:7000});
 const ready=async()=>{await page.waitForSelector('#loading',{state:'detached'});await state('title')};
 const click=async(x,y)=>{await page.mouse.click(x,y);mx=x;my=y;await sleep(200)};
 const shot=name=>page.screenshot({path:path.join(ROOT,'docs',name),scale:'css'});
 const aim=async target=>{const s=await read(),a=Math.atan2(-(target[0]-s.position[0]),-(target[1]-s.position[2])),d=((a-s.yaw+Math.PI*3)%(Math.PI*2))-Math.PI,p=-d/.0026,n=Math.max(1,Math.ceil(Math.abs(p)/60));for(let i=0;i<n;i++){mx+=p/n;await page.mouse.move(mx,my);await sleep(18)}await sleep(160)};
 const jump=async(target)=>{await aim(target);const s=await read(),d=Math.hypot(target[0]-s.position[0],target[1]-s.position[2]);await page.keyboard.down('ArrowUp');await sleep(Math.max(60,(d-4.3)/5.4*1000));await page.keyboard.press('Space');await sleep(750);await page.keyboard.up('ArrowUp');await sleep(250)};
 try{
  await page.goto(process.env.GAME_URL||'http://127.0.0.1:8765/?qa');await ready();
  // These are storage fixtures in this fresh test context, never player movement setters.
  await page.evaluate(()=>{
   localStorage.setItem('lily-pad-escape.secret-perch.v1','1');
   localStorage.setItem('lily-pad-escape.appearance.v1',JSON.stringify({name:'Pip',outfit:{hair_style:3,top_color:3}}));
   localStorage.setItem('lily-pad-escape.fireflies.v1','[1,-2,9]');
  });
  await page.reload();await ready();let s=await read();
  check(s.firefly_masks.join(',')==='1,0,0,0,0'&&s.fireflies[0].collected,'Web loading keeps valid fireflies and rejects invalid masks');
  check(s.secret_unlocked&&s.player_name==='Pip'&&s.outfit.hair_style===3&&s.outfit.top_color===3,'Collection loading preserves the saved name, outfit, and secret reward');
  await page.evaluate(()=>localStorage.setItem('lily-pad-escape.fireflies.v1','not valid JSON'));await page.reload();await ready();s=await read();
  check(s.firefly_masks.every(x=>x===0)&&s.secret_unlocked&&s.player_name==='Pip','Malformed collection JSON falls back without damaging older saves');
  await click(1110,506);await click(220,565);await state('playing');await sleep(3000);
  await jump([0,-4.85]);
  await page.waitForFunction(()=>window.lilyPadState?.frogs[0].behavior==='crouching',null,{timeout:5000});
  check((await read()).frogs[0].telegraph,'The browser shows a landing marker during the frog crouch');
  await shot('58-frog-crouch-warning.png');
  await page.waitForFunction(()=>window.lilyPadState?.frogs[0].behavior==='hopping',null,{timeout:2000});
  await shot('59-frog-physical-hop.png');
  // Deny storage only in this isolated context and repeat a real pickup.
  await context.addInitScript(()=>Object.defineProperty(window,'localStorage',{configurable:true,get(){throw new Error('Test storage blocked')}}));
  await page.reload();await ready();s=await read();check(s.firefly_masks.every(x=>x===0),'Blocked browser storage still opens a playable empty collection');
  await click(220,565);await state('playing');await sleep(550);await jump([0,-5.35]);
  await aim([3.9,-5.35]);await shot('60-firefly-before-collection.png');
  await page.waitForFunction(()=>window.lilyPadState?.drifting_pads[0].clock%8<.25,null,{timeout:11000});
  await jump([3.9,-5.35]);await page.waitForFunction(()=>window.lilyPadState?.fireflies[0].collected,null,{timeout:3000});s=await read();
  check(!s.fireflies_saved&&s.firefly_masks[0]===1,'A real pickup stays collected when browser storage rejects saving');
  await shot('61-firefly-saving-unavailable.png');await page.keyboard.press('r');await sleep(400);s=await read();
  check(s.fireflies[0].collected&&s.firefly_masks[0]===1,'An unsaved pickup survives a restart in the same visit');
  await page.reload();await ready();check((await read()).firefly_masks[0]===0,'Storage denial does not falsely claim persistence across reload');
  check(errors.length===0,'Malformed and blocked browser storage produce no engine or browser errors');
  await fs.writeFile(path.join(ROOT,'docs/collection-storage-browser-results.json'),JSON.stringify({checks,errors},null,2));console.log('RESULT:',checks.length,'checks passed');
 }catch(e){console.error('STATE:',JSON.stringify(await read().catch(()=>null)),errors);await shot('collection-storage-test-failure.png').catch(()=>{});throw e}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
