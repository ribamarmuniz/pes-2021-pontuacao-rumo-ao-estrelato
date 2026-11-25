const fs=require('fs');
const {readStudy,defaultLog}=require('./read-study.cjs');
const {readObservations}=require('./read-observations.cjs');
const {explainPath}=require('./explain.cjs');
const {readNativeEvents}=require('./read-native-events.cjs');
const path=require('path');
const {readContextArchive}=require('./read-context-archive.cjs'),{decodeContextPacket}=require('./read-context-state.cjs');
const {instantModel}=require('./instant-model.cjs'),{observedTimeline}=require('./observed-context-model.cjs');
async function main(){
const file=process.argv[2]||defaultLog(),session=process.argv[3],source=fs.readFileSync(file,'utf8');
const observations=readObservations(file),snapshots=readStudy(file).snapshots;
const indexed=new Map(snapshots.map(s=>[s.session+':'+s.generation,s]));
const nativeEvents=new Map(readNativeEvents(file).events.map(e=>[e.session+':'+e.sequence,e]));
const lines=source.split(/\r?\n/),checks=[],failures=[];
const same=(a,b)=>a&&b&&a.length===b.length&&a.every((n,i)=>n===b[i]);
const fullContexts=new Map();
const contextArchive=process.argv[4]||path.join(__dirname,'..','bal-context-captures.balc');
if(source.includes('"groupSource":"native-observed-context"')&&fs.existsSync(contextArchive)){
 const needed=new Set();
 for(const line of lines)if(line.includes('BAL_RATING_EXPLANATION ')){
  let e;try{e=JSON.parse(line.split('BAL_RATING_EXPLANATION ')[1]);}catch{continue;}
  if((!session||e.session===session)&&e.groupSource==='native-observed-context')for(const n of e.nativeEventSequences)needed.add(e.session+':'+n);
 }
 for await(const packet of readContextArchive(contextArchive)){
  if(!needed.has(packet.meta.session+':'+packet.meta.sequence))continue;
  const g=decodeContextPacket(packet),s=snapshots.find(s=>s.session===packet.meta.session&&s.match===packet.meta.match&&s._programs);
  if(!g.valid||!s)continue;
  g.before.match=g.after.match=g.match=packet.meta.match;g.epoch=packet.meta.epoch;
  const a=instantModel(g.before,s._programs),b=instantModel(g.after,s._programs);
  if(!a||!b||a.note!==packet.meta.beforeNote||b.note!==packet.meta.afterNote)continue;
  g.beforeNote=a.note;g.afterNote=b.note;fullContexts.set(packet.meta.session+':'+g.sequence,g);
 }
}
for(let at=0;at<lines.length;at++){
 const marker='BAL_RATING_EXPLANATION ';if(!lines[at].includes(marker))continue;
 let e;try{e=JSON.parse(lines[at].split(marker)[1]);}catch(error){if(at===lines.length-1&&!source.endsWith('\n'))break;throw error;}
 if(session&&session!==e.session)continue;
 const a=indexed.get(e.session+':'+e.fromGeneration),b=indexed.get(e.session+':'+e.generation);
 if(!a||!b){failures.push({generation:e.generation,reason:'missing-snapshots'});continue;}
 const pa=a.players.find(p=>p.v[2]===2147483834),pb=b.players.find(p=>p.v[2]===2147483834);
 if(!pa||!pb){failures.push({generation:e.generation,reason:'missing-player'});continue;}
 const rows=observations.filter(o=>o.session===e.session&&o.match===e.match);
 const start=rows.findLastIndex(o=>o.time<=a.time&&same(o.s,pa.s)&&same(o.u,pa.u));
 const end=rows.findLastIndex(o=>o.time<=b.time&&same(o.s,pb.s)&&same(o.u,pb.u));
 let groups,expected;
 if(e.groupSource==='native-observed-context'){
  groups=e.nativeEventSequences.map(n=>fullContexts.get(e.session+':'+n));
  const valid=groups.every((g,i)=>g&&g.match===e.match&&g.epoch===e.epoch&&g.generationBefore>=a.generation&&g.generationAfter<b.generation&&(!i||g.sequence>groups[i-1].sequence));
  expected=valid?observedTimeline(a,b,groups):null;
 }else if(['native-dispatch-events','native-event-boundaries'].includes(e.groupSource)){
  const selected=(e.nativeEventSequences||[]).map(n=>nativeEvents.get(e.session+':'+n));
  const valid=selected.every((n,i)=>n&&n.match===e.match&&(!i||(n.sequence>selected[i-1].sequence&&n.epoch===selected[i-1].epoch)));
  groups=valid?selected.map(n=>({previous:n.before,s:n.after.s,u:n.after.u,chainCoherent:true,label:n.contextUpdate?'Contexto':undefined})):null;
  expected=groups?explainPath(a,b,groups):null;
 }else{
  groups=rows.slice(start+1,end+1).filter(o=>o.changes.length||(o.uniqueChanges||[]).length);
  expected=start<0||end<start?null:explainPath(a,b,groups);
 }
 let valid=!!expected;
 if(expected){
  for(const k of ['from','to','total','playerEffect','remainingEffect'])if(e[k]!==expected[k])valid=false;
  if(!same(e.stateNotes,expected.stateNotes)||JSON.stringify(e.components)!==JSON.stringify(expected.components))valid=false;
 }
 checks.push({session:e.session,generation:e.generation,valid,total:e.total,components:e.components,remainingEffect:e.remainingEffect,
  groupSource:e.groupSource||'sampled-input-groups',nativeEventCount:e.nativeEventSequences?.length||0});
 if(!valid)failures.push({generation:e.generation,expected:expected?{stateNotes:expected.stateNotes,components:expected.components}:null,observed:e});
}
console.log(JSON.stringify({checks,failures,historicalActionAttribution:false},null,2));
if(failures.length)process.exitCode=1;else if(!checks.length)process.exitCode=2;
}
main().catch(error=>{console.error(error);process.exitCode=1;});
