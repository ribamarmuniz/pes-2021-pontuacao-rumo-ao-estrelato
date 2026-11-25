const fs=require('fs'),path=require('path'),{readStudy,defaultLog}=require('./read-study.cjs'),{instantModel}=require('./instant-model.cjs');
const report={captures:0,notes:0,activeRaw:0,heldRaw:0,skippedUnsupported:0,failures:[],virtualModel:true,historicalActionAttributionValidated:false};
for(const source of readStudy(process.argv[2]||defaultLog()).snapshots){
 if(source.schema<5||!source.calculation_copy||!source._programs||source.players.some(p=>![0,1].includes(p.a)||!p.t)){
  report.skippedUnsupported++;continue;
 }
 const result=instantModel(structuredClone(source),source._programs);if(!result){report.failures.push({generation:source.generation,reason:'missing-result'});continue;}
 report.captures++;
 for(let i=0;i<source.players.length;i++){
  const p=source.players[i],q=result.input.players[i];
  report.notes++;if(result.notes[i].predicted!==Math.fround(p.v[7]))report.failures.push({session:source.session,generation:source.generation,id:p.v[2],type:'note'});
  if(p.a===1)report.activeRaw++;else report.heldRaw++;
  if(q.v[6]!==Math.fround(p.v[6]))report.failures.push({session:source.session,generation:source.generation,id:p.v[2],type:p.a===1?'active-raw':'held-raw'});
 }
}
report.status=report.failures.length?'failed':report.captures?'compared':'awaiting-captures';
fs.writeFileSync(path.join(__dirname,'instant-model-validation.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({...report,failures:report.failures.slice(0,5),failureCount:report.failures.length},null,2));if(report.failures.length)process.exitCode=1;else if(!report.captures)process.exitCode=2;
