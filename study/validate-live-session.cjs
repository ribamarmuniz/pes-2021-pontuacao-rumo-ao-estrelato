// Check one immutable local copy so every validator sees the same evidence.
// Neither game memory nor the game controls are accessed here.
const fs=require('fs'),path=require('path'),cp=require('child_process'),crypto=require('crypto');
const {defaultLog}=require('./read-study.cjs');
const source=path.resolve(process.argv[2]||defaultLog()),session=process.argv[3];
if(!session)throw Error('Informe a sessao como terceiro argumento');
const bytes=fs.readFileSync(source);
const temporary=path.join(__dirname,'live-validation-input-'+process.pid+'.log');
const report={session,source,sourceBytes:bytes.length,sourceSha256:crypto.createHash('sha256').update(bytes).digest('hex'),
 checkedAt:new Date().toISOString(),historicalActionAttributionValidated:false,validators:{}};
const eventSession=bytes.toString('utf8').split(/\r?\n/).filter(l=>l.includes('BAL_NATIVE_EVENT_SESSION '))
 .map(l=>JSON.parse(l.split('BAL_NATIVE_EVENT_SESSION ')[1])).findLast(e=>e.session===session);
const names=['check-captures','validate-lua','check-live-explanations'];
if(eventSession?.version>=2)names.push('analyze-native-events','validate-native-event-paths');
const contextSession=bytes.toString('utf8').split(/\r?\n/).filter(l=>l.includes('BAL_CONTEXT_SESSION '))
 .map(l=>JSON.parse(l.split('BAL_CONTEXT_SESSION ')[1])).findLast(e=>e.session===session);
const contextTemporary=path.join(__dirname,'live-validation-context-'+process.pid+'.balc');
if(contextSession?.version>=3){
 const contextBytes=fs.readFileSync(path.join(__dirname,'..','bal-context-captures.balc'));
 fs.writeFileSync(contextTemporary,contextBytes,{flag:'wx'});
 report.contextArchiveBytes=contextBytes.length;report.contextArchiveSha256=crypto.createHash('sha256').update(contextBytes).digest('hex');
 names.push('validate-observed-context');
}
report.contextCaptureVersion=contextSession?.version||0;
report.nativeCaptureVersion=eventSession?.version||0;
let status=0;
fs.writeFileSync(temporary,bytes,{flag:'wx'});
try{
 for(const name of names){
  const run=cp.spawnSync(process.execPath,[path.join(__dirname,name+'.cjs'),temporary,session,contextTemporary],
   {encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:8*1024*1024});
  if(run.error||run.signal||run.status===null)throw run.error||Error('Validador interrompido '+name);
  const result=JSON.parse(run.stdout);
  report.validators[name]={exitCode:run.status,...result};
  if(run.status===1)status=1;
  else if(run.status!==0&&status===0)status=2;
 }
 report.status=status===0?'compared':status===1?'failed':'awaiting-evidence';
 const explanations=report.validators['check-live-explanations'].checks;
 report.explanationCount=explanations.length;
 report.explanationsWithIndividualComponents=explanations.filter(e=>e.components.length>0).length;
 report.nativeExplanations=explanations.filter(e=>e.groupSource==='native-event-boundaries').length;
 report.nativeExplanationsWithIndividualComponents=explanations.filter(e=>e.groupSource==='native-event-boundaries'&&e.components.length>0).length;
 report.observedContextExplanations=explanations.filter(e=>e.groupSource==='native-observed-context').length;
 fs.writeFileSync(path.join(__dirname,'live-validation.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({status:report.status,session,explanations:report.explanationCount,
  explanationsWithIndividualComponents:report.explanationsWithIndividualComponents,
  nativeExplanations:report.nativeExplanations,nativeExplanationsWithIndividualComponents:report.nativeExplanationsWithIndividualComponents,
  observedContextExplanations:report.observedContextExplanations,
  captures:report.validators['check-captures'].captures,notes:report.validators['check-captures'].notes,
  historicalActionAttributionValidated:false},null,2));
 process.exitCode=status;
}finally{fs.unlinkSync(temporary);if(fs.existsSync(contextTemporary))fs.unlinkSync(contextTemporary);}
