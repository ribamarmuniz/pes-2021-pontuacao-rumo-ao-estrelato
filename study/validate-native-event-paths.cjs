const fs=require('fs'),path=require('path'),cp=require('child_process');
const {readStudy,defaultLog}=require('./read-study.cjs'),{readNativeEvents}=require('./read-native-events.cjs');
const {explainPath}=require('./explain.cjs'),{writeCases,readResults}=require('./native-cases.cjs');
const file=process.argv[2]||defaultLog(),session=process.argv[3];
const events=readNativeEvents(file,session).events,snapshots=readStudy(file).snapshots.filter(s=>!session||s.session===session);
const same=(a,b)=>a&&b&&a.length===b.length&&a.every((n,i)=>n===b[i]);
const paths=[],cases=[];
for(let i=1;i<snapshots.length;i++){
 const a=snapshots[i-1],b=snapshots[i];if(a.session!==b.session||a.match!==b.match)continue;
 const pa=a.players.find(p=>p.v[2]===2147483834),pb=b.players.find(p=>p.v[2]===2147483834);if(!pa||!pb||pa.v[7]<=0)continue;
 const eligible=events.filter(e=>e.session===a.session&&e.match===a.match);
 const start=eligible.findLastIndex(e=>e.observedAt<=a.time&&same(e.after.s,pa.s)&&same(e.after.u,pa.u));
 const end=eligible.findLastIndex(e=>e.observedAt<=b.time&&same(e.after.s,pb.s)&&same(e.after.u,pb.u));
 if(start<0||end<start||eligible[start].epoch!==eligible[end].epoch)continue;
 const chain=eligible.slice(start+1,end+1);
 const groups=chain.map(e=>({previous:e.before,s:e.after.s,u:e.after.u,chainCoherent:true,label:e.contextUpdate?'Contexto':undefined}));
 const result=explainPath(a,b,groups);if(!result)continue;
 const at=cases.length;cases.push(...result.trials);delete result.trials;
 paths.push({session:a.session,generation:b.generation,fromGeneration:a.generation,start:at,count:cases.length-at,
  nativeEvents:chain.map(e=>({sequence:e.sequence,type:e.type})),...result});
}
if(!cases.length){console.log(JSON.stringify({status:'awaiting-aligned-native-event-paths',events:events.length,paths:0}));process.exit(2);}
const input=path.join(__dirname,'native-event-path-input.bin'),output=path.join(__dirname,'native-event-path-output.bin');
let failures=[];
try{
 writeCases(cases,input);
 const run=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'native-normalizer.ps1'),'-InputFile',input,'-OutputFile',output],{encoding:'utf8',timeout:120000,windowsHide:true});
 if(run.status!==0)throw Error('Validacao nativa falhou '+run.stderr+' '+run.stdout);
 const results=readResults(output);
 for(const p of paths){
  const notes=[];for(let i=p.start;i<p.start+p.count;i++)notes.push(results[i][cases[i].players.findIndex(p=>p.v[2]===2147483834)]);
  if(notes.some((n,i)=>n!==p.stateNotes[i])||Math.fround(notes.at(-1)-notes[0])!==p.playerEffect
   ||Math.fround(p.playerEffect+p.remainingEffect)!==p.total)failures.push({generation:p.generation,notes,expected:p.stateNotes});
 }
 const report={status:failures.length?'failed':'compared',paths:paths.length,states:cases.length,failures,
  boundary:'native-dispatch-call',physicalActionValidated:false,historicalActionAttributionValidated:false,results:paths};
 fs.writeFileSync(path.join(__dirname,'native-event-path-validation.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({status:report.status,paths:paths.length,states:cases.length,failures:failures.length,
  changes:paths.filter(p=>p.total!==0).map(p=>({generation:p.generation,total:p.total,components:p.components,remainingEffect:p.remainingEffect}))},null,2));
 if(failures.length)process.exitCode=1;
}finally{for(const name of [input,output])if(fs.existsSync(name))fs.unlinkSync(name);}
