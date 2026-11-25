const fs=require('fs'),path=require('path'),cp=require('child_process');
const {readStudy,defaultLog}=require('./read-study.cjs');
const {evaluate}=require('./compiled-program.cjs');
const {resolve}=require('./validate-raw.cjs');
const {writeCases,readResults}=require('./native-cases.cjs');
const {label}=require('./explain.cjs');
const source=readStudy(defaultLog()).snapshots.at(-1),hex=source._programs[0];
const constants=Array(166).fill(0);for(let i=2;i<=16;i++)constants[i]=source.constants[i];for(let i=152;i<=163;i++)constants[i]=source.constants[i];
function player(team,slot,id,stats){const s=Array(135).fill(0);for(const [k,v] of Object.entries(stats))s[k]=v;return {a:1,v:[team,slot,id,0,30,12,0,0,0,100,0,9],s,u:[0,0,0,0],t:[0,0]};}
const before={match:'synthetic-path-test',duration:10,score:[0,0],constants,players:[
 player(0,0,2147483834,{22:3,23:3,24:3,25:3,67:5,65:1,66:1}),
 player(0,1,2,{22:5,23:4,24:5,25:4,67:8,89:1,94:1}),
 player(1,0,3,{22:7,23:7,24:7,25:7,67:10}),
 player(1,1,4,{22:1,23:1,24:1,25:1,67:2})]};
for(const p of before.players)p.v[6]=evaluate(hex,n=>resolve(n,p,{...before,schema:5}));
const after=structuredClone(before);after.score=[1,0];for(const p of after.players)p.t=[1,0];
let s=[...before.players[0].s],u=[0,0,0,0];const groups=[];
for(const changes of [{s:{22:1,23:1,24:1,25:1,67:1}},{s:{6:1,17:1,67:1},u:{1:1}},
 {s:{0:1,6:1,12:1,17:1},u:{1:1}},{s:{65:1,89:1,90:1,67:1}}]){
 const nextS=[...s],nextU=[...u];for(const [k,v] of Object.entries(changes.s))nextS[k]+=v;for(const [k,v] of Object.entries(changes.u||{}))nextU[k]+=v;
 groups.push({before_s:s,before_u:u,after_s:nextS,after_u:nextU});s=nextS;u=nextU;
}
after.players[0].s=s;after.players[0].u=u;
for(const p of after.players)p.v[6]=evaluate(hex,n=>resolve(n,p,{...after,schema:5}));
const trials=[];
for(const [s,u] of [[before.players[0].s,before.players[0].u],...groups.map(g=>[g.after_s,g.after_u])]){
 const trial=structuredClone(after),p=trial.players[0];p.s=s;p.u=u;p.v[6]=evaluate(hex,n=>resolve(n,p,{...trial,schema:5}));trials.push(trial);
}
const input=path.join(__dirname,'selftest-native-input.bin'),output=path.join(__dirname,'selftest-native-output.bin');
writeCases([before,after,...trials],input);
const run=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'native-normalizer.ps1'),'-InputFile',input,'-OutputFile',output],{encoding:'utf8',timeout:120000,windowsHide:true});
if(run.status!==0)throw Error('Native fixture failed '+run.status+' '+run.stderr);
const results=readResults(output);for(let i=0;i<4;i++){before.players[i].v[7]=before.players[i].v[8]=results[0][i];after.players[i].v[7]=after.players[i].v[8]=results[1][i];}
const notes=results.slice(2).map(x=>x[0]),components=[];let sum=0;
groups.forEach((g,i)=>{const effect=Math.fround(notes[i+1]-notes[i]);sum=Math.fround(sum+effect);if(effect)components.push({label:label({s:g.before_s,u:g.before_u},{s:g.after_s,u:g.after_u}),effect});});
const total=results[1][0]-results[0][0];
const expected={from:results[0][0],to:results[1][0],total,playerEffect:sum,remainingEffect:Math.fround(total-sum),stateNotes:notes,components};
const buffer=Buffer.from(hex,'hex'),program={count:buffer.length/12};for(let i=0;i<program.count;i++)program[i]={t:buffer.readUInt32LE(i*12),a:buffer.readUInt32LE(i*12+4),b:buffer.readUInt32LE(i*12+8),value:buffer.readUInt32LE(i*12)===4?buffer.readFloatLE(i*12+4):0};
function lua(value){if(Array.isArray(value))return '{'+value.map(lua).join(',')+'}';if(value&&typeof value==='object')return '{'+Object.entries(value).map(([k,v])=>'['+(/^\d+$/.test(k)?k:JSON.stringify(k))+']='+lua(v)).join(',')+'}';return JSON.stringify(value);}
const code='-- Synthetic fixture. Expected values produced by the original PES machine code in a separate process.\nlocal function run_rating_selftest(model)\n'
 +'local before='+lua(before)+'\nlocal after='+lua(after)+'\nlocal groups='+lua(groups)+'\nlocal expected='+lua(expected)+'\n'
 +'local program='+lua(program)+'\nlocal result=model.path({program},before,after,groups,2147483834)\n'
 +'if not result or not model.same(result.stateNotes,expected.stateNotes) then return false end\n'
 +'for _,key in ipairs({"from","to","total","playerEffect","remainingEffect"}) do if result[key]~=expected[key] then return false end end\n'
 +'if #result.components~=#expected.components then return false end\n'
 +'for i,p in ipairs(result.components) do if p.label~=expected.components[i].label or p.effect~=expected.components[i].effect then return false end end\nreturn true,{before=before,after=after,groups=groups,expected=expected,programs={program}}\nend\n';
fs.writeFileSync(path.join(__dirname,'path-selftest.lua'),code);fs.writeFileSync(path.join(__dirname,'path-selftest-native.json'),JSON.stringify(expected,null,2)+'\n');console.log(JSON.stringify(expected));
