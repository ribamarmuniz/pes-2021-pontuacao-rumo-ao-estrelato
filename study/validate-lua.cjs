const fs=require('fs');
const {defaultLog,readStudy}=require('./read-study.cjs');
const {normalize}=require('./validate.cjs');
const {evaluate}=require('./compiled-program.cjs');
const {resolve,formulaByCategory}=require('./validate-raw.cjs');
const file=process.argv[2]||defaultLog();
const session=process.argv[3];
const snapshots=readStudy(file).snapshots;
const byKey=new Map(snapshots.map(s=>[s.session+':'+s.generation,s]));
const checks=[];
const source=fs.readFileSync(file,'utf8');
const lines=source.split(/\r?\n/);
for(let i=0;i<lines.length;i++){
 const marker='BAL_LUA_MODEL_CHECK ';
 if(!lines[i].includes(marker))continue;
 let check;
 try{check=JSON.parse(lines[i].split(marker)[1]);}
 catch(error){if(i===lines.length-1&&!source.endsWith('\n'))break;throw error;}
 if(session&&check.session!==session)continue;
 const s=byKey.get(check.session+':'+check.generation);
 if(!s)throw Error('Captura correspondente ausente');
 const predicted=normalize(s),failures=[];
 let heldRaw=0;
 if(check.players.length!==s.players.length||new Set(check.players.map(p=>p[0])).size!==check.players.length)
  failures.push({type:'incomplete-player-set'});
 for(const row of check.players){
  const [id,note,raw,engine,observed,active]=row;
  const p=s.players.find(p=>p.v[2]===id);
  const n=predicted.find(p=>p.id===id);
  const index=[2,0,3,1][formulaByCategory[p?.v[11]]];
  const expected=index===undefined?null:evaluate(s._programs[index],name=>resolve(name,p,s));
  if(active===0)heldRaw++;
  if(!n||note!==n.predicted||note!==engine||engine!==p.v[7]||active!==p.a
    ||Math.fround(observed)!==Math.fround(p.v[6])||(active!==0&&Math.fround(raw)!==Math.fround(observed))
    ||expected!==Math.fround(raw))failures.push({id,note,engine,raw,expected,observed});
 }
 checks.push({session:check.session,generation:check.generation,total:check.players.length,heldRaw,failures});
}
console.log(JSON.stringify({status:checks.length?'compared':'awaiting-runtime-captures',checks:checks.length,players:checks.reduce((a,c)=>a+c.total,0),
 heldRaw:checks.reduce((a,c)=>a+c.heldRaw,0),
 failures:checks.filter(c=>c.failures.length),historicalActionAttribution:false},null,2));
if(checks.some(c=>c.failures.length))process.exitCode=1;
else if(!checks.length)process.exitCode=2;
