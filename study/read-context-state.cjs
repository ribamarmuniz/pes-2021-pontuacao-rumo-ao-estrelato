function decodeState(raw,offset){
 const header=offset+0xec00,valid=raw.readUInt32LE(header)===1;
 const info={valid,root:Number(raw.readBigUInt64LE(header+8)),object:Number(raw.readBigUInt64LE(header+16)),
  frame:raw.readUInt32LE(header+24),frameBefore:raw.readUInt32LE(header+28),generation:raw.readUInt32LE(header+40),generationBefore:raw.readUInt32LE(header+44)};
 if(!valid)return info;
 const duration=raw.readFloatLE(header+4),constants=Array.from({length:166},(_,i)=>raw.readFloatLE(offset+0xc800+i*4));
 if(!Number.isFinite(duration)||duration<=0||duration>120)return {...info,valid:false,reason:'invalid-duration'};
 const goals=[],score=[0,0],count=raw[offset+0xcc00+0x1ef3];
 if(count>198)return {...info,valid:false,reason:'invalid-goal-count'};
 for(let i=0;i<count;i++){
  const at=offset+0xcc00+i*40,team=raw.readUInt32LE(at+4),minute=raw[at+12];
  if(team>1)return {...info,valid:false,reason:'invalid-goal-team'};
  goals.push([team,minute]);score[team]++;
 }
 const players=[];
 for(let team=0;team<2;team++){
  const categories=new Map();for(let i=0;i<11;i++)categories.set(raw.readUInt32LE(offset+0xcb2c+team*128+(i+1)*4),raw.readUInt32LE(offset+0xcb00+team*128+i*4));
  for(let slot=0;slot<40;slot++){
   const row=offset+(team*40+slot)*0x280,start=raw[row+4],end=raw[row+5];if(start===255)continue;
   let role=13,max=0;for(let i=0;i<13;i++){const n=raw.readUInt32LE(row+0x24c+i*4);if(n>max){role=i;max=n;}}
   const s=Array.from({length:135},(_,i)=>raw.readUInt32LE(row+0x20+i*4)),u=Array.from({length:4},(_,i)=>raw.readUInt32LE(row+0x23c+i*4));
   const t=[0,0];for(const [side,minute] of goals)if(minute>=start&&minute<=end)t[side]++;
   const category=categories.get(slot),active=categories.has(slot)?1:0;
   const v=[team,slot,raw.readUInt32LE(row),start,end,role,raw.readFloatLE(row+8),raw.readFloatLE(row+12),raw.readFloatLE(row+24),
    raw.readUInt32LE(row+16),raw.readUInt32LE(row+20),category??255];
   if(v.some(n=>!Number.isFinite(n)))return {...info,valid:false,reason:'invalid-player-number'};
   players.push({v,s,u,t,a:active});
  }
 }
 return {...info,schema:6,duration,constants,goals,score,players};
}
function decodeContextPacket(packet){
 const {raw,meta}=packet;if(raw.length!==0x20000)throw Error('Tamanho de pacote diferente');
 const sequence=Number(raw.readBigUInt64LE(0)),completed=Number(raw.readBigUInt64LE(8)),type=raw.readUInt32LE(48);
 const before=decodeState(raw,0x1000),after=decodeState(raw,0x10000),overlap=raw.readUInt32LE(0x58)!==0;
 const generationBefore=raw.readUInt32LE(64),generationAfter=raw.readUInt32LE(68),root=Number(raw.readBigUInt64LE(16));
 const cpuTicksBefore=Number(raw.readBigUInt64LE(96)),cpuTicksAfter=Number(raw.readBigUInt64LE(104));
 const valid=before.valid&&after.valid&&!overlap&&Number.isSafeInteger(sequence)&&sequence>0&&sequence===completed&&before.root===root&&after.root===root
  &&before.frame===before.frameBefore&&after.frame===after.frameBefore&&before.frame===after.frame
  &&before.generation===before.generationBefore&&after.generation===after.generationBefore
  &&before.generation===generationBefore&&after.generation===generationAfter&&generationBefore===generationAfter&&generationBefore>0&&generationBefore%2===0
  &&raw.readUInt32LE(0x180)===type&&cpuTicksBefore<=cpuTicksAfter;
 return {meta,sequence,type,slot:raw.readUInt32LE(52),root,before,after,overlap,generationBefore,generationAfter,valid,
  contextUpdate:type===4294967294,cpuTicksBefore,cpuTicksAfter};
}
module.exports={decodeState,decodeContextPacket};
