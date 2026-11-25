const fs=require('fs');
const defaultExe='C:\\Games\\PES2021\\PES2021.exe';
function readPe(file=defaultExe){
 const fd=fs.openSync(file,'r');
 try{
  const header=Buffer.alloc(4096);fs.readSync(fd,header,0,header.length,0);
  const pe=header.readUInt32LE(60),optional=pe+24;
  if(header.toString('ascii',pe,pe+4)!=='PE\0\0')throw Error('PE invalido');
  const base=Number(header.readBigUInt64LE(optional+24)),sections=[];
  const table=optional+header.readUInt16LE(pe+20);
  for(let i=0;i<header.readUInt16LE(pe+6);i++){
   const at=table+i*40,name=header.toString('ascii',at,at+8).replace(/\0/g,'');
   const rva=header.readUInt32LE(at+12),size=header.readUInt32LE(at+16),offset=header.readUInt32LE(at+20);
   if(!['.trace','.pdata','.rdata'].includes(name))continue;
   const bytes=Buffer.alloc(size);fs.readSync(fd,bytes,0,size,offset);sections.push({name,rva,size,bytes});
  }
  const functions=[],pdata=sections.find(s=>s.name==='.pdata');
  for(let at=0;at+12<=pdata.size;at+=12){
   const start=pdata.bytes.readUInt32LE(at),end=pdata.bytes.readUInt32LE(at+4),unwind=pdata.bytes.readUInt32LE(at+8);
   if(start&&end>start)functions.push({start,end,unwind});
  }
  const at=(rva,size)=>{const s=sections.find(s=>rva>=s.rva&&rva+size<=s.rva+s.size);if(!s)throw Error('RVA fora das secoes');return s.bytes.subarray(rva-s.rva,rva-s.rva+size);};
  const functionAt=rva=>functions.find(f=>rva>=f.start&&rva<f.end);
  const functionRoot=f=>{
   const seen=new Set();
   while(f){
    if(seen.has(f.unwind))throw Error('Ciclo nos dados de unwind');seen.add(f.unwind);
    const head=at(f.unwind,4),flags=head[0]>>>3;
    if(!(flags&4))return f;
    const offset=(4+head[2]*2+3)&~3,chain=at(f.unwind+offset,12);
    f={start:chain.readUInt32LE(0),end:chain.readUInt32LE(4),unwind:chain.readUInt32LE(8)};
   }
  };
  const callsTo=target=>{
   const result=[];
   for(const s of sections.filter(s=>s.name==='.trace'))for(let i=0;i+5<=s.size;i++)
    if(s.bytes[i]===0xe8&&s.rva+i+5+s.bytes.readInt32LE(i+1)===target)result.push(s.rva+i);
   return result;
  };
  return {file,base,sections,functions,at,functionAt,functionRoot,callsTo};
 }finally{fs.closeSync(fd);}
}
module.exports={readPe,defaultExe};
