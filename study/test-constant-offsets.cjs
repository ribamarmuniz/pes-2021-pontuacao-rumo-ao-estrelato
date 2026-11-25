const fs=require('fs'),path=require('path'),cp=require('child_process');
const dir=__dirname,file=path.join(dir,'constant-offsets.tmp.lua');
const source=fs.readFileSync(path.join(dir,'../modules/bal_painel.lua'),'utf8');
const loop=source.match(/for i=0,0x294\/4 do values[^\n]+/)[0];
const factory=fs.readFileSync(path.join(dir,'rating-model.lua'),'utf8').replace(/\nreturn create_rating_model\s*$/,'');
const observed=fs.readFileSync(path.join(dir,'observed-context-model.lua'),'utf8').replace(/\nreturn extend_observed_context_model\s*$/,'');
let fixture=fs.readFileSync(path.join(dir,'observed-context-selftest.lua'),'utf8');
const checks=`
for _,input in ipairs({before,after}) do
    local expected=model.normalize(input)
    local original=input.constants
    for missing=120,149 do
        local cf={}
        for i=1,166 do cf[i-1]=original[i] end
        cf[missing]=nil
        local values={}
        ${loop}
        assert(#values==166,"Constant offsets shifted")
        assert(values[missing+1]~=values[missing+1],"Missing word was invented")
        input.constants=values
        assert(model.same(model.normalize(input),expected),"Native-reference notes changed")
    end
    input.constants=original
end
`;
fixture=fixture.replace('return true,result',checks+'\nreturn true,result');
const code=factory+'\n'+observed+'\n'+fixture+'\nlocal F=function(x)return (string.unpack("f",string.pack("f",x)))end\nassert(run_observed_context_selftest(extend_observed_context_model(create_rating_model(F),F)))\nprint("Constant offsets passed: 60 missing-word cases against native-reference notes")\n';
fs.writeFileSync(file,code);
try{
 const cli=process.env.FENGARI_CLI||path.resolve(dir,'../../../.test-tools/node_modules/fengari-node-cli/src/lua-cli.js');
 const r=cp.spawnSync(process.execPath,[cli,file],{encoding:'utf8',windowsHide:true});
 if(r.status!==0||!r.stdout.includes('Constant offsets passed'))throw Error(r.stderr+'\n'+r.stdout);
 console.log(r.stdout.trim());
 fs.writeFileSync(path.join(dir,'constant-offsets-selftest.json'),JSON.stringify({passed:true,cases:60,missingWordsPreserved:true,nativeReferenceNotesUnchanged:true})+'\n');
}finally{fs.unlinkSync(file);}
