// Deterministic controller smoke runs. This is not a substitute for human difficulty testing.
const {game}=require('./harness.cjs');
const fs=require('node:fs');
const reports=[];
for(const seed of [11,29,47]){
 const {run}=game(seed);
 run(`
 const priorities=${JSON.stringify(seed===11?[9,10,3,7,0,8,2,1,11,12]:seed===29?[8,0,1,3,7,2,9,10,11,12]:[12,11,3,7,0,8,2,1,9,10])};
 start();let stepCount=0,stuck=0,lastRoom=0,lastPos={x:p.x,y:p.y},pathTimer=0,pathPoint=null,visitedShops=new Set();
 function botPath(target){
   const cols=49,rows=16,cell=20,ox=65,oy=215;
   const point=n=>({x:ox+n%cols*cell,y:oy+Math.floor(n/cols)*cell});
   const index=o=>clamp(Math.round((o.y-oy)/cell),0,rows-1)*cols+clamp(Math.round((o.x-ox)/cell),0,cols-1);
   const start=index(p),goal=index(target),q=[start],prev=new Map([[start,-1]]);
   for(let i=0;i<q.length;i++){let n=q[i];if(n===goal){if(n===start)return target;while(prev.get(n)!==start&&prev.get(n)!==-1)n=prev.get(n);return point(n)}let x=n%cols,y=Math.floor(n/cols);for(const [nx,ny] of [[x+1,y],[x-1,y],[x,y+1],[x,y-1]]){if(nx<0||nx>=cols||ny<0||ny>=rows)continue;const next=ny*cols+nx,v=point(next);if(prev.has(next)||blocked(v.x,v.y,p.r)||rooms[ri].hazards.some(h=>circleBox(v.x,v.y,p.r,h)))continue;prev.set(next,n);q.push(next)}}return target;
 }
 for(;stepCount<40000&&!['dead','win'].includes(state);stepCount++){
   if(state==='upgrade'){pick([...offered].sort((a,b)=>(priorities.indexOf(a)<0?99:priorities.indexOf(a))-(priorities.indexOf(b)<0?99:priorities.indexOf(b)))[0]);continue}
   if(state==='shop'){if(p.hp<p.max-5&&p.coins>=20)buy(0);else if(p.coins>=30&&rooms[ri].stock.barrel)buy(1);else{visitedShops.add(ri);close()}continue}
   if(state==='event'){close();continue}
   mouse.down=true;const alive=enemies.filter(e=>e.hp>0),near=alive.filter(e=>visible(p,e)).sort((a,b)=>dist(p,a)-dist(p,b))[0]||alive[0];
   if(near){mouse.x=near.x;mouse.y=near.y}
   let target=null;
   if(!alive.length){
     if(drops.length)target=drops.reduce((a,b)=>dist(p,a)<dist(p,b)?a:b);
     else if(!rooms[ri].used&&rooms[ri].type==='treasure'||rooms[ri].type==='shop'&&!visitedShops.has(ri)){target={x:550,y:355};if(dist(p,target)<80)interact()}
     else target={x:1035,y:355};
   }else{
     const healing=drops.filter(d=>d.heal&&p.hp<p.max-10).sort((a,b)=>dist(p,a)-dist(p,b))[0];
     if(healing)target=healing;
     else{
       const angle=elapsed*.65,center=near.type==='boss'?{x:550,y:355}:near;
       target={x:clamp(center.x+Math.cos(angle)*250,100,990),y:clamp(center.y+Math.sin(angle)*125,225,505)};
       if(near.mode==='windup'||bossStrikes.length){target={x:clamp(p.x-Math.sin(near.lockAngle||0)*170,100,990),y:clamp(p.y+Math.cos(near.lockAngle||0)*140,225,505)}}
     }
   }
   if(target){if(pathTimer<=0||ri!==lastRoom||pathPoint&&dist(p,pathPoint)<14){pathPoint=botPath(target);pathTimer=.2}pathTimer-=.032;const dx=pathPoint.x-p.x,dy=pathPoint.y-p.y,len=Math.max(1,Math.hypot(dx,dy));touch.move={x:dx/len,y:dy/len};}
   if(near&&dist(p,near)<90&&dash<=0)tryDash();
   lastRoom=ri;tick(.032);render(.032);
 }
 `);
 const report=run('({state,seconds:Math.round(elapsed),floor:maxFloor,kills,hp:p.hp,level:p.lv,build:chosen,steps:stepCount})');reports.push({seed,...report});
}
console.log(JSON.stringify(reports,null,2));
if(process.argv[2])fs.writeFileSync(process.argv[2],JSON.stringify(reports,null,2));
if(reports.some(report=>report.state!=='win'))process.exitCode=1;
