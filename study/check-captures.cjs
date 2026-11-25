// Compares native copied inputs with the compiled expression interpreter.
// Agreement reproduces the recorded calculation, without assigning action causes.
const {readStudy,defaultLog}=require('./read-study.cjs');
const {normalize}=require('./validate.cjs');
const {resolve,formulaByCategory}=require('./validate-raw.cjs');
const {evaluate}=require('./compiled-program.cjs');
const file=process.argv[2]||defaultLog();
const session=process.argv[3];
const all=readStudy(file).snapshots;
const report={captures:0,notes:0,raw:0,heldRaw:0,unknownCategories:0,failures:[],historicalActionAttribution:false};
for(const s of all){
 if(session&&s.session!==session)continue;
 if(s.schema<5||s.calculation_copy!==1)continue;
 report.captures++;
 if(!s._programs||!s.players.length){report.failures.push({time:s.time,type:'missing-input'});continue;}
 for(const p of normalize(s)){
  report.notes++;
  if(p.difference!==0)report.failures.push({session:s.session,generation:s.generation,type:'note',...p});
 }
 for(const p of s.players){
  if(p.a===0){report.heldRaw++;continue;}
  const i=[2,0,3,1][formulaByCategory[p.v[11]]];
  if(i===undefined){report.unknownCategories++;continue;}
  report.raw++;
  const compiled=evaluate(s._programs[i],name=>resolve(name,p,s));
  const observed=Math.fround(p.v[6]);
  if(compiled!==observed)report.failures.push({session:s.session,generation:s.generation,
   type:'raw',id:p.v[2],compiled,observed});
 }
}
report.status=report.captures?'compared':'awaiting-captures';
console.log(JSON.stringify(report,null,2));
if(report.failures.length)process.exitCode=1;
else if(!report.captures||report.unknownCategories)process.exitCode=2;
