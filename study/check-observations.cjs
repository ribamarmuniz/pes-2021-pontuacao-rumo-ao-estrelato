// Checks the observed player's counter arrays against native copied snapshots.
// Equal arrays do not establish an atomic action or a historical causal effect.
const fs=require('fs');
const {readStudy,defaultLog}=require('./read-study.cjs');
const file=process.argv[2]||defaultLog(),session=process.argv[3];
const source=fs.readFileSync(file,'utf8'),lines=source.split(/\r?\n/);
const states=[],current=new Map(),chainFailures=[];
for(let i=0;i<lines.length;i++){
 const marker='BAL_INPUT_OBSERVATION ';
 if(!lines[i].includes(marker))continue;
 let x;
 try{x=JSON.parse(lines[i].split(marker)[1]);}
 catch(error){if(i===lines.length-1&&!source.endsWith('\n'))break;throw error;}
 if(session&&x.session!==session)continue;
 const key=x.session+':'+x.match;
 let state=current.get(key);
 if(x.reset||!state)state={s:Array(135),u:Array(4)};
 for(const [field,changes] of [['s',x.changes],['u',x.uniqueChanges||[]]]){
  for(const [id,before,after] of changes){
   if(before!==-1&&state[field][id]!==undefined&&state[field][id]!==before)
    chainFailures.push({session:x.session,time:x.time,field,id,before,prior:state[field][id]});
   state[field][id]=after;
  }
 }
 current.set(key,state);
 states.push({...x,s:[...state.s],u:x.uniqueAvailable?[...state.u]:null});
}
let compared=0,aligned=0,nonzeroUnique=0;
const unaligned=[];
for(const s of readStudy(file).snapshots){
 if(session&&s.session!==session)continue;
 if(!s.match)continue;
 const p=s.players.find(p=>p.v[2]===2147483834);
 if(!p)continue;
 compared++;
 const o=states.findLast(x=>x.session===s.session&&x.match===s.match&&x.time<=s.time);
 const equal=(a,b)=>a&&a.length===b.length&&b.every((n,i)=>a[i]===n);
 if(o&&equal(o.s,p.s)&&equal(o.u,p.u)){
  aligned++;
  if(p.u.some(n=>n>0))nonzeroUnique++;
 }else unaligned.push({session:s.session,generation:s.generation,
  reason:'live-observation-does-not-match-copied-frame'});
}
console.log(JSON.stringify({compared,aligned,nonzeroUnique,chainFailures,unaligned,
 atomicAction:false,historicalActionAttribution:false},null,2));
if(chainFailures.length)process.exitCode=1;
else if(!aligned)process.exitCode=2;
