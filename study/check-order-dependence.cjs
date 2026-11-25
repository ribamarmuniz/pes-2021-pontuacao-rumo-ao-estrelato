// Controlled numerical counterexample. These are synthetic input changes,
// not a claim about the causal value of an action in a recorded match.
const fs=require('fs'),path=require('path'),cp=require('child_process');
const {readStudy,defaultLog}=require('./read-study.cjs');
const {normalize}=require('./validate.cjs');
const {evaluate}=require('./compiled-program.cjs');
const {resolve,formulaByCategory}=require('./validate-raw.cjs');
const {writeCases,readResults}=require('./native-cases.cjs');
let selected;
for(const s of readStudy(process.argv[2]||defaultLog()).snapshots){
 const p=s.players.find(p=>p.v[2]===2147483834);if(!p||p.a!==1||!s._programs)continue;
 const k=[2,0,3,1][formulaByCategory[p.v[11]]];if(k===undefined)continue;
 const trials=[];
 for(const mask of [0,1,2,3]){
  const x=structuredClone(s),q=x.players.find(q=>q.v[2]===2147483834);
  if(mask&1)for(const id of [22,23,24,25,67])q.s[id]++;
  if(mask&2){for(const id of [6,17,67])q.s[id]++;q.u[1]++;}
  q.v[6]=evaluate(s._programs[k],name=>resolve(name,q,x));trials.push(x);
 }
 const n=trials.map(x=>normalize(x).find(p=>p.id===2147483834).predicted);
 if(n[1]-n[0]!==n[3]-n[2]){selected={source:{session:s.session,generation:s.generation},trials};break;}
}
if(!selected)throw Error('No order-dependence case found');
const input=path.join(__dirname,'order-native-input.bin'),output=path.join(__dirname,'order-native-output.bin');
writeCases(selected.trials,input);
const run=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'native-normalizer.ps1'),'-InputFile',input,'-OutputFile',output],{encoding:'utf8',timeout:120000,windowsHide:true});
if(run.status!==0)throw Error('Native counterexample failed '+run.status+' '+run.stderr);
const n=readResults(output).map((r,i)=>r[selected.trials[i].players.findIndex(p=>p.v[2]===2147483834)]);
const report={source:selected.source,synthetic:true,nativeNotes:{none:n[0],A:n[1],B:n[2],both:n[3]},
 inputA:{stats:[22,23,24,25,67],increments:1},inputB:{stats:[6,17,67],unique:[1],increments:1},
 orderAB:{A:n[1]-n[0],B:n[3]-n[1]},orderBA:{B:n[2]-n[0],A:n[3]-n[2]},
 total:n[3]-n[0],historicalActionAttribution:false};
if(report.orderAB.A===report.orderBA.A)throw Error('Native arithmetic did not confirm order dependence');
fs.writeFileSync(path.join(__dirname,'order-dependence.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
