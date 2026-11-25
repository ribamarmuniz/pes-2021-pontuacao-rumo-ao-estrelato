const fs=require('fs'),path=require('path'),cp=require('child_process'),{readContextArchive}=require('./read-context-archive.cjs');
const {decodeContextPacket}=require('./read-context-state.cjs');
const raw=path.join(__dirname,'context-archive-test-raw.bin'),archive=path.join(__dirname,'context-archive-test.balc');
(async()=>{
 try{
  const run=cp.spawnSync(process.execPath,[path.join(__dirname,'test-event-context.cjs'),raw],{encoding:'utf8',windowsHide:true,timeout:30000});
  if(run.status!==0)throw Error('Fixture nativo falhou '+run.stderr);
  let count=0;
  for await(const packet of readContextArchive(archive,{rawFixture:raw})){
   if(!packet.meta.synthetic||packet.meta.session!=='selftest'||!packet.raw.equals(fs.readFileSync(raw)))throw Error('Pacote diferente apos compressao');count++;
   const context=decodeContextPacket(packet);
   if(!context.valid||context.before.players.length!==54||context.after.players.length!==54||context.before.score.join()!=='1,1')throw Error('Estado completo decodificado diferente');
   const targetA=context.before.players.find(p=>p.v[2]===2147483834),targetB=context.after.players.find(p=>p.v[2]===2147483834);
   const otherA=context.before.players.find(p=>p.v[2]===1004),otherB=context.after.players.find(p=>p.v[2]===1004);
   if(targetB.s[0]-targetA.s[0]!==1||otherB.s[22]-otherA.s[22]!==1||targetB.u[1]-targetA.u[1]!==1)throw Error('Alteracoes de jogadores diferentes nao recuperadas');
  }
  if(count!==1)throw Error('Quantidade de pacotes diferente');
  const report={passed:true,synthetic:true,packets:count,rawBytes:fs.statSync(raw).size,archiveBytes:fs.statSync(archive).size,lossless:true};
  fs.writeFileSync(path.join(__dirname,'context-archive-selftest.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
 }finally{for(const file of [raw,archive])if(fs.existsSync(file))fs.unlinkSync(file);}
})().catch(error=>{console.error(error);process.exitCode=1;});
