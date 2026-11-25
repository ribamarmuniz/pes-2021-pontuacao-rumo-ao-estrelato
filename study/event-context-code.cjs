// Full model-input copies at native event boundaries. No game data is written.
// Layout per state: 80*0x280 rows, constants at c800, lineups at cb00,
// goal table at cc00, validity/duration/root/frame metadata at ec00.
function buildContextProbe(a,base,options={}){
 const storage=options.storageBase??a,target=options.targetRva??0xa22130,payload=options.payload!==false;
 const parts=[],fixes=[],worldOffsets=[],labels=new Map();let size=0;
 const emit=hex=>{const b=Buffer.from(hex,'hex');parts.push(b);size+=b.length;};
 const i32=n=>{const b=Buffer.alloc(4);b.writeInt32LE(n);return b.toString('hex');};
 const rel=(hex,target)=>{emit(hex);emit(i32(target-(a+size+4)));};
 const branch=(hex,name)=>{emit(hex);fixes.push({at:size,name});emit('00000000');};
 const mark=name=>{if(labels.has(name))throw Error('Duplicate label');labels.set(name,size);};
 const save=()=>emit('488944242048894c242848895424304c894424384c894c24404c895424484c895c2450fc');
 const restore=()=>emit('488b742470488b7c2478488b442420488b4c2428488b5424304c8b4424384c8b4c24404c8b5424484c8b5c2450');
 const destination=offset=>emit('498dbc24'+i32(offset));
 const sequence=()=>{rel('488b05',storage+0x3010);emit('4885c0');branch('0f84','sequenceZero'+size);const label=fixes.at(-1).name;emit('8b8000020000');branch('e9',label+'End');mark(label);emit('31c0');mark(label+'End');};
 const pack=(offset,tag)=>{
  destination(offset);
  emit('498b442420488b8008bd0000488d80d0500700493b442410');branch('0f85',tag+'Unavailable');
  emit('498b4424208b8000bd00008987'+i32(0xec1c));
  sequence();emit('8987'+i32(0xec2c));
  emit('498b7424104881c6e06400004d8b5c24204981c3c00100004d8b5424104981c290b610004531c0');
  mark(tag+'Row');
  emit('8b46fc89070fb786e41800006689470466c747060000');
  emit('498b0348894708498b4308488947108b862c190000894718c7471c000000004883c720');
  emit('ba87000000');mark(tag+'Stat');
  emit('8b0603460403460803460c03461003461403461803461c89074883c6244883c70483ea01');branch('0f85',tag+'Stat');
  emit('498b02488907498b4208488947084883c7104983c2104983c3104881c6f8050000b90d000000f3a54881c60c08000041ffc04183f828');
  branch('0f85',tag+'NoGap');emit('4881c630660000');mark(tag+'NoGap');
  emit('4183f850');branch('0f82',tag+'Row');
  rel('488b05',storage+0x3010);emit('4885c0');branch('0f84',tag+'NoConfig');
  emit('488bb010020000493b742410');branch('0f85',tag+'NoConfig');
  emit('488bb008020000493b742420');branch('0f85',tag+'NoConfig');
  emit('4c8b90180200004d85d2');branch('0f84',tag+'NoConfig');
  // The existing native-calculation buffer owns this copy throughout the process.
  emit('488db000450b0041b901000000b9a6000000f3a5');branch('e9',tag+'ConfigDone');
  mark(tag+'NoConfig');emit('4531c94531d231c0b9a6000000f3ab');
  mark(tag+'ConfigDone');emit('4883c768');worldOffsets.push(size+3);rel('488b05',base+0x36f3dc8);
  emit('483d00000100');branch('0f82',tag+'NoWorld');
  for(let team=0;team<2;team++){
   emit('488bb0'+i32((team+0xa1)*40)+'4881fe00000100');branch('0f82',tag+'NoWorld');
   emit('4881c6004c0000b90b000000f3a5');
   emit('488bb0'+i32((team+0xa3)*40)+'4881fe00000100');branch('0f82',tag+'NoWorld');
   emit('b90c000000f3a54883c724');
  }
  emit('488bb0c00200004881fe00000100');branch('0f82',tag+'NoWorld');
  emit('448b4658');branch('e9',tag+'WorldDone');
  mark(tag+'NoWorld');emit('4531c94531c0');destination(offset+0xcb00);emit('31c0b940000000f3ab');
  mark(tag+'WorldDone');emit('498b7424104881c6bc8d1000b900080000f3a5');
  emit('44890f44894704498b44241048894708498b442420488947108b8000bd00008947184c8957203b471c');
  branch('0f85',tag+'Invalid');
  sequence();emit('8947283b472c');branch('0f85',tag+'Invalid');
  emit('a801');branch('0f85',tag+'Invalid');branch('e9',tag+'Done');
  mark(tag+'Invalid');emit('c70700000000');branch('e9',tag+'Done');
  mark(tag+'Unavailable');destination(offset+0xec00);emit('4889470831c08907894704');mark(tag+'Done');
 };
 emit('41544881ecb0000000488974247048897c2478');save();emit('4531e4');
 rel('803d',storage+0x3018-1);emit('00');branch('0f84','preEnd');
 emit('488b8108bd0000483d00000100');branch('0f82','preEnd');
 emit('488d80d0500700488db0d86400004531d2');mark('scan');
 emit('817e04ba000080');branch('0f84','found');
 emit('4183fa4f');branch('0f84','preEnd');
 emit('41ffc24881c6342100004183fa28');branch('0f85','scan');emit('4881c630660000');branch('e9','scan');
 mark('found');emit('4989f34889c2b801000000');rel('f0480fc105',storage+0x3000);
 emit('4c8d48014c898c24800000004883e03f48c1e011');rel('4c8d25',storage+0x4000);emit('4901c4');
 emit('4d890c2449c74424080000000049895424104d895c241849894c24204d89442428');
 if(payload)emit('418b004189442430');else emit('41c7442430feffffff49c744242800000000');
 emit('458954243465488b04254800000049894424388b8100bd00004189442450');
 emit('b801000000');rel('f0480fc105',storage+0x3020);emit('31d24885c00f95c20fb6d24189542458');
 branch('0f84','notOverlapping');rel('f048ff05',storage+0x3028);mark('notOverlapping');
 rel('488b05',storage+0x3028);emit('49894424700f3148c1e2204809d04989442460');
 if(payload){emit('498bf0');destination(0x180);emit('b9c8000000f3a5');}
 else{emit('31c0');destination(0x180);emit('b9c8000000f3ab41c7842480010000feffffff');}
 pack(0x1000,'before');sequence();emit('4189442440');
 mark('preEnd');restore();const nativeCallOffset=size+1;rel('e8',base+target);save();
 emit('4d85e4');branch('0f84','postEnd');emit('4c8b9424800000004d391424');branch('0f85','postDropped');
 pack(0x10000,'after');sequence();emit('41894424440f3148c1e2204809d04989442468');
 rel('488b05',storage+0x3028);emit('4989442478493b442470');branch('0f84','overlapChecked');emit('41c744245801000000');mark('overlapChecked');
 emit('4c8b9424800000004d89542408');mark('postDropped');rel('f048ff0d',storage+0x3020);
 mark('postEnd');restore();emit('4881c4b0000000415cc3');
 const code=Buffer.concat(parts);for(const f of fixes){if(!labels.has(f.name))throw Error('Missing label '+f.name);code.writeInt32LE(labels.get(f.name)-f.at-4,f.at);}
 if(code.length>=0x1000)throw Error('Full context code exceeds reserved page');
 code.nativeCallOffset=nativeCallOffset;code.worldOffsets=worldOffsets;code.unwind=Buffer.from('0113070013740f000e640e000901160002c00000','hex');return code;
}
module.exports={buildContextProbe};
