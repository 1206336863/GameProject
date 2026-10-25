// Run with node --test tests/game.test.cjs. No third-party packages required.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
function game(seed=1){
  const elements={},handlers={};
  const canvas=new Proxy({createRadialGradient:()=>({addColorStop(){}})}, {get:(o,k)=>o[k]||(()=>{})});
  function element(id){return elements[id]??={style:{},innerHTML:'',textContent:'',setAttribute(){},addEventListener:(t,f)=>{handlers[id+':'+t]=f},getContext:()=>canvas,getBoundingClientRect:()=>({left:0,top:0,width:1100,height:710}),setPointerCapture(){}}}
  const storage={};const context={console,Math:Object.create(Math),Set,Map,performance:{now:()=>0},requestAnimationFrame(){},localStorage:storage,window:{addEventListener:(t,f)=>handlers['window:'+t]=f},document:{getElementById:element,addEventListener:(t,f)=>handlers['document:'+t]=f,body:{classList:{add(){}}}}};
  context.Math.random=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296};vm.createContext(context);vm.runInContext(fs.readFileSync(path.join(__dirname,'../game.js'),'utf8'),context);
  return {run:s=>vm.runInContext(s,context),elements,handlers,storage};
}

module.exports={game};
