const fs=require('fs'),path=require('path'),cp=require('child_process');
const {readStudy,defaultLog}=require('./read-study.cjs');
const {evaluate,names}=require('./compiled-program.cjs');
const {resolve,formulaByCategory}=require('./validate-raw.cjs');
const cases=[];
for(const [index,s] of readStudy(process.argv[2]||defaultLog()).snapshots.entries()){
 if(s.schema<5||!s._programs)continue;
 for(const p of s.players){
  const i=[2,0,3,1][formulaByCategory[p.v[11]]];if(i===undefined)continue;
  const hex=s._programs[i],b=Buffer.from(hex,'hex'),ids=new Set();
  for(let at=0;at<b.length;at+=12)if(b.readUInt32LE(at)===7)ids.add(b.readUInt32LE(at+4));
  const args=Array(92).fill(0);
  for(const id of ids)args[id]=Math.fround(resolve(names[id-36],p,s));
  const base={hex,args,label:'recorded',session:s.session,generation:s.generation,id:p.v[2]};cases.push(base);
  if(index%8===0&&p.v[2]===2147483834){
   for(const id of ids)for(const v of [0,1,2,10,1000]){
    const trial=[...args];trial[id]=v;
    cases.push({...base,args:trial,label:'getter-'+id+'-'+v});
   }
  }
 }
}
const parts=[];const u=v=>{const b=Buffer.alloc(4);b.writeUInt32LE(v);parts.push(b);};
u(cases.length);
for(const x of cases){const b=Buffer.from(x.hex,'hex');u(b.length);parts.push(b);const a=Buffer.alloc(92*4);x.args.forEach((v,i)=>a.writeFloatLE(v,i*4));parts.push(a);}
const input=path.join(__dirname,'native-raw-input.bin'),output=path.join(__dirname,'native-raw-output.bin');
fs.writeFileSync(input,Buffer.concat(parts));
const run=cp.spawnSync('pwsh',['-NoProfile','-File',path.join(__dirname,'native-normalizer.ps1'),'-InputFile',input,'-OutputFile',output,'-Raw'],{encoding:'utf8',timeout:120000,windowsHide:true});
if(run.status!==0)throw Error('Native expression process failed '+run.status+' '+run.stderr+' '+run.stdout);
const b=fs.readFileSync(output);if(b.readUInt32LE(0)!==cases.length||b.length!==4+cases.length*4)throw Error('Result count differs');
const failures=[];
cases.forEach((x,i)=>{
 const predicted=evaluate(x.hex,name=>x.args[names.indexOf(name)+36]),native=b.readFloatLE(4+i*4);
 if(predicted!==native)failures.push({session:x.session,generation:x.generation,id:x.id,label:x.label,predicted,native});
});
const report={cases:cases.length,failures,nativeArithmetic:'unmodified PES expression interpreter with supplied getter values',historicalActionAttribution:false};
fs.writeFileSync(path.join(__dirname,'native-raw-validation.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({...report,failures:failures.slice(0,20)},null,2));
if(failures.length)process.exitCode=1;
