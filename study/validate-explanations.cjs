const fs=require('fs'),path=require('path'),cp=require('child_process');
const {readStudy,defaultLog}=require('./read-study.cjs');
const {writeCases,readResults}=require('./native-cases.cjs');
const {explain}=require('./explain.cjs');
const snapshots=readStudy(process.argv[2]||defaultLog()).snapshots;
const trials=[],explanations=[],failures=[];
for(let i=1;i<snapshots.length;i++){
 const before=snapshots[i-1],after=snapshots[i],e=explain(before,after);
 if(!e)continue;
 explanations.push({session:after.session,match:after.match,generation:after.generation,...e});trials.push(e.trial);
}
if(!trials.length)throw Error('No explanation trials');
const input=path.join(__dirname,'explanation-native-input.bin'),output=path.join(__dirname,'explanation-native-output.bin');
writeCases(trials,input);
const run=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'native-normalizer.ps1'),'-InputFile',input,'-OutputFile',output],{encoding:'utf8',timeout:120000,windowsHide:true});
if(run.status!==0)throw Error('Native replay failed '+run.status+' '+run.stderr);
const results=readResults(output);
for(let i=0;i<explanations.length;i++){
 const e=explanations[i],j=e.trial.players.findIndex(p=>p.v[2]===2147483834);
 const nativeEffect=Math.fround(e.to-results[i][j]);
 if(nativeEffect!==e.playerEffect)failures.push({generation:e.generation,nativeEffect,translated:e.playerEffect});
 delete e.trial;e.nativeEffect=nativeEffect;
}
const report={comparisons:explanations.length,failures,explanations,historicalActionAttribution:false};
fs.writeFileSync(path.join(__dirname,'explanation-validation.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({comparisons:explanations.length,failures,changes:explanations.filter(e=>e.total!==0)},null,2));
if(failures.length)process.exitCode=1;
