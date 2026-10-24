'use strict';
// Canvas world coordinates stay fixed; pointer coordinates are scaled to match.
const C=document.getElementById('c'),g=C.getContext('2d'),$=id=>document.getElementById(id);
const W=1100,H=710,TAU=Math.PI*2,DASH_COOLDOWN=1.5;
const rand=(a,b)=>a+Math.random()*(b-a),clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const shuffled=items=>{const a=[...items];for(let i=a.length-1;i>0;i--){let j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a};
const timeText=s=>`${String(Math.floor(s/60)).padStart(2,'0')}:${String(Math.floor(s%60)).padStart(2,'0')}`;
let keys={},mouse={x:700,y:355,down:false},state='title',rooms=[],ri=0,p;
let bullets=[],enemies=[],particles=[],drops=[],numbers=[],effects=[];
let elapsed=0,kills=0,visited=0,shot=0,toastTime=0,dash=0,dashTime=0,dashVector={x:1,y:0},inv=0;
let pending=0,shake=0,chosen=[],offered=[],runDamage=0,runCrits=0,maxFloor=1,settled=false,nextId=1;
let legacy=0,best=0,stats={runs:0,wins:0,totalKills:0,maxFloor:0,bestTime:null};
let soundOn=true,audio=null,master=null,lastSound={};
const touch={move:{x:0,y:0},aim:{x:1,y:0},firing:false,aimManual:false};
try{legacy=+localStorage.neonLegacy||0;best=+localStorage.neonBest||0;stats={...stats,...JSON.parse(localStorage.neonStats||'{}')};soundOn=localStorage.neonSound!=='off'}catch{}

// One context, shared gain, short envelopes. No external audio or network dependency.
function unlockAudio(){
  if(!soundOn)return;
  try{if(!audio){const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)return;audio=new Audio();master=audio.createGain();master.gain.value=.22;master.connect(audio.destination)}if(audio.state==='suspended')audio.resume().catch(()=>{})}catch{}
}
function tone(freq,duration,type='sine',volume=.3,delay=0,endFreq=freq){
  if(!soundOn||!audio||audio.state!=='running')return;
  const t=audio.currentTime+delay,o=audio.createOscillator(),v=audio.createGain();o.type=type;
  o.frequency.setValueAtTime(freq,t);o.frequency.exponentialRampToValueAtTime(Math.max(20,endFreq),t+duration);
  v.gain.setValueAtTime(.001,t);v.gain.exponentialRampToValueAtTime(volume,t+.005);v.gain.exponentialRampToValueAtTime(.001,t+duration);
  o.connect(v);v.connect(master);o.start(t);o.stop(t+duration+.02);o.onended=()=>{o.disconnect();v.disconnect()};
}
function sfx(name){
  if(!soundOn||!audio)return;const t=audio.currentTime,limit={shot:.055,hit:.045,pick:.06,shock:.1,heal:.18,boom:.09}[name]||0;
  if(t-(lastSound[name]??-99)<limit)return;lastSound[name]=t;
  if(name==='shot')tone(650,.075,'triangle',.18,0,120);
  if(name==='hit')tone(140,.1,'sawtooth',.25,0,40);
  if(name==='hurt'){tone(95,.17,'square',.27,0,40);tone(60,.22,'triangle',.3)}
  if(name==='pick'){tone(740,.09,'sine',.28);tone(1120,.12,'sine',.23,.055)}
  if(name==='heal'){[523,659,784].forEach((f,i)=>tone(f,.16,'sine',.25,i*.07))}
  if(name==='level'||name==='win'){[392,523,659,784,1047].forEach((f,i)=>tone(f,.22,'triangle',.25,i*.09))}
  if(name==='dash')tone(160,.17,'triangle',.24,0,700);
  if(name==='crit'){tone(1100,.12,'square',.12,0,320)}
  if(name==='boom'){tone(75,.25,'sawtooth',.35,0,25)}
  if(name==='shock'){tone(1800,.09,'sawtooth',.1,0,300)}
  if(name==='dead'){[180,130,75].forEach((f,i)=>tone(f,.3,'triangle',.3,i*.15))}
}
function toggleSound(){soundOn=!soundOn;try{localStorage.neonSound=soundOn?'on':'off'}catch{}if(soundOn)unlockAudio();if(master)master.gain.setValueAtTime(soundOn?.22:0,audio.currentTime);$('sound').textContent=soundOn?'♫ 音效开':'♫ 音效关';$('sound').setAttribute('aria-pressed',String(soundOn))}
function resetInput(){keys={};mouse.down=false;touch.move={x:0,y:0};touch.firing=false;touch.aimManual=false;for(const id of ['moveKnob','aimKnob'])$(id).style.transform='translate(0px,0px)'}
function message(s){$('toast').textContent=s;toastTime=3}
function overlay(html){resetInput();$('overlay').style.display='flex';$('overlay').innerHTML=html}
function close(){if(!p)return;resetInput();$('overlay').style.display='none';state='play';if(pending>0)choose()}
function legacyUI(){
  $('legacy').innerHTML=`霓虹印记 <b style="color:#ffce75">${legacy}</b><br>初始生命 +${Math.min(legacy,30)*2} · 单局击败 ${best}<br>累计击败 ${stats.totalKills} · 最高 ${stats.maxFloor}/12 区<br>通关 ${stats.wins} / ${stats.runs} 局 · 最快 ${stats.bestTime==null?'—':timeText(stats.bestTime)}<div class="build-list" id="build">当前强化：无</div>`;
}
function title(){state='title';p=null;rooms=[];enemies=[];bullets=[];drops=[];effects=[];numbers=[];particles=[];pending=0;resetInput();$('boss').style.display='none';$('toast').textContent='';$('roomlabel').textContent='NEON EDITION 2.0';$('health').textContent='♥ READY';$('hpbar').style.width='100%';$('dashbar').style.width='100%';$('dashtext').textContent='冲刺就绪 / SPACE';$('level').textContent='准备进入夜市';$('map').innerHTML='';$('coins').textContent='¥ 0';$('kills').textContent='0';$('explored').textContent='— / 12';$('time').textContent='00:00';$('objective').textContent='键鼠 / 双摇杆 · 合成音效';legacyUI();overlay('<div><div class="eyebrow">NEON EDITION 2.0 / AFTER HOURS</div><h2>夜深了，<br><span style="color:#ff518d">别回头。</span></h2><p>穿过十二个夜市街区。利用掩体、组合异能，挑战夜市之王。<br>电脑：方向键移动 / 鼠标射击 / 空格冲刺<br>手机：左摇杆移动 / 右摇杆瞄准射击</p><button class="pink" onclick="start()">开始突围 ↗</button><p style="font-size:11px">音效将在开始后启用 · 支持随时静音</p></div>')}
function start(){
  unlockAudio();p={x:150,y:355,r:14,hp:100+Math.min(legacy,30)*2,max:100+Math.min(legacy,30)*2,speed:220,damage:16,rate:.24,multi:1,pierce:0,regen:0,magnet:90,xp:0,need:30,lv:1,coins:0,chain:0,freeze:0,explosive:0,leech:0,orbit:0,crit:.08,orbitCD:0};
  const types=['fight',...shuffled(['fight','fight','treasure','shop','fight','event','fight','treasure','shop','fight']),'boss'];
  const variants=shuffled(['lanes','poison','cover']);
  rooms=types.map((type,i)=>makeRoom(type,i===11?'arena':variants[i%3],i));
  ri=0;kills=0;visited=0;elapsed=0;shot=0;dash=0;dashTime=0;inv=0;pending=0;chosen=[];runDamage=0;runCrits=0;maxFloor=1;settled=false;state='play';$('overlay').style.display='none';resetInput();enter(0);
}
function makeRoom(type,variant,i){
  const decor=Array.from({length:9},(_,n)=>({x:100+n%5*215,y:n<5?122:566,color:['#e54991','#50d8cf','#e9ad58'][n%3],label:['拉面','焼鳥','深夜食堂','茶','電玩','章魚燒','花屋','酒場','雑貨'][n]}));
  // The shop facades have real collision rectangles. Interior vendor carts create usable cover.
  const obstacles=decor.map(s=>({x:s.x-76,y:s.y-40,w:156,h:102,kind:'stall'}));
  const layouts={
    cover:[{x:310,y:260,w:96,h:74,kind:'cart'},{x:700,y:400,w:100,h:74,kind:'cart'},{x:760,y:225,w:72,h:64,kind:'crate'}],
    lanes:[{x:325,y:206,w:82,h:192,kind:'cart'},{x:715,y:355,w:82,h:184,kind:'cart'}],
    poison:[{x:330,y:405,w:90,h:70,kind:'crate'},{x:710,y:230,w:90,h:70,kind:'cart'}],
    arena:[{x:310,y:230,w:70,h:65,kind:'crate'},{x:710,y:430,w:70,h:65,kind:'crate'}]
  };
  obstacles.push(...layouts[variant].map(o=>({...o})));
  return {type,variant,index:i,seen:false,clear:false,used:false,stock:{barrel:1},decor,obstacles,hazards:variant==='poison'?[{x:435,y:232,w:180,h:75},{x:550,y:420,w:125,h:80}]:[],drops:[],healPity:0};
}
function enter(i){
  if(rooms[ri]?.seen)rooms[ri].drops=drops;
  ri=i;const r=rooms[i];if(!r.seen){r.seen=true;visited++}maxFloor=Math.max(maxFloor,i+1);
  p.x=150;p.y=355;bullets=[];particles=[];effects=[];numbers=[];drops=r.drops;enemies=[];inv=Math.max(inv,.5);dashTime=0;
  if(!r.clear&&(r.type==='fight'||r.type==='boss')){
    if(r.type==='boss')spawn('boss',865,355);else for(let j=0;j<4+Math.floor(i*.55);j++){const pool=i<2?['chase','gun']:['chase','gun','dash','tank'];spawn(pool[j%pool.length],rand(440,980),rand(225,510))}
  }else r.clear=true;
  const names={fight:'危险街区 · 清除所有敌人',treasure:'遗失货箱 · 靠近中央按 E',shop:'深夜补给 · 拉面可反复购买',event:'神秘摊主 · 靠近中央按 E',boss:'夜市之王 · 小心二阶段弹幕'};
  message(names[r.type]+' / '+({cover:'摊车掩体',lanes:'错位窄道',poison:'泄漏毒池',arena:'终局街口'})[r.variant]);updateUI();
}
function spawn(type,x,y){
  const boss=type==='boss',hp=boss?1250:type==='tank'?105+ri*5:38+ri*4;
  const e={id:nextId++,type,x,y,hp,max:hp,r:boss?38:type==='tank'?23:16,t:rand(0,2),cd:rand(.4,1),speed:boss?60:type==='dash'?140:type==='tank'?60:95,slow:0,freeze:0,mode:'seek',timer:0,burst:0,burstCD:0,chargeX:0,chargeY:0};
  for(let n=0;n<100&&blocked(e.x,e.y,e.r);n++){e.x=rand(450,990);e.y=rand(220,510)}
  enemies.push(e);return e;
}
function circleBox(x,y,r,o){return Math.hypot(x-clamp(x,o.x,o.x+o.w),y-clamp(y,o.y,o.y+o.h))<r}
function blocked(x,y,r){return rooms[ri].obstacles.some(o=>circleBox(x,y,r,o))}
// Split movement prevents tunnelling even during charge/dash. Axis resolution permits wall sliding.
function moveBody(body,dx,dy){
  const count=Math.max(1,Math.ceil(Math.max(Math.abs(dx),Math.abs(dy))/6));let collided=false;
  for(let n=0;n<count;n++){
    let x=clamp(body.x+dx/count,45+body.r,1055-body.r),y=clamp(body.y+dy/count,195+body.r,535-body.r);
    if(!blocked(x,body.y,body.r))body.x=x;else collided=true;
    if(!blocked(body.x,y,body.r))body.y=y;else collided=true;
  }return collided;
}
function moveEnemy(e,dx,dy){moveBody(e,dx,dy)}
// Small navigation grid keeps seekers from endlessly pressing into a vendor cart.
function navigationAngle(e,dt){
  if(visible(e,p)){e.waypoint=null;return Math.atan2(p.y-e.y,p.x-e.x)}
  e.navCD=(e.navCD||0)-dt;
  if(e.navCD<=0||!e.waypoint||dist(e,e.waypoint)<15){
    e.navCD=.55;const cols=31,rows=10,cell=32,origin={x:65,y:220};
    const point=n=>({x:origin.x+n%cols*cell,y:origin.y+Math.floor(n/cols)*cell});
    const index=o=>clamp(Math.round((o.y-origin.y)/cell),0,rows-1)*cols+clamp(Math.round((o.x-origin.x)/cell),0,cols-1);
    const start=index(e),goal=index(p),queue=[start],parents=new Map([[start,-1]]);let found=false;
    for(let q=0;q<queue.length;q++){const n=queue[q];if(n===goal){found=true;break}const x=n%cols,y=Math.floor(n/cols);
      for(const [nx,ny] of [[x+1,y],[x-1,y],[x,y+1],[x,y-1]]){if(nx<0||nx>=cols||ny<0||ny>=rows)continue;const next=ny*cols+nx,pos=point(next);if(parents.has(next)||blocked(pos.x,pos.y,e.r))continue;parents.set(next,n);queue.push(next)}
    }
    e.waypoint=null;if(found&&goal!==start){let n=goal;while(parents.get(n)!==start&&parents.get(n)!==-1)n=parents.get(n);e.waypoint=point(n)}
  }
  const target=e.waypoint||p;return Math.atan2(target.y-e.y,target.x-e.x);
}
function segmentBox(x0,y0,x1,y1,o,pad=0){
  let lo=0,hi=1;const dx=x1-x0,dy=y1-y0;
  for(const [start,delta,min,max] of [[x0,dx,o.x-pad,o.x+o.w+pad],[y0,dy,o.y-pad,o.y+o.h+pad]]){
    if(Math.abs(delta)<1e-8){if(start<min||start>max)return null;continue}
    let a=(min-start)/delta,b=(max-start)/delta;if(a>b)[a,b]=[b,a];lo=Math.max(lo,a);hi=Math.min(hi,b);if(lo>hi)return null;
  }return lo;
}
function wallHit(x0,y0,x1,y1,pad=0){let t=null;for(const o of rooms[ri].obstacles){const h=segmentBox(x0,y0,x1,y1,o,pad);if(h!==null&&(t===null||h<t))t=h}return t}
function visible(a,b){return wallHit(a.x,a.y,b.x,b.y)===null}
function segmentCircle(x0,y0,x1,y1,e,r){let dx=x1-x0,dy=y1-y0;const t=clamp(((e.x-x0)*dx+(e.y-y0)*dy)/(dx*dx+dy*dy||1),0,1);return Math.hypot(e.x-(x0+dx*t),e.y-(y0+dy*t))<r?t:null}
function tryDash(){
  if(state!=='play'||dash>0)return false;
  let dx=(keys.ArrowRight||keys.d?1:0)-(keys.ArrowLeft||keys.a?1:0)+touch.move.x;
  let dy=(keys.ArrowDown||keys.s?1:0)-(keys.ArrowUp||keys.w?1:0)+touch.move.y;
  if(Math.hypot(dx,dy)<.1){const a=aimAngle();dx=Math.cos(a);dy=Math.sin(a)}
  const len=Math.hypot(dx,dy);dashVector={x:dx/len,y:dy/len};dash=DASH_COOLDOWN;dashTime=.2;inv=Math.max(inv,.24);sfx('dash');burst(p.x,p.y,'#66ffdc',15);return true;
}
const upgrades=[
  ['过载电容','伤害 +30%',()=>p.damage*=1.3],['极速扳机','射速 +25%（最低间隔 0.08 秒）',()=>p.rate=Math.max(.08,p.rate*.8)],
  ['双生弹道','额外一枚弹丸，最多五枚',()=>p.multi=Math.min(5,p.multi+1)],['热汤续命','生命上限 +25，恢复 40 生命',()=>{p.max+=25;heal(40)}],
  ['轻盈步伐','移动速度 +15%，最多 340',()=>p.speed=Math.min(340,p.speed*1.15)],['磁力芯片','拾取范围 +80',()=>p.magnet+=80],
  ['穿巷弹头','穿透一名额外敌人；无法穿透掩体',()=>p.pierce++],['回春霓虹','每秒恢复 0.7 生命',()=>p.regen+=.7],
  ['雷电链','命中后连接附近敌人；再次选取增加跳跃数',()=>p.chain++],['绝对零度','子弹减速，连续三次命中冻结；再次选取延长冻结',()=>p.freeze++],
  ['爆炸弹','命中后小范围爆炸；再次选取增加范围与伤害',()=>p.explosive++],['血色回路','子弹命中吸血，恢复实际伤害的 4% / 层',()=>p.leech++],
  ['环绕刃','获得一枚近战旋转刀刃，最多四枚',()=>p.orbit=Math.min(4,p.orbit+1)],['致命节拍','暴击率 +15%；暴击造成双倍伤害',()=>p.crit=Math.min(.8,p.crit+.15)]
];
function availableUpgrades(){return upgrades.map((u,i)=>i).filter(i=>!(i===2&&p.multi>=5)&&!(i===4&&p.speed>=340)&&!(i===12&&p.orbit>=4)&&!(i===13&&p.crit>=.8))}
function choose(){if(state==='dead'||state==='win'||!pending)return;state='upgrade';sfx('level');offered=shuffled(availableUpgrades()).slice(0,3);overlay('<div><div class="eyebrow">LEVEL UP / LV. '+p.lv+'</div><h2>让霓虹流入血液</h2><p>选择一项强化，本局持续生效。异能可叠加组合。</p><div class="cards">'+offered.map((id,i)=>`<button class="card" onclick="pick(${id})"><span>0${i+1} / AUGMENT</span><strong>${upgrades[id][0]}</strong><small>${upgrades[id][1]}</small></button>`).join('')+'</div></div>')}
function pick(id){if(state!=='upgrade'||!offered.includes(id))return;upgrades[id][2]();chosen.push(upgrades[id][0]);pending--;offered=[];sfx('pick');close();updateUI()}
function addXP(amount){p.xp+=amount;while(p.xp>=p.need){p.xp-=p.need;p.need+=20;p.lv++;pending++}}
function interact(){
  if(state!=='play')return;const r=rooms[ri];if(!r.clear||dist(p,{x:550,y:355})>105)return;
  if(r.type==='shop'){shop();return}if(r.used)return;
  if(r.type==='treasure'){r.used=true;p.coins+=30;p.lv++;pending++;choose()}
  if(r.type==='event'){state='event';overlay('<div><div class="eyebrow">UNKNOWN ENCOUNTER</div><h2>雨棚下的交易</h2><p>付出 20 生命，获得一次三选一强化与 25 代币。<br>生命不足时无法交易；你也可以安全离开。</p><div class="menu-actions"><button class="pink" onclick="trade()">接受交易</button><button class="ghost" onclick="close()">转身离开</button></div></div>')}
}
function shop(note=''){
  state='shop';const stock=rooms[ri].stock;
  overlay(`<div><div class="eyebrow">24H / LATE NIGHT SUPPLY</div><h2>深夜补给</h2><p>现有代币 ¥ ${p.coins} · 生命 ${Math.ceil(p.hp)} / ${p.max}<br>拉面不限量，枪管每个摊位限购一次。离开后可再次光临。</p><div class="cards"><button class="card" onclick="buy(0)" ${p.coins<20||p.hp>=p.max?'disabled':''}><strong>热腾腾拉面</strong><small>恢复 50 生命<br>¥ 20 · 不限量</small></button><button class="card" onclick="buy(1)" ${p.coins<30||!stock.barrel?'disabled':''}><strong>改装枪管</strong><small>本局伤害 +35%<br>${stock.barrel?'¥ 30 · 剩余 1':'已售罄'}</small></button></div><button class="ghost" onclick="close()">离开摊位</button><p id="shopmsg" aria-live="polite">${note}</p></div>`);
}
function buy(id){if(state!=='shop'||![0,1].includes(id))return;const r=rooms[ri],cost=id?30:20;if(p.coins<cost){shop('代币不足');return}if(id&&!r.stock.barrel){shop('枪管已售罄');return}if(!id&&p.hp>=p.max){shop('生命已满，无需购买');return}p.coins-=cost;if(id){p.damage*=1.35;r.stock.barrel--}else heal(50);sfx('pick');shop(id?'枪管已安装，欢迎继续购买补给':'恢复 50 点生命，欢迎继续购买');updateUI()}
function trade(){if(state!=='event'||rooms[ri].used)return;if(p.hp<=20){message('生命不足，无法交易');close();return}p.hp-=20;p.coins+=25;rooms[ri].used=true;p.lv++;pending++;choose()}
function heal(n){const actual=Math.min(n,p.max-p.hp);p.hp+=actual;if(actual>=1){floating(p.x,p.y-15,'+'+Math.ceil(actual),'#79ffb2');sfx('heal')}return actual}
function floating(x,y,text,color='#fff'){numbers.push({x,y,text,color,life:.75})}
function burst(x,y,color,n=10){for(let i=0;i<n;i++)particles.push({x,y,vx:rand(-140,140),vy:rand(-140,140),life:rand(.15,.6),color});if(particles.length>450)particles.splice(0,particles.length-450)}
function damage(n){if(state!=='play'||inv>0)return;p.hp=Math.max(0,p.hp-n);runDamage+=n;inv=.7;shake=9;burst(p.x,p.y,'#ff518d');floating(p.x,p.y-25,'−'+n,'#ff759f');sfx('hurt');if(p.hp<=0)end(false)}
function hitEnemy(e,amount,crit=false,color='#d8fff3'){
  if(e.hp<=0)return 0;const actual=Math.min(e.hp,amount);e.hp-=amount;floating(e.x+rand(-8,8),e.y-e.r,`${crit?'暴击 ':''}${Math.ceil(amount)}`,crit?'#ffe082':color);if(crit){runCrits++;shake=Math.max(shake,3);sfx('crit')}else sfx('hit');burst(e.x,e.y,crit?'#ffe082':'#ff69a1',4);return actual;
}
function projectileHit(e,b){
  const crit=Math.random()<p.crit,amount=b.damage*(crit?2:1),actual=hitEnemy(e,amount,crit);
  if(p.leech)heal(actual*.04*p.leech);
  if(p.freeze&&e.hp>0){e.slow=2;e.freezeHits=(e.freezeHits||0)+1;if(e.freezeHits>=3){e.freezeHits=0;e.freeze=(e.type==='boss'?.22:.7)+p.freeze*.18;floating(e.x,e.y-40,'冻结','#91eaff')}}
  if(p.explosive){const radius=55+Math.min(p.explosive,5)*12;effects.push({type:'blast',x:e.x,y:e.y,r:radius,life:.28});sfx('boom');for(const other of enemies)if(other!==e&&other.hp>0&&dist(e,other)<radius+other.r&&visible(e,other))hitEnemy(other,b.damage*(.35+p.explosive*.12),false,'#ffc77a')}
  if(p.chain){const hit=new Set([e.id]);let source=e;for(let n=0;n<Math.min(6,p.chain+1);n++){const target=enemies.filter(o=>o.hp>0&&!hit.has(o.id)&&dist(source,o)<210&&visible(source,o)).sort((a,b)=>dist(source,a)-dist(source,b))[0];if(!target)break;effects.push({type:'chain',x:source.x,y:source.y,x2:target.x,y2:target.y,life:.16});hitEnemy(target,b.damage*.55,false,'#89c9ff');hit.add(target.id);source=target;sfx('shock')}}
}
function aimAngle(){
  if(touch.firing){if(!touch.aimManual){const target=enemies.filter(e=>e.hp>0&&visible(p,e)).sort((a,b)=>dist(a,p)-dist(b,p))[0];if(target)return Math.atan2(target.y-p.y,target.x-p.x)}return Math.atan2(touch.aim.y,touch.aim.x)}
  return Math.atan2(mouse.y-p.y,mouse.x-p.x);
}
function shoot(){let a=aimAngle();for(let j=0;j<p.multi;j++){const ang=a+(j-(p.multi-1)/2)*.14;bullets.push({x:p.x,y:p.y,vx:Math.cos(ang)*650,vy:Math.sin(ang)*650,life:1.6,damage:p.damage,pierce:p.pierce,hit:new Set()})}sfx('shot');burst(p.x+Math.cos(a)*23,p.y+Math.sin(a)*23,'#6cffe0',3)}
function enemyShot(e,a,speed=195){bullets.push({x:e.x,y:e.y,vx:Math.cos(a)*speed,vy:Math.sin(a)*speed,life:6,enemy:true})}
function updateEnemies(dt){for(const e of enemies){
  if(e.hp<=0)continue;e.t+=dt;e.cd-=dt;e.slow=Math.max(0,e.slow-dt);e.freeze=Math.max(0,e.freeze-dt);if(e.freeze>0)continue;
  const a=Math.atan2(p.y-e.y,p.x-e.x),walk=navigationAngle(e,dt),d=dist(p,e),slow=e.slow>0?.5:1;
  if(e.type==='tank'){
    if(e.mode==='windup'){e.timer-=dt;if(e.timer<=0){e.mode='charge';e.timer=.6;sfx('dash')}}
    else if(e.mode==='charge'){e.timer-=dt;const hit=moveBody(e,e.chargeX*500*dt*slow,e.chargeY*500*dt*slow);if(hit||e.timer<=0){e.mode='recover';e.timer=.95;effects.push({type:'blast',x:e.x,y:e.y,r:40,life:.22})}}
    else if(e.mode==='recover'){e.timer-=dt;if(e.timer<=0){e.mode='seek';e.cd=1.8}}
    else if(e.cd<=0&&d<520&&visible(e,p)){e.mode='windup';e.timer=.85;e.chargeX=Math.cos(a);e.chargeY=Math.sin(a)}
    else moveEnemy(e,Math.cos(walk)*e.speed*dt*slow,Math.sin(walk)*e.speed*dt*slow);
  }else if(e.type==='gun'){
    const s=!visible(e,p)?75:d<210?-65:d>340?75:0;moveEnemy(e,(Math.cos(walk)*s-Math.sin(walk)*25)*dt*slow,(Math.sin(walk)*s+Math.cos(walk)*25)*dt*slow);
    if(e.cd<=0&&!e.burst&&visible(e,p)){e.burst=3;e.burstCD=.18;e.cd=2.1}
    if(e.burst>0){e.burstCD-=dt;if(e.burstCD<=0){if(visible(e,p))enemyShot(e,a);e.burst--;e.burstCD=.15}}
  }else if(e.type==='dash'){
    if(e.mode==='windup'){e.timer-=dt;if(e.timer<=0){e.mode='charge';e.timer=.28}}
    else if(e.mode==='charge'){e.timer-=dt;const hit=moveBody(e,e.chargeX*380*dt*slow,e.chargeY*380*dt*slow);if(hit||e.timer<=0){e.mode='seek';e.cd=1.4}}
    else if(e.cd<=0&&d<400&&visible(e,p)){e.mode='windup';e.timer=.35;e.chargeX=Math.cos(a);e.chargeY=Math.sin(a)}
    else moveEnemy(e,Math.cos(walk+.4*Math.sin(e.t*4))*e.speed*dt*slow,Math.sin(walk+.4*Math.sin(e.t*4))*e.speed*dt*slow);
  }else if(e.type==='boss'){
    moveEnemy(e,Math.cos(walk)*e.speed*dt*slow,Math.sin(walk)*e.speed*dt*slow);
    if(e.cd<=0){const phase=e.hp<e.max/2;e.cd=phase?.8:1.3;for(let j=0;j<(phase?18:12);j++)enemyShot(e,j/(phase?18:12)*TAU+e.t*.35,phase?210:175);if(phase)for(let j=-1;j<=1;j++)enemyShot(e,a+j*.12,285)}
  }else moveEnemy(e,Math.cos(walk)*e.speed*dt*slow,Math.sin(walk)*e.speed*dt*slow);
  if(dist(e,p)<e.r+p.r)damage(e.type==='boss'?24:e.type==='tank'&&e.mode==='charge'?22:12);
  if(state!=='play')return;
}}
function updateBullets(dt){for(const b of bullets){
  if(b.life<=0)continue;const x0=b.x,y0=b.y,x1=x0+b.vx*dt,y1=y0+b.vy*dt,wall=wallHit(x0,y0,x1,y1,3);b.life-=dt;
  const hits=(b.enemy?[p]:enemies).filter(e=>b.enemy||e.hp>0&&!b.hit.has(e.id)).map(e=>({e,t:segmentCircle(x0,y0,x1,y1,e,e.r+(b.enemy?4:3))})).filter(h=>h.t!==null&&(wall===null||h.t<wall)).sort((a,b)=>a.t-b.t);
  for(const {e} of hits){if(b.enemy){damage(10);b.life=0;break}projectileHit(e,b);b.hit.add(e.id);if(--b.pierce<0){b.life=0;break}}
  b.x=x1;b.y=y1;if(wall!==null){burst(x0+(x1-x0)*wall,y0+(y1-y0)*wall,b.enemy?'#ff79ac':'#9fffe6',3);b.life=0}
  if(state!=='play')break;
}bullets=bullets.filter(b=>b.life>0&&b.x>40&&b.x<1060&&b.y>180&&b.y<545)}
function collectDrop(d,winning=false){if(d.dead)return;d.dead=true;p.coins+=d.coins||0;addXP(d.xp||0);if(d.heal)heal(d.heal);sfx('pick');if(winning&&pending){pending=0}}
function resolveKills(){let won=false;for(const e of enemies){if(e.hp>0||e.rewarded)continue;e.rewarded=true;kills++;burst(e.x,e.y,'#ff60a2',20);
  if(e.type==='boss'){collectDrop({xp:150,coins:100},true);won=true;continue}
  drops.push({x:e.x,y:e.y,xp:12,coins:e.type==='tank'?8:5});const r=rooms[ri];r.healPity++;if(Math.random()<.18||r.healPity>=5){r.healPity=0;drops.push({x:e.x+9,y:e.y-8,heal:16})}
}enemies=enemies.filter(e=>e.hp>0);if(won){for(const d of drops)collectDrop(d,true);end(true);return true}return false}
function updateDrops(dt){for(const d of drops){let distance=dist(d,p);if(distance<p.magnet){d.x+=(p.x-d.x)*Math.min(1,dt*9);d.y+=(p.y-d.y)*Math.min(1,dt*9)}if(distance<24)collectDrop(d)}drops=drops.filter(d=>!d.dead)}
function orbitPosition(i){const a=elapsed*2.7+i/Math.max(1,p.orbit)*TAU;return {x:p.x+Math.cos(a)*62,y:p.y+Math.sin(a)*62}}
function tick(dt){
  if(state!=='play')return;elapsed+=dt;shot-=dt;dash=Math.max(0,dash-dt);dashTime=Math.max(0,dashTime-dt);inv=Math.max(0,inv-dt);shake*=.85;p.hp=Math.min(p.max,p.hp+p.regen*dt);
  let dx=(keys.ArrowRight||keys.d?1:0)-(keys.ArrowLeft||keys.a?1:0)+touch.move.x,dy=(keys.ArrowDown||keys.s?1:0)-(keys.ArrowUp||keys.w?1:0)+touch.move.y,len=Math.max(1,Math.hypot(dx,dy));
  if(dashTime>0)moveBody(p,dashVector.x*p.speed*3*dt,dashVector.y*p.speed*3*dt);else moveBody(p,dx/len*p.speed*dt,dy/len*p.speed*dt);
  for(const h of rooms[ri].hazards)if(circleBox(p.x,p.y,p.r,h))damage(6);if(state!=='play')return;
  if((mouse.down||touch.firing)&&shot<=0){shot=p.rate;shoot()}
  updateEnemies(dt);if(state!=='play')return;updateBullets(dt);if(state!=='play')return;
  if(p.orbit){for(const e of enemies){e.orbitCD=Math.max(0,(e.orbitCD||0)-dt);if(e.hp>0&&e.orbitCD<=0){for(let i=0;i<p.orbit;i++){const blade=orbitPosition(i);if(dist(blade,e)<e.r+12&&visible(p,e)){hitEnemy(e,p.damage*.7,false,'#c8aeff');e.orbitCD=.3;break}}}}}
  if(resolveKills())return;updateDrops(dt);
  let r=rooms[ri];if(!enemies.length&&!r.clear){r.clear=true;p.coins+=10;message('街区清空 · 出口已开启 +10 代币');sfx('pick')}
  if(pending){choose();updateUI();return}
  if(r.clear&&p.x>1010&&p.y>302&&p.y<402&&ri<11){enter(ri+1);return}
  if(r.clear&&p.x<80&&p.y>302&&p.y<402&&ri>0){enter(ri-1);p.x=970;return}
  if(toastTime>0){toastTime-=dt;if(toastTime<=0)$('toast').textContent=''}
  updateUI();
}
function rating(win){if(!win)return maxFloor>=9?'B':maxFloor>=5?'C':'D';return elapsed<360&&runDamage<100?'S':elapsed<600?'A':'B'}
function end(win){
  if(settled)return;settled=true;state=win?'win':'dead';resetInput();pending=0;
  const gain=win?5:Math.max(1,Math.floor(kills/8));legacy+=gain;best=Math.max(best,kills);stats.runs++;stats.totalKills+=kills;stats.maxFloor=Math.max(stats.maxFloor,maxFloor);if(win){stats.wins++;stats.bestTime=stats.bestTime==null?elapsed:Math.min(stats.bestTime,elapsed)}
  try{localStorage.neonLegacy=legacy;localStorage.neonBest=best;localStorage.neonStats=JSON.stringify(stats)}catch{}
  legacyUI();updateUI();sfx(win?'win':'dead');const rank=rating(win);
  overlay(`<div><div class="eyebrow">${win?'DAWN HAS ARRIVED':'THE NIGHT IS NOT OVER'}</div><h2>${win?'天亮了。':'迷失在霓虹里'}</h2><div class="grade">${rank} <span style="font-size:14px">评级</span></div><div class="summary"><span><b>${timeText(elapsed)}</b>${win?'通关时长':'生存时长'}</span><span><b>${maxFloor}/12</b>最高街区</span><span><b>${kills}</b>本局击败</span><span><b>${p.coins}</b>剩余代币</span><span><b>${p.lv}</b>最终等级</span><span><b>${runCrits}</b>暴击次数</span></div><p>${win?'Boss 奖励已自动到账：150 经验 + 100 代币。':'下一次，带着新的印记重返夜市。'}<br>获得 ${gain} 枚永久印记 · 累计击败 ${stats.totalKills}<br>${win?'S：6 分钟内且受伤少于 100；A：10 分钟内；其他通关为 B。':'失败评级按最高街区计：9 区 B / 5 区 C / 其余 D。'}</p><div class="menu-actions"><button class="pink" onclick="start()">再次突围 ↗</button><button class="ghost" onclick="title()">回主菜单</button></div></div>`);
}
function pause(){if(state==='play'){state='pause';overlay('<div><div class="eyebrow">TAKE A BREATH</div><h2>夜市暂停营业</h2><p>重新开始或回到主菜单会放弃本局。永久成长保留。</p><div class="menu-actions"><button class="pink" onclick="close()">继续游戏</button><button class="ghost" onclick="start()">重新开始</button><button class="ghost" onclick="title()">回主菜单</button></div></div>')}else if(state==='pause')close()}
function updateUI(){if(!p)return;
  $('health').textContent=`♥ ${Math.ceil(p.hp)} / ${p.max}`;$('hpbar').style.width=p.hp/p.max*100+'%';$('level').textContent=`LV. ${String(p.lv).padStart(2,'0')}　XP ${Math.floor(p.xp)} / ${p.need}`;
  $('dashbar').style.width=(1-dash/DASH_COOLDOWN)*100+'%';$('dashtext').textContent=dash>0?`冲刺冷却 ${dash.toFixed(1)}s`:'冲刺就绪 / SPACE';$('touchDash').textContent=dash>0?`冲刺 ${dash.toFixed(1)}s`:'冲刺 就绪';
  $('coins').textContent='¥ '+p.coins;$('kills').textContent=kills;$('explored').textContent=visited+' / 12';$('time').textContent=timeText(elapsed);
  $('roomlabel').innerHTML=`DISTRICT ${String(ri+1).padStart(2,'0')} / 12<br>${({cover:'摊车掩体',lanes:'错位窄道',poison:'泄漏毒池',arena:'终局街口'})[rooms[ri].variant]}<br>${enemies.length?'敌人剩余 '+enemies.length:'街区安全'}`;
  $('map').innerHTML=rooms.map((r,i)=>`<span class="${r.seen?'seen ':''}${i===ri?'here':''}">${r.seen||i===ri+1?({fight:'◆',treasure:'◇',shop:'＋',event:'?',boss:'♛'})[r.type]:'·'}</span>`).join('');
  $('objective').textContent=enemies.length?'清除威胁 · '+enemies.length+' 名敌人':ri===11?'夜市之王已陨落':'街区安全 · 在出口中央向右前进';
  const boss=enemies.find(e=>e.type==='boss');$('boss').style.display=boss?'block':'none';if(boss){$('bossbar').style.width=Math.max(0,boss.hp/boss.max)*100+'%';$('bosshealth').textContent=`${Math.max(0,Math.ceil(boss.hp))} / ${boss.max}`;$('bossname').textContent='夜市之王 / '+(boss.hp<boss.max/2?'Ⅱ 暴走':'Ⅰ 苏醒')}
  const counts={};chosen.forEach(n=>counts[n]=(counts[n]||0)+1);$('build').textContent='当前强化：'+(Object.entries(counts).map(([n,c])=>n+(c>1?' ×'+c:'')).join(' · ')||'无');
}

