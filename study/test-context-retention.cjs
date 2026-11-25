const fs=require('fs'),path=require('path'),cp=require('child_process');
const dir=__dirname,file=path.join(dir,'context-retention.tmp.lua');
function body(name,returned){return fs.readFileSync(path.join(dir,name),'utf8').replace(new RegExp('\\nreturn '+returned+'\\s*$'),'');}
const luaFile=path.resolve(dir,'../modules/bal_painel.lua').replace(/\\/g,'/');
const code=body('rating-model.lua','create_rating_model')+'\n'+body('observed-context-model.lua','extend_observed_context_model')+'\n'+
 fs.readFileSync(path.join(dir,'observed-context-selftest.lua'),'utf8')+'\n'+body('context-probe.lua','create_full_context_probe')+'\n'+
 'local moduleFile='+JSON.stringify(luaFile)+'\n'+fs.readFileSync(path.join(dir,'test-context-retention.lua'),'utf8');
fs.writeFileSync(file,code);
try{
 const cli=process.env.FENGARI_CLI||path.resolve(dir,'../../../.test-tools/node_modules/fengari-node-cli/src/lua-cli.js');
 const result=cp.spawnSync(process.execPath,[cli,file],{encoding:'utf8',windowsHide:true});
 if(result.status!==0||!result.stdout.includes('Retention passed'))throw Error(result.stderr+'\n'+result.stdout);
 console.log(result.stdout.trim());
 fs.writeFileSync(path.join(dir,'context-retention-selftest.json'),JSON.stringify({passed:true,events:4096,fullContexts:2,exactTimeline:true,futureGeneration:true,missingEvidenceRejected:true,reset:true,moduleSyntax:true},null,2)+'\n');
}finally{fs.unlinkSync(file);}
