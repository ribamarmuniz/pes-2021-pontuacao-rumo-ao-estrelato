const fs=require('fs');
function writeCases(cases,file){
 const parts=[];
 const u=v=>{const b=Buffer.alloc(4);b.writeUInt32LE(v>>>0);parts.push(b);};
 const f=v=>{const b=Buffer.alloc(4);b.writeFloatLE(v);parts.push(b);};
 const d=v=>{const b=Buffer.alloc(8);b.writeDoubleLE(v);parts.push(b);};
 u(cases.length);
 for(const x of cases){
  u(x.players.length);f(x.duration);x.score.forEach(u);x.constants.forEach(f);
  for(const p of x.players){p.v.forEach(d);p.s.forEach(u);}
 }
 fs.writeFileSync(file,Buffer.concat(parts));
}
function readResults(file){
 const b=fs.readFileSync(file);let cursor=0;
 const u=()=>{const v=b.readUInt32LE(cursor);cursor+=4;return v;};
 const f=()=>{const v=b.readFloatLE(cursor);cursor+=4;return v;};
 const n=u(),out=[];
 for(let i=0;i<n;i++){const size=u();out.push(Array.from({length:size},f));}
 if(cursor!==b.length)throw Error('Trailing result bytes');
 return out;
}
module.exports={writeCases,readResults};