// Drawing deliberately uses the same obstacle rectangles as physics.
function rect(x,y,w,h,color){g.fillStyle=color;g.fillRect(x,y,w,h)}
function glow(color,blur=15){g.shadowColor=color;g.shadowBlur=blur}
function circle(x,y,r,color){g.fillStyle=color;g.beginPath();g.arc(x,y,r,0,TAU);g.fill()}
function line(x,y,x2,y2,color,width=2){g.strokeStyle=color;g.lineWidth=width;g.beginPath();g.moveTo(x,y);g.lineTo(x2,y2);g.stroke()}
function text(s,x,y,color='#fff',size=12){g.fillStyle=color;g.font=`${size}px 'Microsoft Yahei', sans-serif`;g.textAlign='center';g.fillText(s,x,y)}
function polygon(points,color){g.fillStyle=color;g.beginPath();points.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.closePath();g.fill()}
function drawObstacle(o){
  if(o.kind==='stall')return;
  rect(o.x+5,o.y+7,o.w,o.h,'#0007');rect(o.x,o.y,o.w,o.h,o.kind==='cart'?'#343348':'#494355');
  rect(o.x+3,o.y+3,o.w-6,o.h-6,'#20283b');rect(o.x,o.y,o.w,5,o.kind==='cart'?'#b5659a':'#c2a47a');
  if(o.kind==='cart'){for(let j=0;j<o.w;j+=18)rect(o.x+j,o.y+7,9,13,'#b5659a88');rect(o.x+9,o.y+27,o.w-18,7,'#5c7682');text('屋台',o.x+o.w/2,o.y+o.h-12,'#e4bad8',12)}
  else{line(o.x+7,o.y+9,o.x+o.w-7,o.y+o.h-7,'#756d62',3);line(o.x+o.w-7,o.y+9,o.x+7,o.y+o.h-7,'#756d62',3)}
}
function drawEnemy(e){
  let col=({chase:'#f95c96',gun:'#bd7bff',dash:'#ffb758',tank:'#e75768',boss:'#ff488b'})[e.type];if(e.freeze>0)col='#9cefff';else if(e.slow>0)col='#6abbdc';
  circle(e.x,e.y+e.r*.8,e.r,'#0005');
  if(e.mode==='windup'){
    line(e.x,e.y,e.x+e.chargeX*(e.type==='tank'?310:150),e.y+e.chargeY*(e.type==='tank'?310:150),'#ff786677',e.type==='tank'?32:12);
    text(e.type==='tank'?'蓄力冲锋 !':'突进 !',e.x,e.y-e.r-20,'#ffb179',12);
  }
  glow(col,8);
  if(e.type==='chase'){
    polygon([[e.x,e.y-22],[e.x+18,e.y-4],[e.x+10,e.y+17],[e.x-10,e.y+17],[e.x-18,e.y-4]],col);
    polygon([[e.x-9,e.y-15],[e.x-20,e.y-24],[e.x-16,e.y-3]],col);polygon([[e.x+9,e.y-15],[e.x+20,e.y-24],[e.x+16,e.y-3]],col);
    line(e.x-17,e.y+9,e.x-27,e.y+19,col,3);line(e.x+17,e.y+9,e.x+27,e.y+19,col,3);
  }else if(e.type==='gun'){
    polygon([[e.x-15,e.y-17],[e.x+15,e.y-17],[e.x+20,e.y],[e.x+12,e.y+19],[e.x-12,e.y+19],[e.x-20,e.y]],col);
    const a=Math.atan2(p.y-e.y,p.x-e.x);line(e.x,e.y,e.x+Math.cos(a)*29,e.y+Math.sin(a)*29,'#e2c8ff',7);circle(e.x,e.y,9,'#28223e');circle(e.x,e.y,4,'#eee1ff');
    for(let i=0;i<3;i++)circle(e.x-8+i*8,e.y-26,2,i<e.burst?'#fff1ad':'#715385');
  }else if(e.type==='dash'){
    polygon([[e.x,e.y-23],[e.x+20,e.y+16],[e.x,e.y+7],[e.x-20,e.y+16]],col);line(e.x-10,e.y+23,e.x-17,e.y+30,col);line(e.x+10,e.y+23,e.x+17,e.y+30,col);
  }else if(e.type==='tank'){
    rect(e.x-24,e.y-21,48,45,col);rect(e.x-30,e.y-16,10,30,'#9d4865');rect(e.x+20,e.y-16,10,30,'#9d4865');rect(e.x-17,e.y-13,34,25,'#39223b');
    for(let n=-1;n<=1;n++)rect(e.x-13,e.y+n*7,26,3,e.mode==='windup'?'#ffdf8e':'#ed879f');rect(e.x-19,e.y+22,10,7,col);rect(e.x+9,e.y+22,10,7,col);
  }else{
    polygon([[e.x-35,e.y-28],[e.x+35,e.y-28],[e.x+44,e.y+14],[e.x+25,e.y+37],[e.x-25,e.y+37],[e.x-44,e.y+14]],col);
    polygon([[e.x-28,e.y-34],[e.x-32,e.y-54],[e.x-10,e.y-43],[e.x,e.y-62],[e.x+10,e.y-43],[e.x+32,e.y-54],[e.x+28,e.y-34]],'#ffce7a');
    circle(e.x,e.y,23,'#301c36');rect(e.x-18,e.y-7,12,7,'#ffe4b3');rect(e.x+6,e.y-7,12,7,'#ffe4b3');rect(e.x-15,e.y+14,30,4,'#ffc18b');
  }
  g.shadowBlur=0;
  if(e.type!=='gun'&&e.type!=='boss'&&e.type!=='tank')rect(e.x-9,e.y-7,18,5,'#261c36');
  if(e.type!=='boss'){rect(e.x-e.r,e.y+e.r+12,e.r*2,3,'#3e243c');rect(e.x-e.r,e.y+e.r+12,e.r*2*Math.max(0,e.hp/e.max),3,col)}
  if(e.freeze>0){g.strokeStyle='#b6f6ff';g.lineWidth=2;g.strokeRect(e.x-e.r-4,e.y-e.r-5,e.r*2+8,e.r*2+12)}
}
function render(dt){
  g.save();g.translate(rand(-shake,shake),rand(-shake,shake));rect(0,0,W,H,'#0c1020');
  const r=rooms[ri]||makeRoom('fight','cover',0);
  rect(40,183,1020,365,'#17192c');for(let x=45;x<1060;x+=50)rect(x,183,1,365,'#242538');for(let y=183;y<548;y+=45)rect(40,y,1020,1,'#242538');
  for(let i=0;i<18;i++){let x=70+(i*167)%960,y=240+(i*79)%250;g.globalAlpha=.1;rect(x,y,80,3,i%2?'#fa559a':'#5ce8dd');g.globalAlpha=1}
  for(const h of r.hazards){rect(h.x,h.y,h.w,h.h,'#183f39');g.globalAlpha=.5+Math.sin(elapsed*3)*.15;rect(h.x+3,h.y+3,h.w-6,h.h-6,'#357d52');g.globalAlpha=1;for(let i=0;i<6;i++)circle(h.x+15+(i*43)%(h.w-20),h.y+15+(i*29)%(h.h-20),3+Math.sin(elapsed*2+i)*2,'#93e68588');text('☣ 毒水',h.x+h.w/2,h.y+h.h/2+4,'#b5e392',12)}
  for(const s of r.decor){
    rect(s.x-76,s.y-40,156,102,'#080b16');rect(s.x-69,s.y-35,142,86,'#232134');rect(s.x-76,s.y+15,156,32,'#393047');for(let j=0;j<8;j++)rect(s.x-76+j*20,s.y+15,10,32,s.color+'55');
    glow(s.color,14);rect(s.x-63,s.y-31,125,34,s.color);g.shadowBlur=0;text(s.label,s.x,s.y-8,'#171124',18);rect(s.x-60,s.y+54,120,6,s.color+'55');
  }
  line(0,83,1100,83,'#615072',1);for(let i=0;i<16;i++){let x=25+i*70,y=86+Math.sin(i/15*Math.PI)*48;glow(i%2?'#f763a1':'#ffbb77');circle(x,y,6,i%2?'#f763a1':'#ffbb77')}g.shadowBlur=0;
  r.obstacles.forEach(drawObstacle);
  if(p){
    glow(r.clear?'#67f9da':'#f24a81');rect(1040,302,8,100,r.clear?'#67f9da':'#f24a81');g.shadowBlur=0;text(r.clear?'EXIT →':'LOCKED',992,290,r.clear?'#67f9da':'#a24d72');
    if(ri>0){rect(48,310,6,80,'#75918f');text('←',75,300,'#91b9b0')}
    if(r.clear&&(!r.used||r.type==='shop')&&['shop','treasure','event'].includes(r.type)){
      glow('#ffcf69');rect(523,330,54,44,'#b57e48');rect(522,330,56,5,'#ffe19a');g.shadowBlur=0;text('E · '+({shop:'补给商店',treasure:'打开宝箱',event:'神秘交易'})[r.type],550,310,'#ffe6ad',13);
    }
    for(const d of drops){glow(d.heal?'#81ffad':'#68efdc',8);if(d.heal){rect(d.x-3,d.y-9,6,18,'#81ffad');rect(d.x-9,d.y-3,18,6,'#81ffad')}else polygon([[d.x,d.y-6],[d.x+5,d.y],[d.x,d.y+6],[d.x-5,d.y]],'#68efdc')}g.shadowBlur=0;
    enemies.forEach(drawEnemy);
    const a=aimAngle();circle(p.x,p.y+17,17,'#0007');g.globalAlpha=inv>0?.5+Math.sin(elapsed*40)*.3:1;glow('#61ffe0',14);rect(p.x-12,p.y-7,24,27,'#64e7db');circle(p.x,p.y-13,12,'#e1f6ee');rect(p.x-12,p.y-17,24,7,'#163443');rect(p.x-15,p.y+2,6,17,'#ff518d');
    g.save();g.translate(p.x,p.y);g.rotate(a);rect(6,-4,30,8,'#b6e9ef');rect(26,-3,13,6,'#6dffda');g.restore();g.shadowBlur=0;g.globalAlpha=1;
    for(let i=0;i<p.orbit;i++){const b=orbitPosition(i);glow('#bca0ff');g.save();g.translate(b.x,b.y);g.rotate(elapsed*7);polygon([[0,-15],[8,0],[0,15],[-8,0]],'#cbb8ff');g.restore()}g.shadowBlur=0;
    for(const b of bullets){glow(b.enemy?'#ff588d':p.explosive?'#ffc06b':p.freeze?'#9feaff':'#7affe8',10);circle(b.x,b.y,b.enemy?5:4,b.enemy?'#ff588d':p.explosive?'#ffc06b':p.freeze?'#9feaff':'#affff1')}g.shadowBlur=0;
  }
  for(const fx of effects){g.globalAlpha=Math.min(1,fx.life*5);if(fx.type==='chain'){glow('#85bfff');const mx=(fx.x+fx.x2)/2+rand(-8,8),my=(fx.y+fx.y2)/2+rand(-8,8);line(fx.x,fx.y,mx,my,'#a4d9ff',3);line(mx,my,fx.x2,fx.y2,'#a4d9ff',3);g.shadowBlur=0}else{g.strokeStyle='#ffbe75';g.lineWidth=3;g.beginPath();g.arc(fx.x,fx.y,fx.r*(1-fx.life/.4),0,TAU);g.stroke()}if(state==='play')fx.life-=dt}effects=effects.filter(f=>f.life>0);g.globalAlpha=1;
  for(const q of particles){if(state==='play'){q.x+=q.vx*dt;q.y+=q.vy*dt;q.life-=dt}g.globalAlpha=Math.max(0,q.life*1.8);rect(q.x,q.y,3,3,q.color)}particles=particles.filter(q=>q.life>0);g.globalAlpha=1;
  for(const n of numbers){if(state==='play'){n.y-=dt*38;n.life-=dt}g.globalAlpha=Math.min(1,Math.max(0,n.life*2));text(n.text,n.x,n.y,n.color,n.text.includes('暴击')?18:14)}numbers=numbers.filter(n=>n.life>0);g.globalAlpha=1;
  g.strokeStyle='#88a6c411';g.lineWidth=1;g.beginPath();for(let i=0;i<75;i++){const x=(i*97+elapsed*85)%W,y=(i*113+elapsed*400)%H;g.moveTo(x,y);g.lineTo(x-4,y+14)}g.stroke();
  const vign=g.createRadialGradient(550,355,240,550,355,650);vign.addColorStop(0,'transparent');vign.addColorStop(1,'#03050cbb');g.fillStyle=vign;g.fillRect(0,0,W,H);g.restore();
}

