// Offline research only. Does not read or write the running game.
const fs=require('fs'),path=require('path');
const {readStudy,defaultLog}=require('./read-study.cjs');
const {readContextArchive}=require('./read-context-archive.cjs');
const {decodeContextPacket}=require('./read-context-state.cjs');
const {instantModel}=require('./instant-model.cjs');
const {normalize}=require('./validate.cjs');
const {eventLabel}=require('./observed-context-model.cjs');
async function run(){
 const log=process.argv[2]||defaultLog(),snapshots=readStudy(log).snapshots;
 const session=process.argv[3]||snapshots.at(-1)?.session;
 if(!session)throw Error('No session available');
 const archive=process.argv[4]||path.join(__dirname,'..','bal-context-captures.balc');
 const id=2147483834, rows=[],failures=[];
 let selected=0,invalid=0,zeroRawNoteChanged=0,rawChangedNoteStable=0,rawChanged=0;
 for await(const packet of readContextArchive(archive)){
  if(packet.meta.session!==session)continue;
  selected++;
  const g=decodeContextPacket(packet),source=snapshots.find(s=>s.session===session&&s.match===packet.meta.match&&s._programs);
  if(!g.valid||!source){invalid++;continue;}
  const a=instantModel(g.before,source._programs,id),b=instantModel(g.after,source._programs,id);
  if(!a||!b||a.note!==packet.meta.beforeNote||b.note!==packet.meta.afterNote){failures.push({sequence:g.sequence,reason:'model-mismatch'});continue;}
  const x=normalize(a.input,{trace:true}).find(p=>p.id===id),y=normalize(b.input,{trace:true}).find(p=>p.id===id);
  if(x.predicted!==a.note||y.predicted!==b.note)throw Error('Trace changed result');
  const rawDelta=Math.fround(y.trace.rawPoints-x.trace.rawPoints),noteDelta=Math.fround(b.note-a.note);
  if(rawDelta){rawChanged++;if(!noteDelta)rawChangedNoteStable++;}
  else if(noteDelta)zeroRawNoteChanged++;
  rows.push([session,packet.meta.match,packet.meta.epoch,g.sequence,g.type,eventLabel(g.before,g.after,id),
   x.trace.minutes,y.trace.minutes,x.trace.rawPoints,y.trace.rawPoints,rawDelta,
   x.trace.continuousBase,y.trace.continuousBase,y.trace.continuousBase-x.trace.continuousBase,
   x.trace.quantizedBase,y.trace.quantizedBase,a.note,b.note,noteDelta]);
 }
 const prefix=path.join(__dirname,'raw-event-audit-'+String(session).replace(/[^a-zA-Z0-9_-]/g,'_'));
 const header=['session','match','epoch','sequence','type','candidateLabel','minutesBefore','minutesAfter','rawBefore','rawAfter','rawDelta','modelContinuousBaseBefore','modelContinuousBaseAfter','modelContinuousBaseDelta','quantizedBaseBefore','quantizedBaseAfter','virtualNoteBefore','virtualNoteAfter','virtualNoteDelta'];
 const csv=v=>'"'+String(v??'').replace(/"/g,'""')+'"';
 fs.writeFileSync(prefix+'.csv',[header,...rows].map(r=>r.map(csv).join(',')).join('\n')+'\n');
 const report={session,selected,processed:rows.length,invalid,rawChanged,rawChangedNoteStable,zeroRawNoteChanged,failures,
  examples:rows.filter(r=>r[10]!==0||r[18]!==0).slice(0,12).map(r=>Object.fromEntries(header.map((h,i)=>[h,r[i]]))),
  continuousBaseSource:'derived-model-before-base-quantization-not-direct-engine-read',
  rawSource:'compiled-formula-at-observed-event-context',virtualNotes:true,
  historicalActionAttributionValidated:false,physicalActionValidated:false};
 fs.writeFileSync(prefix+'.json',JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report,null,2));if(failures.length||!rows.length)process.exitCode=1;
}
run().catch(e=>{console.error(e);process.exitCode=1;});
