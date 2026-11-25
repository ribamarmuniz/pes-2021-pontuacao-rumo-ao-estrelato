const fs = require('fs');
const base=0x140000000, a=0x141000000, site=base+0xa1de6c;
const expected=Buffer.from('4c8d9c24c0020000','hex');
const pieces=[];let length=0;
const emit=b=>{if(typeof b==='string')b=Buffer.from(b,'hex');pieces.push(b);length+=b.length;};
const i32=n=>{const b=Buffer.alloc(4);b.writeInt32LE(n);return b;};
function relative(hex,target){const b=Buffer.from(hex,'hex');const d=target-(a+length+b.length+4);emit(b);emit(i32(d));}
function copy(hex,destination,size){emit(hex);relative('488d3d',a+destination);emit('b9');emit(i32(size/4));emit('f3a5');}
emit('9c50515657fc');relative('ff05',a+512);
relative('488935',a+520);relative('4c893d',a+536);
emit('488b8608bd0000488d80d0500700');relative('488905',a+528);
copy('488bf0',0x1000,0xb2ca0);
relative('488b35',a+520);copy('488db6c0010000',0xb4000,80*16);
copy('498bf7',0xb4500,0x298);
relative('488b35',a+520);copy('488bb608bd0000488db660071800',0xb4800,80*16);
relative('488b35',a+528);copy('488db6bc8d1000',0xb6000,0x2000);
relative('488b05',base+0x36f3dc8);
for(let team=0;team<2;team++){
 copy('488bb0'+i32((team+0xa1)*40).toString('hex')+'488db6004c0000',0xb5000+team*128,44);
 copy('488bb0'+i32((team+0xa3)*40).toString('hex'),0xb5040+team*128,48);
}
relative('ff05',a+512);emit('5f5e59589d');emit(expected);relative('e9',site+expected.length);
const code=Buffer.concat(pieces);
if(code.length>=512)throw Error('Code exceeds reserved area');
// Patch only a synthetic static-image dump for disassembly, never the EXE.
if(process.argv[2]){
 const dump=fs.readFileSync(process.argv[2]);
 const memoryList=dump.readUInt32LE(32+3*12+8);
 const count=Number(dump.readBigUInt64LE(memoryList));
 let offset=Number(dump.readBigUInt64LE(memoryList+8));
 let found=false;
 for(let i=0;i<count;i++){
  const va=Number(dump.readBigUInt64LE(memoryList+16+i*16));
  const size=Number(dump.readBigUInt64LE(memoryList+24+i*16));
  if(a>=va&&a+code.length<=va+size){code.copy(dump,offset+a-va);found=true;break;}
  offset+=size;
 }
 if(!found)throw Error('Synthetic code area missing');
 fs.writeFileSync(process.argv[2],dump);
}
console.log(JSON.stringify({bytes:code.length,start:a.toString(16),return:(site+expected.length).toString(16)}));
