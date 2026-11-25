const fs=require('fs'),path=require('path'),{buildEventProbe}=require('./event-probe-code.cjs');
const reference=path.join(__dirname,'event-probe.lua'),moduleFile=path.join(__dirname,'..','modules','bal_painel.lua');
const code=buildEventProbe(0,0);
const contextCode=buildEventProbe(0xa00,0,{storageBase:0,targetRva:0xa23c10,payload:false,maxCodeBytes:0x300});
let factory=fs.readFileSync(reference,'utf8');
factory=factory.replace(/    -- BEGIN generated event code[\s\S]*?    -- END generated event code/,
 '    -- BEGIN generated event code\n    local code_hex="'+code.toString('hex')+'"\n    local native_call_offset='+code.nativeCallOffset+'\n    local context_code_hex="'+contextCode.toString('hex')+'"\n    local context_call_offset='+contextCode.nativeCallOffset+'\n    local unwind_hex="'+code.unwind.toString('hex')+'"\n    -- END generated event code');
fs.writeFileSync(reference,factory);
factory=factory.replace(/\nreturn create_event_probe\s*$/,'');
let source=fs.readFileSync(moduleFile,'utf8');
const embedded='-- BEGIN embedded event collector\n'+factory+'\n-- END embedded event collector\n';
if(source.includes('-- BEGIN embedded event collector'))source=source.replace(/-- BEGIN embedded event collector[\s\S]*?-- END embedded event collector\n/,embedded);
else source=source.replace('function m.init(ctx,api,base)',embedded+'function m.init(ctx,api,base)');
fs.writeFileSync(moduleFile,source);
console.log(JSON.stringify({codeBytes:code.length,nativeCallOffset:code.nativeCallOffset,embedded:true}));
