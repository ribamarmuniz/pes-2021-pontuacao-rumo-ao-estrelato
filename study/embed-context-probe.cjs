const fs=require('fs'),path=require('path'),{buildContextProbe}=require('./event-context-code.cjs');
const dir=__dirname,moduleFile=path.join(dir,'..','modules','bal_painel.lua');
let source=fs.readFileSync(moduleFile,'utf8');
const code=buildContextProbe(0,0);
let factory=fs.readFileSync(path.join(dir,'context-probe.lua'),'utf8');
factory=factory.replace(/    -- BEGIN generated context code[\s\S]*?    -- END generated context code/,
 '    -- BEGIN generated context code\n    local code_hex="'+code.toString('hex')+'"\n    local native_call_offset='+code.nativeCallOffset+'\n    local world_offsets={'+code.worldOffsets.join(',')+'}\n    local unwind_hex="'+code.unwind.toString('hex')+'"\n    -- END generated context code');
fs.writeFileSync(path.join(dir,'context-probe.lua'),factory);
function body(file,name){return fs.readFileSync(path.join(dir,file),'utf8').replace(new RegExp('\\nreturn '+name+'\\s*$'),'');}
const codeblock='-- BEGIN embedded observed context\n'+body('observed-context-model.lua','extend_observed_context_model')+'\n'+body('observed-context-selftest.lua','run_observed_context_selftest')+'\n-- END embedded observed context\n';
if(source.includes('-- BEGIN embedded observed context'))source=source.replace(/-- BEGIN embedded observed context[\s\S]*?-- END embedded observed context\n/,codeblock);
else source=source.replace('local rating_capture = (function()',codeblock+'local rating_capture = (function()');
const block='-- BEGIN embedded context collector\n'+body('context-state.lua','create_context_decoder')+'\n'+body('context-archive.lua','create_context_archive')+'\n'+factory.replace(/\nreturn create_full_context_probe\s*$/,'')+'\n-- END embedded context collector\n';
if(source.includes('-- BEGIN embedded context collector'))source=source.replace(/-- BEGIN embedded context collector[\s\S]*?-- END embedded context collector\n/,block);
else source=source.replace('function m.init(ctx,api,base)',block+'function m.init(ctx,api,base)');
fs.writeFileSync(moduleFile,source);
console.log(JSON.stringify({embedded:true,codeBytes:code.length,nativeCallOffset:code.nativeCallOffset}));
