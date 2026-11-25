const fs=require('fs'),path=require('path'),cp=require('child_process');
const {readStudy,defaultLog}=require('./read-study.cjs');
const {readObservations}=require('./read-observations.cjs');
const {marginal}=require('./explain.cjs');
const {writeCases,readResults}=require('./native-cases.cjs');
const file=process.argv[2]||defaultLog(),observations=readObservations(file),cases=[],events=[];
const equal=(a,b)=>a&&a.length===b.length&&b.every((n,i)=>a[i]===n);
for(const snapshot of readStudy(file).snapshots){
 const p=snapshot.players.find(p=>p.v[2]===2147483834);if(!p||!snapshot.match)continue;
 const o=observations.findLast(o=>o.session===snapshot.session&&o.match===snapshot.match&&o.time<=snapshot.time);
 if(!o||!o.previous||!o.chainCoherent||!o.u||!o.previous.u||o.previous.player[3]<=0||o.player[3]===o.previous.player[3]
  ||o.player[3]!==p.v[7]||!equal(o.s,p.s)||!equal(o.u,p.u)||o.time-o.previous.time>2)continue;
 const e=marginal(snapshot,o.previous.s,o.previous.u);if(!e)continue;
 const total=o.player[3]-o.previous.player[3];
 events.push({session:o.session,generation:snapshot.generation,label:e.label,from:o.previous.player[3],to:o.player[3],
  total,playerEffect:e.playerEffect,contextEffect:Math.fround(total-e.playerEffect),samplingInterval:o.time-o.previous.time,
  definition:'previous-observed-player-counters-at-current-context',historicalActionAttribution:false});
 cases.push(e.trial);
}
if(!cases.length){console.log(JSON.stringify({status:'awaiting-aligned-event-intervals'}));process.exit(2);}
const input=path.join(__dirname,'event-native-input.bin'),output=path.join(__dirname,'event-native-output.bin');
writeCases(cases,input);
const run=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'native-normalizer.ps1'),'-InputFile',input,'-OutputFile',output],{encoding:'utf8',timeout:120000,windowsHide:true});
if(run.status!==0)throw Error('Native event study failed '+run.status+' '+run.stderr);
const results=readResults(output),failures=[];
events.forEach((e,i)=>{const j=cases[i].players.findIndex(p=>p.v[2]===2147483834);e.nativeEffect=e.to-results[i][j];if(e.nativeEffect!==e.playerEffect)failures.push(e);});
const report={events,failures,historicalActionAttribution:false};
fs.writeFileSync(path.join(__dirname,'event-effect-validation.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
if(failures.length)process.exitCode=1;