// Keyboard edges, rather than held-state polling, own discrete actions.
function keyDown(e){
  if(['ArrowUp','ArrowDown','ArrowLeft','ArrowRight',' '].includes(e.key))e.preventDefault();
  const key=e.key.length===1?e.key.toLowerCase():e.key,wasDown=!!keys[key];keys[key]=true;unlockAudio();
  if(e.repeat||wasDown)return;if(key===' ')tryDash();if(key==='e')interact();if(key==='Escape')pause();
}
function keyUp(e){const key=e.key.length===1?e.key.toLowerCase():e.key;keys[key]=false}
window.addEventListener('keydown',keyDown);window.addEventListener('keyup',keyUp);
window.addEventListener('blur',()=>{resetInput();if(state==='play')pause()});
document.addEventListener('visibilitychange',()=>{if(document.hidden){resetInput();if(state==='play')pause()}});
function updateMouse(e){const r=C.getBoundingClientRect();mouse.x=(e.clientX-r.left)/r.width*W;mouse.y=(e.clientY-r.top)/r.height*H}
C.addEventListener('pointermove',e=>{if(e.pointerType!=='touch')updateMouse(e)});
C.addEventListener('pointerdown',e=>{unlockAudio();if(e.pointerType!=='touch'&&e.button===0&&state==='play'){updateMouse(e);mouse.down=true}});
window.addEventListener('pointerup',()=>mouse.down=false);window.addEventListener('pointercancel',()=>mouse.down=false);C.addEventListener('contextmenu',e=>e.preventDefault());
function setupStick(zoneId,knobId,kind){
  const zone=$(zoneId),knob=$(knobId);let pointer=null;
  function update(e){const r=zone.getBoundingClientRect(),dx=e.clientX-r.left-r.width/2,dy=e.clientY-r.top-r.height/2,max=r.width*.34,len=Math.hypot(dx,dy),scale=Math.max(max,len);const v={x:dx/scale,y:dy/scale};knob.style.transform=`translate(${v.x*max}px,${v.y*max}px)`;
    if(kind==='move')touch.move=len<8?{x:0,y:0}:v;else{touch.firing=true;touch.aimManual=len>12;if(len>12)touch.aim=v}}
  zone.addEventListener('pointerdown',e=>{e.preventDefault();if(state!=='play'||pointer!==null)return;unlockAudio();pointer=e.pointerId;zone.setPointerCapture(pointer);document.body.classList.add('touch-mode');update(e)});
  zone.addEventListener('pointermove',e=>{if(e.pointerId===pointer&&state==='play'){e.preventDefault();update(e)}});
  function release(e){if(e.pointerId!==pointer)return;pointer=null;knob.style.transform='translate(0px,0px)';if(kind==='move')touch.move={x:0,y:0};else{touch.firing=false;touch.aimManual=false}}
  for(const type of ['pointerup','pointercancel','lostpointercapture'])zone.addEventListener(type,release);
}
setupStick('moveStick','moveKnob','move');setupStick('aimStick','aimKnob','aim');
$('touchDash').addEventListener('pointerdown',e=>{e.preventDefault();unlockAudio();tryDash()});$('touchUse').addEventListener('pointerdown',e=>{e.preventDefault();interact()});
$('pause').onclick=pause;$('sound').onclick=toggleSound;$('sound').textContent=soundOn?'♫ 音效开':'♫ 音效关';
let last=performance.now();function frame(t){const dt=Math.min((t-last)/1000,.04);last=t;tick(dt);render(dt);requestAnimationFrame(frame)}
title();requestAnimationFrame(frame);
