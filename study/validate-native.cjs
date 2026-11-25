const fs=require('fs'),path=require('path'),cp=require('child_process');
const {readStudy,defaultLog}=require('./read-study.cjs');
const {normalize}=require('./validate.cjs');
const {writeCases,readResults}=require('./native-cases.cjs');
const snapshots=readStudy(process.argv[2]||defaultLog()).snapshots.filter(s=>s.schema>=5&&s.calculation_copy===1);
const cases=[],labels=[];
function add(s,label,mutate){const x=structuredClone(s);if(mutate)mutate(x,x.players.find(p=>p.v[2]===2147483834)||x.players[0]);cases.push(x);labels.push({session:s.session,generation:s.generation,label});}
for(let index=0;index<snapshots.length;index++){
 const s=snapshots[index];add(s,'recorded');
 if(index%8!==0)continue;
 for(const goals of [0,1,2,3,5,6,9])add(s,'goals-'+goals,(x,p)=>{p.s[0]=goals;});
 for(const assists of [0,1,2,3,5])add(s,'assists-'+assists,(x,p)=>{p.s[4]=assists;});
 for(const dur of [0,1,4,5,6,44,45,46,90])add(s,'participation-'+dur,(x,p)=>{p.v[3]=0;p.v[4]=dur;});
 for(const raw of [-1000,-1,0,1,25,100,10000])add(s,'points-'+raw,(x,p)=>{p.v[6]=raw;});
 for(const role of [0,4,5,7,8,12,13])for(const losses of [0,2,3,4,9])add(s,'losses-'+role+'-'+losses,(x,p)=>{
  p.v[5]=role;p.s[0]=p.s[4]=0;p.s[24]=p.s[65]=10;p.s[95]=losses;p.s[90]=losses;p.s[91]=p.s[92]=p.s[93]=0;
 });
 for(const duration of [5,10,15,20,30])add(s,'duration-'+duration,(x,p)=>{x.duration=duration;p.s[0]=3;p.s[4]=2;});
 for(const ratio of [0,.1,.2,.3,.4,.5,.6,.7,.8,.9,1,1.2])add(s,'extra-'+ratio,(x,p)=>{p.v[9]=10000;p.v[10]=ratio*10000;});
 for(const faced of [3,4,5,10])for(const saved of [1,2,3,4,5])for(const score of [[0,0],[1,0],[0,4]])
  add(s,'keeper-'+faced+'-'+saved+'-'+score.join('-'),(x,p)=>{p.s[132]=faced;p.s[133]=saved;x.score=score;});
 add(s,'slot-zero-absent',x=>{x.players=x.players.filter(p=>p.v[0]!==0||p.v[1]!==0);});
 add(s,'equal-points',x=>{for(const p of x.players){p.v[6]=0;p.s[0]=p.s[4]=0;}});
}
if(!cases.length)throw Error('No native cases');
const input=path.join(__dirname,'native-input.bin'),output=path.join(__dirname,'native-output.bin');
writeCases(cases,input);
const run=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'native-normalizer.ps1'),'-InputFile',input,'-OutputFile',output],{encoding:'utf8',timeout:120000,windowsHide:true});
if(run.status!==0)throw Error('Native study process failed '+run.status+' '+run.stderr+' '+run.stdout);
const results=readResults(output),failures=[];let players=0;
for(let i=0;i<cases.length;i++){
 const predicted=normalize(cases[i]);
 if(results[i].length!==predicted.length)throw Error('Player count differs');
 for(let j=0;j<predicted.length;j++){
  players++;
  if(results[i][j]!==Math.fround(predicted[j].predicted))failures.push({...labels[i],id:predicted[j].id,native:results[i][j],translated:predicted[j].predicted});
 }
}
const report={cases:cases.length,players,recorded:snapshots.length,failures,
 nativeArithmetic:'unmodified PES normalizer in separate study process',
 adapters:['configuration pointer','world pointer','score getter','container lifetime','memset','study cookie check'],
 historicalActionAttribution:false};
fs.writeFileSync(path.join(__dirname,'native-validation.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({...report,failures:failures.slice(0,30)},null,2));
if(failures.length)process.exitCode=1;
