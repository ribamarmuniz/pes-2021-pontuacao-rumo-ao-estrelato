const fs=require('fs'),path=require('path'),cp=require('child_process'),crypto=require('crypto');
const {buildEventProbe}=require('./event-probe-code.cjs');
const source=fs.readFileSync(path.join(__dirname,'..','modules','bal_painel.lua'),'utf8');
const hex=source.match(/local code_hex="([0-9a-f]+)"/)[1],offset=Number(source.match(/local native_call_offset=(\d+)/)[1]);
const unwind=Buffer.from(source.match(/local unwind_hex="([0-9a-f]+)"/)[1],'hex');
const contextCode=Buffer.from(source.match(/local context_code_hex="([0-9a-f]+)"/)[1],'hex');
const contextOffset=Number(source.match(/local context_call_offset=(\d+)/)[1]);
const code=Buffer.from(hex,'hex'),expected=buildEventProbe(0x144000000,0x140000000);
code.writeInt32LE(0x140000000+0xa22130-(0x144000000+offset+4),offset);
if(!code.equals(expected)||!unwind.equals(expected.unwind)||offset!==expected.nativeCallOffset)throw Error('Codigo incorporado diferente da referencia');
contextCode.writeInt32LE(0x140000000+0xa23c10-(0x144000000+0xa00+contextOffset+4),contextOffset);
const expectedContext=buildEventProbe(0x144000a00,0x140000000,{storageBase:0x144000000,targetRva:0xa23c10,payload:false,maxCodeBytes:0x300});
if(!contextCode.equals(expectedContext)||!unwind.equals(expectedContext.unwind)||contextOffset!==expectedContext.nativeCallOffset)throw Error('Codigo de contexto incorporado diferente');
const bytes=Buffer.alloc(4096);code.copy(bytes);unwind.copy(bytes,0x900);bytes.writeUInt32LE(code.length,0x924);bytes.writeUInt32LE(0x900,0x928);
contextCode.copy(bytes,0xa00);unwind.copy(bytes,0xd00);bytes.writeUInt32LE(0xa00,0x92c);bytes.writeUInt32LE(0xa00+contextCode.length,0x930);bytes.writeUInt32LE(0xd00,0x934);
const file=path.join(__dirname,'event-probe-test-code.bin');fs.writeFileSync(file,bytes);
try{
 const run=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'test-event-probe.ps1'),'-CodeFile',file],{encoding:'utf8',windowsHide:true,timeout:30000});
 if(run.status!==0)throw Error('Ensaio nativo falhou '+run.stderr+' '+run.stdout);
 const result={...JSON.parse(run.stdout),embeddedBytesMatch:true,codeBytes:code.length,contextCodeBytes:contextCode.length,moduleSha256:crypto.createHash('sha256').update(source).digest('hex')};
 fs.writeFileSync(path.join(__dirname,'event-probe-selftest.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
}finally{fs.unlinkSync(file);}
