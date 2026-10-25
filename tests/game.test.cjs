const {test}=require('node:test');
const assert=require('node:assert/strict');
const {game}=require('./harness.cjs');
test('dash only triggers on a new key down, cooldown recovers, walls stop high-speed movement',()=>{
 const {run}=game();run(`start();rooms[0].hazards=[];rooms[0].clear=true;enemies=[];p.x=150;p.y=355;keys.ArrowRight=true;keyDown({key:' ',repeat:false,preventDefault(){}});`);
 assert.equal(run('dash'),1.5);run(`for(let i=0;i<150;i++)tick(.016);keyDown({key:' ',repeat:true,preventDefault(){}})`);assert.equal(run('dash'),0);
 run(`keyUp({key:' '});keyDown({key:' ',repeat:false,preventDefault(){}})`);assert.equal(run('dash'),1.5);
 run(`rooms[ri].obstacles=[{x:300,y:200,w:100,h:330}];p.x=250;p.y=355;moveBody(p,400,0)`);assert.ok(run('p.x')<=286);assert.ok(run('parseFloat($("dashbar").style.width)')>=0);
});
test('shop supports ramen then barrel, re-entry, stock and insufficient funds',()=>{
 const {run}=game();run(`start();rooms[0].type='shop';rooms[0].clear=true;p.x=550;p.y=355;p.hp=20;p.coins=100;interact();buy(0)`);
 assert.equal(run('state'),'shop');assert.equal(run('p.hp'),70);assert.equal(run('p.coins'),80);run('buy(1)');assert.equal(run('p.coins'),50);assert.equal(run('p.damage'),21.6);assert.equal(run('rooms[0].used'),false);
 run('buy(1)');assert.equal(run('p.coins'),50);run('close();interact();buy(0)');assert.equal(run('p.coins'),30);assert.equal(run('p.hp'),100);run('buy(0)');assert.equal(run('p.coins'),30);
 run('p.coins=0;p.hp=20;buy(0)');assert.equal(run('p.hp'),20);
});
test('swept bullets and enemy charges cannot pass through cover',()=>{
 const {run}=game();run(`start();rooms[0].obstacles=[{x:400,y:200,w:50,h:340}];rooms[0].hazards=[];enemies=[];p.x=150;p.y=355;const enemy=spawn('chase',550,355);bullets=[{x:350,y:355,vx:10000,vy:0,life:1,damage:100,pierce:4,hit:new Set()}];updateBullets(.04)`);
 assert.equal(run('enemies[0].hp'),38);assert.equal(run('bullets.length'),0);
 run(`bullets=[{x:550,y:355,vx:-10000,vy:0,life:1,enemy:true}];inv=0;updateBullets(.04)`);assert.equal(run('p.hp'),100);
 run(`enemies[0].x=480;enemies[0].r=23;moveBody(enemies[0],-500,0)`);assert.ok(run('enemies[0].x')>=473);
});
test('lightning, freezing, explosion, lifesteal and critical damage work together',()=>{
 const {run}=game();run(`start();enemies=[];rooms[0].obstacles=[];p.crit=0;p.chain=1;p.freeze=1;p.explosive=1;p.leech=1;p.hp=30;spawn('tank',500,350);spawn('tank',550,350);for(let i=0;i<3;i++)projectileHit(enemies[0],{damage:10})`);
 assert.ok(run('enemies[1].hp')<105);assert.ok(run('enemies[0].freeze')>0);assert.ok(run('p.hp')>30);assert.ok(run('effects.some(e=>e.type==="chain")'));assert.ok(run('effects.some(e=>e.type==="blast")'));
 run(`p.crit=1;projectileHit(enemies[0],{damage:10})`);assert.equal(run('runCrits'),1);
});
test('orbiting blade deals nearby damage without firing',()=>{const {run}=game();run(`start();rooms[0].obstacles=[];rooms[0].hazards=[];enemies=[];p.x=450;p.y=350;p.orbit=1;spawn('tank',512,350);inv=99;tick(.016)`);assert.ok(run('enemies[0].hp')<105)});
test('tank telegraphs, charges and recovers; gunner fires a three-shot burst',()=>{
 const {run}=game();run(`start();rooms[0].obstacles=[];enemies=[];p.x=150;p.y=350;spawn('tank',500,350);enemies[0].cd=0;attackGap=0;updateEnemies(.016)`);assert.equal(run('enemies[0].mode'),'windup');run('updateEnemies(.86)');assert.equal(run('enemies[0].mode'),'charge');run('updateEnemies(.61)');assert.equal(run('enemies[0].mode'),'recover');
 run(`enemies=[];bullets=[];spawn('gun',500,350);enemies[0].cd=0;attackGap=0;updateEnemies(.016);for(let i=0;i<6;i++)updateEnemies(.1)`);assert.equal(run('bullets.length'),3);
});
test('layouts leave a safe route to exit and interaction point for players and tanks',()=>{
 const {run}=game();run('start()');
 for(const variant of ['cover','lanes','poison','arena'])for(const radius of [14,23,38]){
 run(`rooms[0]=makeRoom('shop','${variant}',0)`);
 const passable=run(`(()=>{const step=10,start={x:150,y:355},seen=new Set(),q=[start];let found=false;for(let n=0;n<q.length;n++){const v=q[n];if(v.x>1010&&Math.abs(v.y-355)<20)found=true;for(const [dx,dy] of [[step,0],[-step,0],[0,step],[0,-step]]){let x=v.x+dx,y=v.y+dy,k=x+','+y;if(x<65||x>1030||y<210||y>520||seen.has(k)||blocked(x,y,${radius})||rooms[0].hazards.some(h=>circleBox(x,y,${radius},h)))continue;seen.add(k);q.push({x,y})}}return found&&[...seen].some(k=>{const [x,y]=k.split(',').map(Number);return Math.hypot(x-550,y-355)<90})})()`);
 assert.ok(passable,`${variant}, radius ${radius}`);
 }
});
test('poison causes damage and health drops have a five-kill pity counter',()=>{
 const {run}=game();run(`start();rooms[0].clear=true;rooms[0].hazards=[{x:100,y:300,w:130,h:100}];enemies=[];p.x=150;p.y=355;inv=0;tick(.016)`);assert.equal(run('p.hp'),94);
 run(`Math.random=()=>.9;enemies=[];for(let i=0;i<5;i++){let e=spawn('chase',800,350);e.hp=0}resolveKills()`);assert.ok(run('drops.some(d=>d.heal===16)'));
 run('p.hp=30;collectDrop({heal:16})');assert.equal(run('p.hp'),46);
});
test('boss rewards auto-collect before victory and stats persist exactly once',()=>{
 const {run,storage}=game();run(`start();enter(11);const oldCoins=p.coins;enemies[0].hp=0;resolveKills()`);assert.equal(run('state'),'win');assert.equal(run('p.coins'),100);assert.ok(run('p.lv')>1);assert.equal(run('stats.wins'),1);assert.equal(run('stats.totalKills'),1);run('end(true)');assert.equal(run('stats.runs'),1);assert.equal(JSON.parse(storage.neonStats).maxFloor,12);
});
test('upgrade consumes exactly one offer; treasure and event cannot be farmed',()=>{
 const {run}=game();run(`start();rooms[0].type='treasure';rooms[0].clear=true;p.x=550;p.y=355;interact()`);assert.equal(run('state'),'upgrade');run('pick(offered[0]);interact()');assert.equal(run('pending'),0);assert.equal(run('p.coins'),30);
 run(`rooms[0].type='event';rooms[0].used=false;p.hp=20;interact();trade()`);assert.equal(run('rooms[0].used'),false);run('p.hp=50;interact();trade();pick(offered[0]);trade()');assert.equal(run('p.coins'),55);
});
test('pause supports resume, restart, title; blur clears held controls',()=>{
 const {run,handlers,elements}=game();run('start();keys.ArrowRight=true;touch.firing=true');handlers['window:blur']();assert.equal(run('state'),'pause');assert.equal(run('touch.firing'),false);assert.match(elements.overlay.innerHTML,/重新开始/);assert.match(elements.overlay.innerHTML,/回主菜单/);run('close()');assert.equal(run('state'),'play');run('title()');assert.equal(run('p'),null);run('start()');assert.equal(run('state'),'play');
});
test('touch move/aim release and cancellation stop their actions',()=>{
 const {run,handlers}=game();run('start()');const event={pointerId:7,clientX:580,clientY:355,preventDefault(){}};
 handlers['moveStick:pointerdown'](event);handlers['moveStick:pointermove']({...event,clientX:900});assert.ok(run('touch.move.x')>0);handlers['moveStick:pointercancel'](event);assert.equal(run('touch.move.x'),0);
 handlers['aimStick:pointerdown'](event);assert.equal(run('touch.firing'),true);handlers['aimStick:lostpointercapture'](event);assert.equal(run('touch.firing'),false);
});
test('render and audio gracefully support disabled sound; two-stage boss HUD updates',()=>{
 const {run,elements}=game();run('render(.016);start();render(.016);enter(11);enemies[0].hp=400;updateBoss(enemies[0],.016);updateUI();render(.016);toggleSound();toggleSound()');assert.equal(elements.boss.style.display,'block');assert.match(elements.bossname.textContent,/Ⅱ/);assert.match(elements.bosshealth.textContent,/400/);
});
test('seekers navigate around cover instead of remaining stuck',()=>{
 const {run}=game();run(`start();rooms[0].obstacles=[{x:300,y:270,w:70,h:130}];enemies=[];p.x=150;p.y=355;inv=99;spawn('chase',550,355);for(let i=0;i<650;i++)updateEnemies(.016)`);assert.ok(run('dist(enemies[0],p)')<50);
});
test('Web Audio synthesis schedules envelopes and mute stops new voices',()=>{
 const instance=game();instance.run(`
 let voices=0,ramps=0;
 window.AudioContext=class {
  constructor(){this.state='suspended';this.currentTime=10;this.destination={}}
  resume(){this.state='running';return Promise.resolve()}
  createGain(){return {gain:{value:0,setValueAtTime(){},exponentialRampToValueAtTime(){ramps++}},connect(){},disconnect(){}}}
  createOscillator(){return {frequency:{setValueAtTime(){},exponentialRampToValueAtTime(){ramps++}},connect(){},disconnect(){},start(){voices++},stop(){}}}
 };
 unlockAudio();sfx('shot');sfx('hurt');sfx('pick');sfx('level');
 `);
 assert.equal(instance.run('audio.state'),'running');assert.ok(instance.run('voices')>=9);assert.ok(instance.run('ramps')>0);
 const before=instance.run('voices');instance.run(`toggleSound();sfx('win')`);assert.equal(instance.run('voices'),before);
});
test('first three rooms guarantee a gentle fight, build upgrade and affordable healing',()=>{
 const {run}=game();for(let i=0;i<20;i++){run('start()');assert.equal(run('rooms.slice(0,3).map(r=>r.type).join()'),'fight,fight,shop');assert.equal(run('rooms[0].hazards.length'),0);assert.equal(run('enemies.length'),3);assert.ok(run('enemies.every(e=>e.type==="chase")'))}
 run(`p.hp=50;for(const e of enemies)e.hp=0;tick(.016)`);assert.equal(run('state'),'upgrade');assert.ok(run('offered.some(i=>[8,9,10,12].includes(i))'));assert.ok(run('p.hp')>=62);
 run('pick(offered[0]);enter(1);for(const e of enemies)e.hp=0;tick(.016);while(state==="upgrade")pick(offered[0]);p.hp=30;enter(2)');assert.equal(run('p.hp'),60);assert.ok(run('p.coins')>=35);run('p.x=550;p.y=355;interact();buy(0)');assert.equal(run('p.hp'),100);
});
test('permanent marks unlock sidegrades without adding initial health',()=>{
 const {run}=game();run(`legacy=50;selectedRunner='courier';selectedWeapon='pulse';start()`);assert.equal(run('p.max'),100);run(`title();selectLoadout('runner','skater');selectLoadout('weapon','scatter');start()`);assert.equal(run('p.max'),85);assert.equal(run('p.multi'),3);assert.equal(run('p.damage'),7);
 run(`legacy=0;start()`);assert.equal(run('p.max'),100);assert.equal(run('p.multi'),1);
 run(`legacy=8;p.chain=1`);assert.ok(run('availableUpgrades().includes(14)'));run('legacy=7');assert.equal(run('availableUpgrades().includes(14)'),false);
});
test('frozen targets shatter, chain kills recharge dash and orbit damage steals life',()=>{
 const {run}=game();run(`start();rooms[0].clear=true;rooms[0].obstacles=[];rooms[0].hazards=[];enemies=[];p.crit=0;p.freeze=1;p.explosive=1;spawn('tank',500,355);spawn('tank',590,355);enemies[0].freeze=1;projectileHit(enemies[0],{damage:16})`);assert.ok(run('enemies[1].hp')<105);assert.ok(run('numbers.some(n=>n.text==="冰爆！")'));
 run(`p.chain=1;p.explosive=0;p.freeze=0;enemies=[];spawn('tank',500,355);spawn('chase',550,355);enemies[1].hp=1;dash=1.5;projectileHit(enemies[0],{damage:16});resolveKills()`);assert.ok(run('dash')<=1.2);
 run(`p.x=450;p.y=350;p.hp=20;p.orbit=1;p.leech=1;elapsed=0;enemies=[];spawn('tank',512,350);inv=99;tick(.016)`);assert.ok(run('p.hp')>20);
});
test('attack director allows one telegraphed attack then a recovery gap',()=>{
 const {run}=game();run(`start();rooms[0].obstacles=[];enemies=[];p.x=150;p.y=350;attackGap=0;spawn('tank',500,350);spawn('tank',600,350);enemies.forEach(e=>e.cd=0);updateEnemies(.016)`);assert.equal(run('enemies.filter(e=>e.mode==="windup").length'),1);
 run(`enemies[0].mode='charge';enemies[0].timer=0;updateEnemies(.016)`);assert.ok(run('attackGap')>0);assert.equal(run('enemies[1].mode'),'seek');
});
test('boss cycles fan, marked strikes and charge with locked telegraphs and recovery',()=>{
 const {run}=game();run(`start();enter(11);rooms[11].obstacles=[];p.x=150;p.y=355;const boss=enemies[0];updateBoss(boss,1.5)`);assert.equal(run('boss.move'),'fan');assert.equal(run('bullets.length'),0);
 run('updateBoss(boss,1)');assert.equal(run('bullets.length'),7);run('updateBoss(boss,.3)');assert.equal(run('boss.mode'),'rest');run('updateBoss(boss,1.5)');assert.equal(run('boss.move'),'marks');assert.equal(run('boss.mode'),'windup');const mark=run('JSON.stringify(boss.markers)');run('p.x=900;updateBoss(boss,.2)');assert.equal(run('JSON.stringify(boss.markers)'),mark);
 run('updateBoss(boss,1)');assert.ok(run('bossStrikes.length')>0);run('updateBossStrikes(.2);updateBoss(boss,1.6)');assert.equal(run('boss.move'),'charge');run('updateBoss(boss,1);updateBoss(boss,.7)');assert.equal(run('boss.mode'),'rest');
 run('boss.hp=500;updateBoss(boss,.016)');assert.equal(run('boss.mode'),'phase');assert.equal(run('bullets.filter(b=>b.enemy).length'),0);assert.equal(run('bossStrikes.length'),0);
});
test('boss warning and strike timers stop while paused',()=>{const {run}=game();run(`start();enter(11);bossStrikes=[{x:p.x,y:p.y,r:50,time:1}];pause();tick(.5)`);assert.equal(run('bossStrikes[0].time'),1)});
test('touch deadzone, optional aim assist and pause pointer reset',()=>{
 const {run,handlers}=game();run('start()');assert.equal(run('stickVector(4,0,40).x'),0);assert.ok(run('stickVector(20,0,40).x')>0);
 const event={pointerId:3,clientX:550,clientY:355,preventDefault(){}};handlers['moveStick:pointerdown'](event);handlers['moveStick:pointermove']({...event,clientX:850});assert.ok(run('touch.move.x')>0);run('pause();close()');handlers['moveStick:pointerdown']({...event,pointerId:4});handlers['moveStick:pointermove']({...event,pointerId:4,clientX:850});assert.ok(run('touch.move.x')>0);
 run(`enemies=[];rooms[0].obstacles=[];p.x=150;p.y=355;spawn('chase',500,380);controls.assist=true`);assert.ok(run('assistedAngle(0)')>0);run('controls.assist=false');assert.equal(run('assistedAngle(0)'),0);
});
test('static page declares all permanent HUD controls and loadout UI actions',()=>{
 const fs=require('node:fs'),path=require('node:path');const html=fs.readFileSync(path.join(__dirname,'../index.html'),'utf8'),js=fs.readFileSync(path.join(__dirname,'../game.js'),'utf8');
 const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);assert.equal(new Set(ids).size,ids.length,'duplicate DOM ids');
 const dynamic=new Set(['build','shopmsg','deadzoneSelect','stickSizeSelect','assistCheck']);
 for(const match of js.matchAll(/\$\('([^']+)'\)/g))assert.ok(ids.includes(match[1])||dynamic.has(match[1]),'missing control '+match[1]);
 for(const name of ['start','pick','buy','selectLoadout','toggleFullscreen','saveControls'])assert.ok(js.includes('function '+name+'('),name);
 assert.match(html,/orientation:landscape/);assert.match(html,/fullscreen-exit/);
});
test('control settings persist and render valid options from title and pause',()=>{
 const {run,elements,storage}=game();run('touchSettings()');assert.match(elements.overlay.innerHTML,/移动死区/);elements.deadzoneSelect={value:'.28'};elements.stickSizeSelect={value:'136'};elements.assistCheck={checked:false};run(`saveControls('title')`);assert.equal(JSON.parse(storage.neonControls).size,136);assert.equal(run('controls.assist'),false);
 run('start();touchSettings()');assert.equal(run('state'),'pause');assert.match(elements.overlay.innerHTML,/保存并返回/);run(`saveControls('pause')`);assert.equal(run('state'),'pause');
});
