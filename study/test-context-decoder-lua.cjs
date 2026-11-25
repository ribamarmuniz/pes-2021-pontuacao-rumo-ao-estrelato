const fs=require('fs'),path=require('path'),cp=require('child_process'),{decodeContextPacket}=require('./read-context-state.cjs');
const rawFile=path.join(__dirname,'decoder-fixture.tmp.bin'),luaFile=path.join(__dirname,'decoder-test.tmp.lua');
const run=cp.spawnSync(process.execPath,[path.join(__dirname,'test-event-context.cjs'),rawFile],{encoding:'utf8',windowsHide:true});
if(run.status!==0)throw Error(run.stderr);
try{
 const raw=fs.readFileSync(rawFile),expected=decodeContextPacket({raw,meta:{}});
 const projection={};for(const k of ['valid','sequence','root','type','generationBefore','generationAfter','contextUpdate','before','after'])projection[k]=expected[k];
 function lua(v){if(Array.isArray(v))return '{'+v.map(lua).join(',')+'}';if(v&&typeof v==='object')return '{'+Object.entries(v).map(([k,x])=>'['+JSON.stringify(k)+']='+lua(x)).join(',')+'}';return JSON.stringify(v);}
 const decoder=fs.readFileSync(path.join(__dirname,'context-state.lua'),'utf8').replace(/\nreturn create_context_decoder\s*$/,'');
 const mock=`local bytes="${Array.from(raw,n=>'\\'+String(n).padStart(3,'0')).join('')}"
local function u32(at)local a,b,c,d=string.byte(bytes,at+1,at+4);return a+b*256.0+c*65536.0+d*16777216.0 end
local pointer_mt={}
local function pointer(at)return setmetatable({offset=at},pointer_mt)end
pointer_mt.__add=function(a,b)return pointer(a.offset+b)end
pointer_mt.__index=function(p,i)return string.byte(bytes,p.offset+i+1)end
ffi={cast=function(kind,p)
 local stride=kind=="uint64_t *" and 8 or 4
 return setmetatable({},{__index=function(_,i)
  local at=p.offset+i*stride
  if kind=="float *" then return (string.unpack("f",bytes,at+1)) end
  if kind=="uint64_t *" then return u32(at)+u32(at+4)*4294967296.0 end
  return u32(at)
 end})
end}
`;
 const compare=`\nlocal expected=${lua(projection)}\nlocal actual=create_context_decoder()(pointer(0))\nlocal count=0\nlocal function same(a,b,path)\n if type(a)~=type(b) then error("Type differs "..path) end\n if type(a)=="table" then for k,v in pairs(b) do same(a[k],v,path.."."..tostring(k)) end else assert(a==b,"Value differs "..path.." "..tostring(a).." "..tostring(b));count=count+1 end\nend\nsame(actual,expected,"packet")\nprint("Lua decoder passed "..count.." scalar comparisons")\n`;
 fs.writeFileSync(luaFile,mock+decoder+compare);
 const result=cp.spawnSync('npm.cmd',['exec','--offline','--cache','.tool-cache','--yes','--package=fengari-node-cli','--','fengari',luaFile],{encoding:'utf8',windowsHide:true,shell:true});
 if(result.status!==0||!result.stdout.includes('Lua decoder passed'))throw Error(result.stderr+'\n'+result.stdout);
 console.log(result.stdout.trim());fs.writeFileSync(path.join(__dirname,'context-decoder-lua-selftest.json'),JSON.stringify({passed:true,synthetic:true,pointerAccess:'Lua mock over exact native-harness bytes',result:result.stdout.trim()})+'\n');
}finally{for(const f of [rawFile,luaFile])if(fs.existsSync(f))fs.unlinkSync(f);}
