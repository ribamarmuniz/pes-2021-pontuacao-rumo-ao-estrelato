const fs=require('fs'),path=require('path');
const {readPe}=require('./pe-reader.cjs');
const pe=readPe(),target=0x8caaa0,groups=new Map();
for(const call of pe.callsTo(target)){
 const fragment=pe.functionAt(call);if(!fragment)throw Error('Chamador sem funcao');
 const owner=pe.functionRoot(fragment);
 const key=owner.start;
 if(!groups.has(key))groups.set(key,{start:owner.start.toString(16),end:owner.end.toString(16),calls:[]});
 const bytes=pe.at(Math.max(owner.start,call-40),Math.min(40,call-owner.start));
 const literals=[];for(let i=0;i+5<=bytes.length;i++)if(bytes[i]===0xba)literals.push(bytes.readUInt32LE(i+1));
 groups.get(key).calls.push({rva:call.toString(16),nearbyEdxLiterals:literals});
}
for(const group of groups.values())group.callers=pe.callsTo(parseInt(group.start,16)).map(rva=>({
 rva:rva.toString(16),owner:pe.functionRoot(pe.functionAt(rva))?.start.toString(16)}));
const report={setterRva:target.toString(16),signature:pe.at(target,12).toString('hex'),
 staticAnalysisOnly:true,nearbyLiteralsAreCandidates:true,functions:[...groups.values()]};
fs.writeFileSync(path.join(__dirname,'stat-write-map.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
