const fs=require('fs'),path=require('path'),cp=require('child_process');
const {readStudy,defaultLog}=require('./read-study.cjs');
const {readObservations}=require('./read-observations.cjs');
const {explainPath}=require('./explain.cjs');
const {writeCases,readResults}=require('./native-cases.cjs');
const file=process.argv[2]||defaultLog(),observations=readObservations(file),snapshots=readStudy(file).snapshots;
const same=(a,b)=>a&&b&&a.length===b.length&&a.every((n,i)=>n===b[i]);
const cases=[],paths=[];
for(let i=1;i<snapshots.length;i++){
 const a=snapshots[i-1],b=snapshots[i];if(!a.match||a.match!==b.match||a.session!==b.session)continue;
 const pa=a.players.find(p=>p.v[2]===2147483834),pb=b.players.find(p=>p.v[2]===2147483834);if(!pa||!pb)continue;
 const relevant=observations.filter(o=>o.session===b.session&&o.match===b.match);
 const begin=relevant.findLastIndex(o=>o.time<=a.time&&same(o.s,pa.s)&&same(o.u,pa.u));
 const end=relevant.findLastIndex(o=>o.time<=b.time&&same(o.s,pb.s)&&same(o.u,pb.u));
 if(begin<0||end<begin)continue;
 const e=explainPath(a,b,relevant.slice(begin+1,end+1));if(!e)continue;
 const start=cases.length;cases.push(...e.trials);delete e.trials;
 paths.push({session:b.session,generation:b.generation,start,count:cases.length-start,...e});
}
if(!cases.length){console.log('No aligned paths');process.exit(2);}
const input=path.join(__dirname,'path-native-input.bin'),output=path.join(__dirname,'path-native-output.bin');
writeCases(cases,input);
const run=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'native-normalizer.ps1'),'-InputFile',input,'-OutputFile',output],{encoding:'utf8',timeout:120000,windowsHide:true});
if(run.status!==0)throw Error('Native path validation failed '+run.status+' '+run.stderr);
const results=readResults(output),failures=[];
for(const p of paths){
 const notes=[];
 for(let i=p.start;i<p.start+p.count;i++)notes.push(results[i][cases[i].players.findIndex(p=>p.v[2]===2147483834)]);
 const nativeSum=Math.fround(notes.at(-1)-notes[0]);
 if(nativeSum!==p.playerEffect||Math.fround(p.playerEffect+p.remainingEffect)!==p.total
   ||notes.some((n,i)=>n!==p.stateNotes[i]))failures.push(p);
}
const report={paths:paths.length,states:cases.length,failures,changes:paths.filter(p=>p.total!==0),historicalActionAttribution:false};
fs.writeFileSync(path.join(__dirname,'path-effect-validation.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
if(failures.length)process.exitCode=1;
