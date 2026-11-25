const fs=require('fs'),path=require('path'),cp=require('child_process');
const dir=__dirname,file=path.join(dir,'observed-lua-test.tmp.lua');
function body(name,returned){return fs.readFileSync(path.join(dir,name),'utf8').replace(new RegExp('\\nreturn '+returned+'\\s*$'),'');}
const code=body('rating-model.lua','create_rating_model')+'\n'+body('observed-context-model.lua','extend_observed_context_model')+'\n'+fs.readFileSync(path.join(dir,'observed-context-selftest.lua'),'utf8')+
 '\nlocal function F(x)return (string.unpack("f",string.pack("f",x)))end\nlocal m=extend_observed_context_model(create_rating_model(F),F)\nassert(run_observed_context_selftest(m),"Observed-context model selftest failed")\nassert(m.context_label({players={},duration=10,constants={1,2}}, {players={},duration=10,constants={1}})=="Contexto da partida")\nassert(m.context_label({players={},duration=10,constants={1,2}}, {players={},duration=10,constants={1,false}})=="Contexto da partida")\nprint("Lua observed-context model passed")\n';
fs.writeFileSync(file,code);
try{
 const executable=process.platform==='win32'?'npm.cmd':'npm';
 const result=cp.spawnSync(executable,['exec','--offline','--cache','.tool-cache','--yes','--package=fengari-node-cli','--','fengari',file],{encoding:'utf8',windowsHide:true,shell:process.platform==='win32'});
 if(result.status!==0||!result.stdout.includes('Lua observed-context model passed'))throw Error(result.stderr+'\n'+result.stdout);
 console.log(result.stdout.trim());fs.writeFileSync(path.join(dir,'observed-lua-selftest.json'),JSON.stringify({passed:true,synthetic:true,runtime:'Fengari Lua 5.3',float32:'string.pack f / unpack f',nativeReference:'observed-context-selftest-native.json'})+'\n');
}finally{fs.unlinkSync(file);}
