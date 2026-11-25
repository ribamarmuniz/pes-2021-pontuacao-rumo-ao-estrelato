// Offline analysis only. Never connected to the displayed original rating.
const fs=require('fs');
const path=require('path');
const {normalize,readSnapshots}=require('./validate.cjs');
const {resolve,formulaByCategory}=require('./validate-raw.cjs');
const {evaluate}=require('./compiled-program.cjs');
const {defaultLog}=require('./read-study.cjs');
const log=process.argv[2]||defaultLog();
const inputs=[['Gol',0],['Assistencia',4],['Chute no alvo',17],['Passe rasteiro certo',25],
 ['Passe em profundidade certo',27],['Passe longo certo',29],['Cruzamento certo',31],
 ['Cartao amarelo',57],['Cartao vermelho',58],['Perda durante passe',94]];
for(const snapshot of readSnapshots(log)){
 if(snapshot.schema<5||snapshot.calculation_copy!==1)continue;
 const programs=snapshot._programs;
 if(!programs){console.log(JSON.stringify({time:snapshot.time,status:'missing-programs'}));continue;}
 const player=snapshot.players.find(p=>p.v[2]===2147483834);
 if(!player||player.v[7]<=0)continue;
 const index=[2,0,3,1][formulaByCategory[player.v[11]]];
 if(index===undefined)continue;
 const raw=evaluate(programs[index],name=>resolve(name,player,snapshot));
 const baseline=normalize(snapshot);
 const bad=baseline.filter(p=>Math.abs(p.difference)>=0.01);
 if(bad.length||raw!==Math.fround(player.v[6])){
  console.log(JSON.stringify({time:snapshot.time,status:'rejected',noteMismatches:bad.length,rawDifference:raw-player.v[6]}));continue;
 }
 const factors=[];
 for(const [label,id] of inputs){
  if(player.s[id]<=0)continue;
  const trial=structuredClone(snapshot);
  const changed=trial.players.find(p=>p.v[2]===2147483834);
  changed.s[id]--;
  changed.v[6]=evaluate(programs[index],name=>resolve(name,changed,trial));
  const result=normalize(trial).find(p=>p.id===2147483834);
  factors.push({label,removedCount:1,rawEffect:raw-changed.v[6],
   isolatedRatingEffect:player.v[7]-result.predicted});
 }
 console.log(JSON.stringify({time:snapshot.time,generation:snapshot.generation,
  status:'isolated-input-study',rating:player.v[7],scoreHeldFixed:snapshot.score,
  historicalActionAttribution:false,factors}));
}
