// Run with node --test tests/game.test.cjs. No third-party packages required.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
function game(){
  const elements={},handlers={};
  const canvas=new Proxy({createRadialGradient:()=>({addColorStop(){}})}, {get:(o,k)=>o[k]||(()=>{})});
  function element(id){return elements[id]??={style:{},innerHTML:'',textContent:'',setAttribute(){},addEventListener:(t,f)=>{handlers[id+':'+t]=f},getContext:()=>canvas,getBoundingClientRect:()=>({left:0,top:0,width:1100,height:710}),setPointerCapture(){}}}
  const storage={};const context={console,Math:Object.create(Math),Set,Map,performance:{now:()=>0},requestAnimationFrame(){},localStorage:storage,window:{addEventListener:(t,f)=>handlers['window:'+t]=f},document:{getElementById:element,addEventListener:(t,f)=>handlers['document:'+t]=f,body:{classList:{add(){}}}}};
  vm.createContext(context);vm.runInContext(fs.readFileSync(path.join(__dirname,'../game.js'),'utf8'),context);
  return {run:s=>vm.runInContext(s,context),elements,handlers,storage};
}
test('dash only triggers on a new key down, cooldown recovers, walls stop high-speed movement',()=>{
 const {run}=game();run(`start();rooms[0].hazards=[];enemies=[];p.x=150;p.y=355;keys.ArrowRight=true;keyDown({key:' ',repeat:false,preventDefault(){}});`);
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
 const {run}=game();run(`start();rooms[0].obstacles=[];enemies=[];p.x=150;p.y=350;spawn('tank',500,350);enemies[0].cd=0;updateEnemies(.016)`);assert.equal(run('enemies[0].mode'),'windup');run('updateEnemies(.86)');assert.equal(run('enemies[0].mode'),'charge');run('updateEnemies(.61)');assert.equal(run('enemies[0].mode'),'recover');
 run(`enemies=[];bullets=[];spawn('gun',500,350);enemies[0].cd=0;updateEnemies(.016);for(let i=0;i<6;i++)updateEnemies(.1)`);assert.equal(run('bullets.length'),3);
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
 const {run}=game();run(`start();rooms[0].hazards=[{x:100,y:300,w:130,h:100}];enemies=[];p.x=150;p.y=355;inv=0;tick(.016)`);assert.equal(run('p.hp'),94);
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
 handlers['moveStick:pointerdown'](event);assert.ok(run('touch.move.x')>0);handlers['moveStick:pointercancel'](event);assert.equal(run('touch.move.x'),0);
 handlers['aimStick:pointerdown'](event);assert.equal(run('touch.firing'),true);handlers['aimStick:lostpointercapture'](event);assert.equal(run('touch.firing'),false);
});
test('render and audio gracefully support disabled sound; two-stage boss HUD updates',()=>{
 const {run,elements}=game();run('render(.016);start();render(.016);enter(11);enemies[0].hp=400;updateUI();render(.016);toggleSound();toggleSound()');assert.equal(elements.boss.style.display,'block');assert.match(elements.bossname.textContent,/Ⅱ/);assert.match(elements.bosshealth.textContent,/400/);
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

