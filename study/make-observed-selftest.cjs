const fs=require('fs'),path=require('path'),cp=require('child_process');
const {readStudy,defaultLog}=require('./read-study.cjs'),{instantModel}=require('./instant-model.cjs');
const {observedTimeline}=require('./observed-context-model.cjs'),{writeCases,readResults}=require('./native-cases.cjs');
const source=readStudy(defaultLog()).snapshots.findLast(s=>s._programs&&s.constants),hex=source._programs[0];
const constants=Array(166).fill(0);for(let i=2;i<=16;i++)constants[i]=source.constants[i];for(let i=152;i<=163;i++)constants[i]=source.constants[i];
function player(team,slot,id,values){const s=Array(135).fill(0);for(const [k,v]of Object.entries(values))s[k]=v;return {a:1,v:[team,slot,id,0,30,12,0,0,0,100,0,9],s,u:[0,0,0,0],t:[0,0]};}
const before={schema:6,match:'synthetic-observed-context',duration:10,score:[0,0],constants,players:[
 player(0,0,2147483834,{22:3,23:3,24:3,25:3,67:5,65:1,66:1}),player(0,1,2,{22:5,23:4,24:5,25:4,67:8,89:1,94:1}),
 player(1,0,3,{22:7,23:7,24:7,25:7,67:10}),player(1,1,4,{22:1,23:1,24:1,25:1,67:2})]};
instantModel(before,[hex]);
const after=structuredClone(before);after.score=[1,0];for(const p of after.players)p.t=[1,0];
let s=[...before.players[0].s],u=[0,0,0,0];const groups=[];
for(const changes of [{s:{22:1,23:1,24:1,25:1,67:1}},{s:{6:1,17:1,67:1},u:{1:1}},{s:{0:1,6:1,12:1,17:1},u:{1:1}},{s:{65:1,89:1,90:1,67:1}}]){
 const a=structuredClone(after);a.players[0].s=[...s];a.players[0].u=[...u];
 for(const [k,v]of Object.entries(changes.s))s[k]+=v;for(const [k,v]of Object.entries(changes.u||{}))u[k]+=v;
 const b=structuredClone(after);b.players[0].s=[...s];b.players[0].u=[...u];
 const aResult=instantModel(a,[hex]),bResult=instantModel(b,[hex]);
 if(!aResult||!bResult)throw Error('Estado sintetico sem resultado');
 groups.push({sequence:groups.length+1,valid:true,before:a,after:b,beforeNote:aResult.note,afterNote:bResult.note,contextUpdate:false});
}
after.players[0].s=s;after.players[0].u=u;instantModel(after,[hex]);
const cases=[before,after,...groups.flatMap(g=>[g.before,g.after])];
const input=path.join(__dirname,'observed-selftest-input.bin'),output=path.join(__dirname,'observed-selftest-output.bin');
try{
 writeCases(cases,input);
 const run=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'native-normalizer.ps1'),'-InputFile',input,'-OutputFile',output],{encoding:'utf8',windowsHide:true,timeout:120000});
 if(run.status!==0)throw Error('Fixture original falhou '+run.stderr);
 const result=readResults(output);for(let i=0;i<4;i++){before.players[i].v[7]=before.players[i].v[8]=result[0][i];after.players[i].v[7]=after.players[i].v[8]=result[1][i];}
 groups.forEach((g,i)=>{if(g.beforeNote!==result[2+i*2][0]||g.afterNote!==result[3+i*2][0])throw Error('Estado virtual diferente do original');});
 const expected=observedTimeline(before,after,groups);
 if(!expected||expected.from!==6||expected.to!==7||expected.eventEffect!==.5||expected.contextEffect!==.5)throw Error('Resultado cronologico inesperado');
 const data=Buffer.from(hex,'hex'),program={count:data.length/12};for(let i=0;i<program.count;i++)program[i]={t:data.readUInt32LE(i*12),a:data.readUInt32LE(i*12+4),b:data.readUInt32LE(i*12+8),value:data.readUInt32LE(i*12)===4?data.readFloatLE(i*12+4):0};
 function lua(v){if(Array.isArray(v))return '{'+v.map(lua).join(',')+'}';if(v&&typeof v==='object')return '{'+Object.entries(v).map(([k,x])=>'['+(/^\d+$/.test(k)?k:JSON.stringify(k))+']='+lua(x)).join(',')+'}';return JSON.stringify(v);}
 const code='-- Synthetic inputs and expected notes verified with the original native normalizer.\nlocal function run_observed_context_selftest(model)\n'
  +'local before='+lua(before)+'\nlocal after='+lua(after)+'\nlocal groups='+lua(groups)+'\nlocal expected='+lua(expected)+'\nlocal programs={'+lua(program)+'}\n'
  +'for _,g in ipairs(groups) do local a=model.instant(programs,g.before,2147483834);local b=model.instant(programs,g.after,2147483834);if not a or not b or a.note~=g.beforeNote or b.note~=g.afterNote then return false end end\n'
  +'local result=model.observed_timeline(before,after,groups,2147483834)\nif not result or not model.same(result.stateNotes,expected.stateNotes) then return false end\n'
  +'for _,k in ipairs({"from","to","total","eventEffect","contextEffect"}) do if result[k]~=expected[k] then return false end end\n'
  +'if #result.components~=#expected.components then return false end\nfor i,p in ipairs(result.components) do local e=expected.components[i];if p.label~=e.label or p.effect~=e.effect or p.source~=e.source or p.sequence~=e.sequence then return false end end\n'
  +'return true,result\nend\n';
 fs.writeFileSync(path.join(__dirname,'observed-context-selftest.lua'),code);
 const report={passed:true,synthetic:true,nativeStates:cases.length,nativePlayerComparisons:cases.reduce((n,s)=>n+s.players.length,0),expected};
 fs.writeFileSync(path.join(__dirname,'observed-context-selftest-native.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
}finally{for(const file of [input,output])if(fs.existsSync(file))fs.unlinkSync(file);}
