const fs=require('fs'),path=require('path'),{readNativeEvents}=require('./read-native-events.cjs');
const {readStudy,defaultLog}=require('./read-study.cjs');
const file=process.argv[2]||defaultLog(),session=process.argv[3];
const {events,gaps,resets}=readNativeEvents(file,session),snapshots=readStudy(file).snapshots;
const same=(a,b)=>a&&b&&a.length===b.length&&a.every((v,i)=>v===b[i]);
const previous=new Map(),byType=new Map(),breaks=[],failures=[],alignments=[],overlaps=[];
let originalNoteChanges=0,individualCounterUpdates=0,coherentLinks=0;
for(const event of events){
 const {before,after}=event;
 const valid=x=>x&&x.s.length===135&&x.u.length===4&&x.player.length===4&&x.player[0]===2147483834
  &&[...x.s,...x.u].every(v=>Number.isSafeInteger(v)&&v>=0);
 if(!valid(before)||!valid(after)||event.cpuTicksAfter<event.cpuTicksBefore||event.payload.length!==1600
  ||Buffer.from(event.payload,'hex').readUInt32LE()!==event.type||event.slot<0||event.slot>=80){failures.push({sequence:event.sequence,type:'invalid-event'});continue;}
 const key=event.session+':'+event.match+':'+event.epoch,prev=previous.get(key);
 if(prev){
  const changed=[];
  for(let i=0;i<135;i++)if(before.s[i]!==prev.after.s[i])changed.push(i);
  const unique=[];for(let i=0;i<4;i++)if(before.u[i]!==prev.after.u[i])unique.push(i);
  if(changed.length||unique.length)breaks.push({sequence:event.sequence,afterSequence:prev.sequence,stats:changed,unique});
  else coherentLinks++;
  if(event.sequence<=prev.sequence)failures.push({sequence:event.sequence,type:'nonmonotonic-sequence'});
  if(prev.cpuTicksAfter>event.cpuTicksBefore)overlaps.push({before:prev.sequence,after:event.sequence});
 }
 previous.set(key,event);
 const changes=[];for(let i=0;i<135;i++)if(before.s[i]!==after.s[i])changes.push(i);
 const unique=[];for(let i=0;i<4;i++)if(before.u[i]!==after.u[i])unique.push(i);
 if(before.player[3]!==after.player[3])originalNoteChanges++;
 individualCounterUpdates+=changes.length+unique.length;
 if(!byType.has(event.type))byType.set(event.type,{type:event.type,count:0,stats:new Set(),unique:new Set(),examples:[]});
 const type=byType.get(event.type);type.count++;changes.forEach(id=>type.stats.add(id));unique.forEach(id=>type.unique.add(id));
 if(type.examples.length<3)type.examples.push({sequence:event.sequence,frame:event.frame,stats:changes,unique,
  originalNoteBefore:before.player[3],originalNoteAfter:after.player[3]});
}
for(const s of snapshots){
 if(session&&s.session!==session)continue;
 const p=s.players.find(p=>p.v[2]===2147483834);if(!p)continue;
 const eligible=events.filter(e=>e.session===s.session&&e.match===s.match);
 const match=eligible.findLast(e=>e.observedAt<=s.time&&e.generationAfter<=s.generation&&same(e.after.s,p.s)&&same(e.after.u,p.u));
 if(match)alignments.push({session:s.session,generation:s.generation,sequence:match.sequence});
}
const report={status:!events.length?'awaiting-events':failures.length?'failed':'analyzed',events:events.length,individualCounterUpdates,coherentLinks,unobservedCounterChanges:breaks,overlappingIntervals:overlaps,
 originalNoteChangesDuringEvent:originalNoteChanges,bufferGaps:gaps,resets,alignedSnapshots:alignments,
 byType:[...byType.values()].map(t=>({...t,stats:[...t.stats].sort((a,b)=>a-b),unique:[...t.unique].sort((a,b)=>a-b)})),
 failures,nativeEvents:events.filter(e=>!e.contextUpdate).length,contextUpdates:events.filter(e=>e.contextUpdate).length,
 boundaryKinds:'native-dispatch-calls-and-context-updates',physicalActionValidated:false,historicalActionAttributionValidated:false};
fs.writeFileSync(path.join(__dirname,'native-event-analysis.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({events:report.events,coherentLinks,unobservedChanges:breaks.length,originalNoteChangesDuringEvent:originalNoteChanges,
 bufferGaps:gaps.length,alignedSnapshots:alignments.length,failures:failures.length,nativeEvents:report.nativeEvents,contextUpdates:report.contextUpdates,
 types:report.byType.map(t=>({type:t.type,count:t.count,stats:t.stats,unique:t.unique}))},null,2));
if(failures.length)process.exitCode=1;else if(!events.length)process.exitCode=2;
