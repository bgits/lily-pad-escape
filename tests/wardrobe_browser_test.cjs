/* Wardrobe acceptance via real canvas controls; QA is read-only. */
const {chromium}=require('playwright');
const fs=require('node:fs/promises');
const assert=require('node:assert/strict');
const path=require('node:path');
const ROOT=path.resolve(__dirname,'..');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await chromium.launch({headless:process.env.PLAYWRIGHT_HEADLESS !== "false",channel:process.env.PLAYWRIGHT_CHANNEL || 'chrome',args:['--use-angle=metal']});
 const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
 const page=await context.newPage();const checks=[],errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const read=()=>page.evaluate(()=>window.lilyPadState);
 const check=(ok,text)=>{assert(ok,text);checks.push(text);console.log('PASS:',text)};
 const state=x=>page.waitForFunction(x=>window.lilyPadState?.state===x,x,{timeout:6000});
 const shot=name=>page.screenshot({path:path.join(ROOT,'docs',name),scale:'css'});
 const point=async(x,y)=>{const rect=await page.locator('#canvas').boundingBox(),scale=Math.min(rect.width/1280,rect.height/720);return{x:rect.x+(rect.width-1280*scale)/2+x*scale,y:rect.y+(rect.height-720*scale)/2+y*scale}};
 const click=async(x,y)=>{const p=await point(x,y);await page.mouse.click(p.x,p.y);await sleep(220)};
 const control=async(key)=>{const c=(await read()).wardrobe.controls[key];assert(c,'Visible wardrobe control: '+key);await click(c.x,c.y)};
 const loaded=async()=>{await page.waitForSelector('#loading',{state:'detached'});await state('title');await page.bringToFront();await sleep(250)};
 const same=(a,b)=>Object.keys(a).length===Object.keys(b).length&&Object.keys(a).every(k=>a[k]===b[k]);
 try{
  await page.goto(process.env.GAME_URL||'http://127.0.0.1:8765/?qa');await loaded();const original=(await read()).outfit;
  await shot('42-customize-button.png');await click(327,437);await state('customizing');await sleep(350);
  check((await read()).wardrobe.visible&&!(await page.evaluate(()=>!!document.pointerLockElement)),'Customize opens a usable preview with the mouse free');await shot('43-wardrobe-character.png');
  await control('character_1');await control('skin_4');await control('name');
  await page.waitForFunction(()=>window.lilyPadState?.wardrobe.name_focused);
  await page.keyboard.type('Pip "Sky" <3',{delay:70});await sleep(200);
  check((await read()).wardrobe.name==='Pip "Sky" <3','The wardrobe name field accepts ordinary typing and quoted text');
  await control('tab_Hair');await control('hair_style_2');await control('hair_color_3');
  const angle=(await read()).wardrobe.preview_rotation;await control('turn_right');await sleep(250);check(Math.abs((await read()).wardrobe.preview_rotation-angle)>.5,'Turn buttons rotate the preview');
  const drag=await point(299,387);await page.mouse.move(drag.x,drag.y);await page.mouse.down();await page.mouse.move(drag.x+100,drag.y,{steps:10});await page.mouse.up();await sleep(250);
  check(Math.abs((await read()).wardrobe.preview_rotation-angle)>1,'Dragging also rotates the character preview');await shot('44-wardrobe-hair.png');
  await control('tab_Tops');let s=await read();check(s.wardrobe.controls.top_color_3.disabled,'Moonflower visibly stays locked before the achievement');
  await control('top_color_3');check((await read()).wardrobe.draft.top_color===0,'Clicking the locked reward cannot equip it');
  await control('top_style_1');await control('top_color_4');
  await control('tab_Pants');await control('pants_style_1');await control('pants_color_1');
  await control('tab_Shoes');await control('shoe_style_1');await control('shoe_color_2');await shot('45-wardrobe-shoes.png');
  s=await read();const chosen=s.wardrobe.draft;check(same(s.outfit,original),'Unsaved customization leaves the actual outfit unchanged');
  check(chosen.character===1&&chosen.skin===4&&chosen.hair_style===2&&chosen.hair_color===3&&chosen.top_style===1&&chosen.top_color===4&&chosen.pants_style===1&&chosen.pants_color===1&&chosen.shoe_style===1&&chosen.shoe_color===2,'Character, skin, hair, top, pants, shoes, and colors can be mixed independently');
  await control('save');await state('title');await page.bringToFront();s=await read();check(same(s.outfit,chosen)&&s.hoodie==='83b8a3'&&s.player_name==='Pip "Sky" <3'&&s.outfit_saved,'Save outfit applies the appearance and quoted name');
  await page.reload();await loaded();s=await read();check(same(s.outfit,chosen)&&s.player_name==='Pip "Sky" <3','All outfit choices and the name survive a browser refresh');
  await click(327,437);await state('customizing');await control('character_2');await control('tab_Hair');await control('hair_style_1');await control('cancel');await state('title');await page.bringToFront();check(same((await read()).outfit,chosen),'Cancel discards preview changes');
  await click(327,437);await state('customizing');await control('character_0');await page.keyboard.press('Escape');await state('title');await page.bringToFront();check(same((await read()).outfit,chosen),'Escape also discards changes');
  await click(327,437);await state('customizing');await page.setViewportSize({width:1024,height:640});await sleep(300);await control('tab_Tops');await shot('46-wardrobe-small.png');
  check(await page.evaluate(()=>innerWidth===document.documentElement.scrollWidth&&innerHeight===document.documentElement.scrollHeight),'Wardrobe fits a smaller desktop window');
  check((await read()).wardrobe.category==='Tops','Wardrobe category controls work at the smaller size');await control('cancel');await state('title');await page.bringToFront();await page.setViewportSize({width:1280,height:720});await sleep(250);
  await click(1110,506);await click(220,565);await state('playing');await sleep(450);s=await read();check(s.has_bat&&same(s.outfit,chosen),'The customized character enters Frog River with its bat');
  await page.keyboard.press('Escape');await state('paused');const paused=await read();await click(1140,50);await state('customizing');
  await control('tab_Tops');await control('top_style_2');await control('top_color_2');await control('tab_Pants');await control('pants_style_2');await control('tab_Shoes');await control('shoe_style_2');await control('shoe_color_3');await control('tab_Hair');await control('hair_style_3');await control('hair_color_4');
  s=await read();check(JSON.stringify(s.position)===JSON.stringify(paused.position)&&s.seconds===paused.seconds,'Customizing from pause freezes the run');await shot('47-wardrobe-new-outfit.png');
  const second=s.wardrobe.draft;await control('save');await state('paused');s=await read();check(same(s.outfit,second)&&JSON.stringify(s.position)===JSON.stringify(paused.position),'Saving from pause changes clothes without moving or resuming the player');
  await click(640,350);await state('playing');await sleep(400);await page.keyboard.press('Space');await sleep(1100);await page.keyboard.press('f');await sleep(550);s=await read();check(s.grounded&&s.jumps===1&&s.swings===1&&same(s.outfit,second),'Customized clothing still supports jumping and the bat animation');await shot('48-customized-gameplay.png');
  await page.keyboard.press('r');await sleep(350);check(same((await read()).outfit,second),'Restart keeps all clothing choices');
  await page.keyboard.press('Escape');await state('paused');await click(640,541);await state('title');await page.bringToFront();await click(1110,558);check((await read()).level===3&&same((await read()).outfit,second),'Changing levels preserves customization');
  // Corrupt only this disposable browser's saved-data fixture, then reload normally.
  await page.evaluate(()=>localStorage.setItem('lily-pad-escape.appearance.v1','{broken saved outfit'));
  await page.reload();await loaded();s=await read();check(s.outfit.hair_style===0&&s.outfit.top_style===0&&s.player_name==='','Malformed saved data falls back to a usable default character');
  // This disposable context simulates unavailable browser storage.
  await context.addInitScript(()=>Object.defineProperty(window,'localStorage',{get(){throw new DOMException('Storage disabled','SecurityError')}}));
  await page.reload();await loaded();await click(327,437);await state('customizing');await control('character_2');await control('tab_Hair');await control('hair_style_4');await control('save');await state('title');await page.bringToFront();s=await read();check(!s.outfit_saved&&s.outfit.character===2&&s.outfit.hair_style===4,'Storage denial keeps the chosen outfit usable for the current visit');
  check(errors.length===0,'Wardrobe browser session has no script or engine errors');
  await fs.writeFile(path.join(ROOT,'docs/wardrobe-browser-results.json'),JSON.stringify({checks,errors,chosen,second},null,2));console.log('RESULT:',checks.length,'wardrobe checks passed');
 }catch(e){await shot('wardrobe-test-failure.png').catch(()=>{});console.error('STATE:',await read().catch(()=>null),'ERRORS:',errors);throw e}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
