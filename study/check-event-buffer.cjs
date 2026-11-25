const fs=require('fs'),path=require('path'),cp=require('child_process'),{buildEventProbe}=require('./event-probe-code.cjs');
const run=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'read-event-buffer.ps1')],{encoding:'utf8',windowsHide:true,timeout:30000});
if(run.status!==0)throw Error('Inspecao somente leitura falhou '+run.stderr);
const observed=JSON.parse(run.stdout),primary=buildEventProbe(observed.address,observed.base);
const context=buildEventProbe(observed.address+0xa00,observed.base,{storageBase:observed.address,targetRva:0xa23c10,payload:false,maxCodeBytes:0x300});
if(!Buffer.from(observed.codeHex,'hex').equals(primary)||!Buffer.from(observed.contextCodeHex,'hex').equals(context))throw Error('Os bytes ativos diferem do codigo validado');
delete observed.codeHex;delete observed.contextCodeHex;
const report={...observed,wrappersMatchValidatedCode:true,stableSlots:observed.slots.length,
 contextSlots:observed.slots.filter(s=>s.type===4294967294).length,checkedAt:new Date().toISOString()};
fs.writeFileSync(path.join(__dirname,'event-buffer-health.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({pid:report.pid,enabled:report.enabled,readOnly:true,wrappersMatchValidatedCode:true,
 head:report.head,stableSlots:report.stableSlots,contextSlots:report.contextSlots},null,2));
