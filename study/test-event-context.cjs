const fs=require('fs'),path=require('path'),cp=require('child_process');
const {buildContextProbe}=require('./event-context-code.cjs');
const base=0x140000000,address=0x144000000,code=buildContextProbe(address,base),context=buildContextProbe(address+0x1000,base,{storageBase:address,targetRva:0xa23c10,payload:false});
const data=Buffer.alloc(0x4000);code.copy(data);context.copy(data,0x1000);code.unwind.copy(data,0x2800);context.unwind.copy(data,0x2820);
data.writeUInt32LE(code.length,0x2844);data.writeUInt32LE(0x2800,0x2848);data.writeUInt32LE(0x1000,0x284c);data.writeUInt32LE(0x1000+context.length,0x2850);data.writeUInt32LE(0x2820,0x2854);
const file=path.join(__dirname,'event-context-test-code-'+process.pid+'.bin');fs.writeFileSync(file,data);
try{
 const args=['-NoProfile','-File',path.join(__dirname,'test-event-context.ps1'),'-CodeFile',file];
 if(process.argv[2])args.push('-PacketFile',path.resolve(process.argv[2]));
 const run=cp.spawnSync('pwsh',args,{encoding:'utf8',windowsHide:true,timeout:30000});
 if(run.status!==0)throw Error('Teste completo falhou '+run.stderr+' '+run.stdout);
 const result={...JSON.parse(run.stdout),codeBytes:code.length,contextCodeBytes:context.length};
 fs.writeFileSync(path.join(__dirname,'event-context-selftest.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
}finally{if(fs.existsSync(file))fs.unlinkSync(file);}
