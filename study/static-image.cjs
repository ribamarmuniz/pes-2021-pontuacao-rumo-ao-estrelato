const fs=require('fs'),path=require('path');
const game='C:\\Games\\PES2021\\PES2021.exe';
const fd=fs.openSync(game,'r');const h=Buffer.alloc(4096);fs.readSync(fd,h,0,h.length,0);
const pe=h.readUInt32LE(60),opt=pe+24,ns=h.readUInt16LE(pe+6),ss=opt+h.readUInt16LE(pe+20),base=h.readBigUInt64LE(opt+24);
const sections=[];for(let i=0;i<ns;i++){let p=ss+i*40;sections.push({name:h.toString('ascii',p,p+8).replace(/\0/g,''),rva:h.readUInt32LE(p+12),size:h.readUInt32LE(p+16),raw:h.readUInt32LE(p+20)});}
if(process.argv[2]==='calls'){
 let targets=process.argv.slice(3).map(x=>parseInt(x,16)-Number(base));
 for(const s of sections.filter(x=>x.name==='.trace')){let b=Buffer.alloc(s.size);fs.readSync(fd,b,0,b.length,s.raw);for(let i=0;i<b.length-5;i++){if(b[i]!==0xe8&&b[i]!==0xe9)continue;let dest=s.rva+i+5+b.readInt32LE(i+1);if(targets.includes(dest))console.log((base+BigInt(s.rva+i)).toString(16),b[i]===0xe8?'call':'jump','to',dest.toString(16));}}
 fs.closeSync(fd);process.exit();
}
const mem=sections.filter(x=>['.trace','.rdata','.data','.pdata'].includes(x.name));
const sys=96,mod=152,thread=264,context=320,list=1552,name=list+16+mem.length*16;
const label=Buffer.from('PES2021-static.exe','utf16le'),rawStart=(name+4+label.length+7)&~7;
const b=Buffer.alloc(rawStart);b.writeUInt32LE(0x504d444d,0);b.writeUInt32LE(0xa793,4);b.writeUInt32LE(4,8);b.writeUInt32LE(32,12);b.writeBigUInt64LE(2n,24);
[[7,56,sys],[4,112,mod],[3,52,thread],[9,16+mem.length*16,list]].forEach((x,i)=>x.forEach((n,j)=>b.writeUInt32LE(n,32+i*12+j*4)));
b.writeUInt16LE(9,sys);b[sys+6]=1;b[sys+7]=1;b.writeUInt32LE(10,sys+8);b.writeUInt32LE(19045,sys+16);b.writeUInt32LE(2,sys+20);
b.writeUInt32LE(1,mod);b.writeBigUInt64LE(base,mod+4);b.writeUInt32LE(h.readUInt32LE(opt+56),mod+12);b.writeUInt32LE(name,mod+24);b.writeUInt32LE(0xfeef04bd,mod+28);
b.writeUInt32LE(1,thread);b.writeUInt32LE(1,thread+4);b.writeUInt32LE(1232,thread+44);b.writeUInt32LE(context,thread+48);b.writeUInt32LE(0x10000b,context+48);b.writeUInt16LE(0x33,context+56);b.writeUInt16LE(0x2b,context+66);b.writeUInt32LE(0x202,context+68);b.writeBigUInt64LE(base+0xa20020n,context+248);
b.writeBigUInt64LE(BigInt(mem.length),list);b.writeBigUInt64LE(BigInt(rawStart),list+8);mem.forEach((s,i)=>{b.writeBigUInt64LE(base+BigInt(s.rva),list+16+i*16);b.writeBigUInt64LE(BigInt(s.size),list+24+i*16);});b.writeUInt32LE(label.length,name);label.copy(b,name+4);
const dest=path.join(__dirname,'static.dmp'),out=fs.openSync(dest,'w');fs.writeSync(out,b);for(const s of mem){let data=Buffer.alloc(s.size);fs.readSync(fd,data,0,data.length,s.raw);fs.writeSync(out,data);}fs.closeSync(fd);fs.closeSync(out);console.log(JSON.stringify({dest,bytes:fs.statSync(dest).size,sections:mem}));
