const fs=require('fs'),path=require('path'),cp=require('child_process');
const {readStudy,defaultLog}=require('./read-study.cjs'),{readContextArchive}=require('./read-context-archive.cjs');
const {decodeContextPacket}=require('./read-context-state.cjs'),{instantModel}=require('./instant-model.cjs');
const {observedTimeline}=require('./observed-context-model.cjs'),{writeCases,readResults}=require('./native-cases.cjs');
const {names}=require('./compiled-program.cjs'),{resolve,formulaByCategory}=require('./validate-raw.cjs');
const file=process.argv[2]||defaultLog(),session=process.argv[3],archive=process.argv[4]||path.join(__dirname,'..','bal-context-captures.balc');
function lines(marker){return fs.readFileSync(file,'utf8').split(/\r?\n/).filter(l=>l.includes(marker+' ')).flatMap(l=>{try{return [JSON.parse(l.split(marker+' ')[1])];}catch{return [];}}).filter(x=>!session||x.session===session);}
async function run(){
 const snapshots=readStudy(file).snapshots.filter(x=>!session||x.session===session);
 const explanations=lines('BAL_RATING_EXPLANATION').filter(x=>x.groupSource==='native-observed-context');
 const needed=new Set(explanations.flatMap(x=>(x.nativeEventSequences||[]).map(n=>x.session+':'+n)));
 const selected=new Map(),cases=[],expected=[],failures=[],sequences=new Map(),rawCases=new Map();let packets=0,archivePackets=0,nonzeroEvents=0,notes=0;
 if(!fs.existsSync(archive)){console.log(JSON.stringify({status:'awaiting-native-context-packets',packets:0,explanations:0}));process.exitCode=2;return;}
 for await(const packet of readContextArchive(archive)){
  if(session&&packet.meta.session!==session)continue;
  archivePackets++;
  const required=needed.has(packet.meta.session+':'+packet.meta.sequence);
  if(!required&&packets>=256)continue;
  const g=decodeContextPacket(packet),meta=packet.meta;
  const snapshot=snapshots.find(s=>s.session===meta.session&&s.match===meta.match&&s._programs);
  if(!snapshot){failures.push({sequence:g.sequence,reason:'programs-unavailable'});continue;}
  if(!g.valid||meta.sequence!==g.sequence){failures.push({sequence:g.sequence,reason:'invalid-native-packet'});continue;}
  const sid=meta.session+':'+meta.epoch,previous=sequences.get(sid);
  if(previous!==undefined&&g.sequence<=previous)failures.push({sequence:g.sequence,reason:'unordered-packets'});
  sequences.set(sid,g.sequence);
  g.match=meta.match;g.before.match=meta.match;g.after.match=meta.match;g.epoch=meta.epoch;
  const before=instantModel(g.before,snapshot._programs),after=instantModel(g.after,snapshot._programs);
  if(!before||!after||before.note!==meta.beforeNote||after.note!==meta.afterNote){failures.push({sequence:g.sequence,reason:'lua-js-model-differs',before:before?.note,after:after?.note,meta});continue;}
  g.beforeNote=before.note;g.afterNote=after.note;packets++;if(before.note!==after.note)nonzeroEvents++;
  for(const x of [before,after]){
   cases.push(x.input);expected.push(x.notes.map(n=>n.predicted));notes+=x.notes.length;
   for(const p of x.input.players)if(p.a===1){
    const hex=snapshot._programs[[2,0,3,1][formulaByCategory[p.v[11]]]],program=Buffer.from(hex,'hex'),args=Buffer.alloc(92*4);
    for(let at=0;at<program.length;at+=12)if(program.readUInt32LE(at)===7){const id=program.readUInt32LE(at+4);args.writeFloatLE(Math.fround(resolve(names[id-36],p,x.input)),id*4);}
    const key=hex+':'+args.toString('base64'),previous=rawCases.get(key);
    if(previous&&previous.expected!==p.v[6])throw Error('Equal native expression inputs with different expected points');
    rawCases.set(key,{program,args,expected:p.v[6]});
   }
  }
  if(required)selected.set(meta.session+':'+g.sequence,g);
 }
 const input=path.join(__dirname,'observed-context-native-input.tmp.bin'),output=path.join(__dirname,'observed-context-native-output.tmp.bin');
 const rawInput=path.join(__dirname,'observed-context-raw-input.tmp.bin'),rawOutput=path.join(__dirname,'observed-context-raw-output.tmp.bin');
 try{
  if(cases.length){
   writeCases(cases,input);
   const result=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'native-normalizer.ps1'),'-InputFile',input,'-OutputFile',output],{encoding:'utf8',windowsHide:true,timeout:120000});
   if(result.status!==0)throw Error('Native context validation failed '+result.stderr);
   const actual=readResults(output);if(actual.length!==cases.length)throw Error('Native context count differs');
   actual.forEach((row,i)=>{if(JSON.stringify(row)!==JSON.stringify(expected[i]))failures.push({state:i,reason:'original-normalizer-differs',actual:row,expected:expected[i]});});
   const rawRows=[...rawCases.values()],parts=[],count=Buffer.alloc(4);count.writeUInt32LE(rawRows.length);parts.push(count);
   for(const r of rawRows){const size=Buffer.alloc(4);size.writeUInt32LE(r.program.length);parts.push(size,r.program,r.args);}
   fs.writeFileSync(rawInput,Buffer.concat(parts));
   const rawRun=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'native-normalizer.ps1'),'-InputFile',rawInput,'-OutputFile',rawOutput,'-Raw'],{encoding:'utf8',windowsHide:true,timeout:120000});
   if(rawRun.status!==0)throw Error('Native context expression validation failed '+rawRun.stderr);
   const rawResult=fs.readFileSync(rawOutput);if(rawResult.length!==4+rawRows.length*4||rawResult.readUInt32LE()!==rawRows.length)throw Error('Native expression count differs');
   rawRows.forEach((r,i)=>{const native=rawResult.readFloatLE(4+i*4);if(native!==r.expected)failures.push({expression:i,reason:'original-expression-differs',actual:native,expected:r.expected});});
  }
 }finally{for(const f of [input,output,rawInput,rawOutput])if(fs.existsSync(f))fs.unlinkSync(f);}
 const checks=[];
 for(const e of explanations){
  const a=snapshots.find(x=>x.session===e.session&&x.generation===e.fromGeneration),b=snapshots.find(x=>x.session===e.session&&x.generation===e.generation);
  const groups=e.nativeEventSequences.map(n=>selected.get(e.session+':'+n));
  const chain=a&&b&&groups.every((g,i)=>g&&g.match===e.match&&g.epoch===e.epoch&&g.generationBefore>=a.generation&&g.generationAfter<b.generation&&(!i||g.sequence>groups[i-1].sequence));
  const expected=chain?observedTimeline(a,b,groups):null;
  let valid=!!expected;
  if(expected){
   for(const k of ['from','to','total','playerEffect','remainingEffect','eventEffect','contextEffect'])if(e[k]!==expected[k])valid=false;
   if(JSON.stringify(e.stateNotes)!==JSON.stringify(expected.stateNotes)||JSON.stringify(e.components)!==JSON.stringify(expected.components))valid=false;
  }
  checks.push({generation:e.generation,fromGeneration:e.fromGeneration,valid,total:e.total,components:e.components,eventEffect:e.eventEffect,contextEffect:e.contextEffect,nativeEvents:groups.length});
  if(!valid)failures.push({generation:e.generation,reason:'timeline-differs',expected});
 }
 const report={status:failures.length?'failed':packets?'compared':'awaiting-native-context-packets',session,archivePackets,packets,packetValidationLimit:256,states:cases.length,notes,nativeExpressions:rawCases.size,nonzeroEvents,explanations:checks.length,checks,failures,
  archiveSha256:require('crypto').createHash('sha256').update(fs.readFileSync(archive)).digest('hex'),definition:'native-event-marginals-at-observed-context',physicalActionValidated:false,historicalActionAttributionValidated:false};
 fs.writeFileSync(path.join(__dirname,'observed-context-live-validation.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({...report,failures:failures.slice(0,10)},null,2));if(failures.length)process.exitCode=1;else if(!packets||!checks.length)process.exitCode=2;
}
run().catch(error=>{console.error(error);process.exitCode=1;});
