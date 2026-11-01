/* Reproduce the backwards-swing report through normal movement and attack input. */
const {chromium}=require('playwright');
const fs=require('node:fs/promises');
const assert=require('node:assert/strict');
const path=require('node:path');
const ROOT=path.resolve(__dirname,'..');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const angleDiff=(a,b)=>Math.atan2(Math.sin(a-b),Math.cos(a-b));
const aligned=(s,yaw)=>s.attack_direction[0]*-Math.sin(yaw)+s.attack_direction[2]*-Math.cos(yaw)>.9999;
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chrome',args:['--use-angle=metal']});
 const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:1});
 const checks=[],errors=[],samples=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const read=()=>page.evaluate(()=>window.lilyPadState);
 const check=(ok,text)=>{assert(ok,text);checks.push(text);console.log('PASS:',text)};
 const state=x=>page.waitForFunction(x=>window.lilyPadState?.state===x,x,{timeout:6000});
 const click=async(x,y)=>{await page.mouse.click(x,y);await sleep(220)};
 const shot=name=>page.screenshot({path:path.join(ROOT,'docs',name),scale:'css'});
 const turn=async(key)=>{await page.keyboard.down(key);await sleep(200);await page.keyboard.up(key);await sleep(220)};
 try{
  await page.goto(process.env.GAME_URL||'http://127.0.0.1:8765/?qa');
  await page.waitForSelector('#loading',{state:'detached'});await state('title');
  await click(1110,578);await click(220,565);await state('playing');await sleep(550);
  for(const [direction,attack] of [['ArrowDown','f'],['ArrowLeft','mouse']]){
   await turn(direction);let s=await read();const facing=s.avatar_yaw;
   check(s.grounded&&Math.abs(angleDiff(facing,s.yaw))>1,'Movement faces '+direction+' independently of the camera');
   if(attack==='mouse')await page.mouse.click(640,360);else await page.keyboard.press(attack);
   await sleep(150);s=await read();samples.push(s);
   check(s.swing_remaining>0&&Math.abs(angleDiff(s.avatar_yaw,facing))<.0001,attack+' swing preserves the character orientation');
   check(aligned(s,facing),attack+' hit direction follows the character rather than camera yaw');
   await sleep(500);s=await read();check(Math.abs(angleDiff(s.avatar_yaw,facing))<.0001,'Recovery keeps the '+direction+' facing');
   await page.keyboard.press('r');await sleep(400);
  }
  // Land on the near side, walk around the frog, then turn back without orbiting.
  await page.keyboard.down('ArrowUp');await sleep(204);await page.keyboard.press('Space');await sleep(750);await page.keyboard.up('ArrowUp');await sleep(280);
  await page.waitForFunction(()=>window.lilyPadState?.grounded&&window.lilyPadState.poison_source_pad===1,null,{timeout:2500});
  for(const [key,ms] of [['ArrowRight',250],['ArrowUp',500],['ArrowLeft',250]]){
   await page.keyboard.down(key);await sleep(ms);await page.keyboard.up(key);await sleep(220);
  }
  let s=await read();const frog=s.frogs[0];
  check(s.grounded&&s.poisoned&&frog.alive&&s.position[2]<frog.position[2]-.4,'Normal movement gets beyond a living frog');
  await turn('ArrowDown');s=await read();const facing=s.avatar_yaw;
  check(Math.abs(angleDiff(facing,s.yaw))>2.8&&s.position[2]<frog.position[2],'Arrow Down turns back toward the frog while the camera stays forward');
  await shot('40-backward-facing-frog.png');
  await page.keyboard.press('f');
  await page.waitForFunction(()=>window.lilyPadState?.swings===1&&window.lilyPadState.swing_remaining<=.30,null,{timeout:2500});
  s=await read();samples.push(s);
  check(Math.abs(angleDiff(s.avatar_yaw,facing))<.0001&&aligned(s,facing),'Backward attack stays facing the frog through impact');
  check(!s.frogs[0].alive&&s.hits===1&&s.frogs_remaining===5,'Backward-facing attack defeats the frog behind the camera');
  check(s.health===100&&!s.poisoned,'Backward kill restores 100 percent health');
  await shot('41-backward-bat-hit.png');await sleep(500);
  check(Math.abs(angleDiff((await read()).avatar_yaw,facing))<.0001,'Character still faces backwards after the successful swing');
  check(errors.length===0,'Facing regression has no browser or engine errors');
  await fs.writeFile(path.join(ROOT,'docs/swing-facing-browser-results.json'),JSON.stringify({checks,errors,samples},null,2));
  console.log('RESULT:',checks.length,'swing-facing checks passed');
 }catch(e){await shot('swing-facing-test-failure.png').catch(()=>{});console.error('STATE:',await read().catch(()=>null),'ERRORS:',errors);throw e}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
