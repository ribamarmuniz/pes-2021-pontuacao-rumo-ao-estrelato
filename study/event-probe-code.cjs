// x64 Windows ABI wrapper around the original event dispatcher.
// Read-only copies go to owned memory. No callback into Lua occurs here.
function buildEventProbe(a,base,options={}){
 const storage=options.storageBase??a,target=options.targetRva??0xa22130,payload=options.payload!==false;
 const parts=[],fixes=[],labels=new Map();let size=0;
 const emit=hex=>{const b=Buffer.from(hex,'hex');parts.push(b);size+=b.length;};
 const i32=n=>{const b=Buffer.alloc(4);b.writeInt32LE(n);return b.toString('hex');};
 const rel=(hex,target)=>{emit(hex);emit(i32(target-(a+size+4)));};
 const branch=(hex,name)=>{emit(hex);fixes.push({at:size,name});emit('00000000');};
 const mark=name=>labels.set(name,size);
 const save=()=>emit('488944242048894c242848895424304c894424384c894c24404c895424484c895c2450fc');
 const restore=()=>emit('488b742470488b7c2478488b442420488b4c2428488b5424304c8b4424384c8b4c24404c8b5424484c8b5c2450');
 const copy=(source,offset,bytes)=>{emit(source);emit('498dbc24'+i32(offset));emit('b9'+i32(bytes/4));emit('f3a5');};
 // Fixed stack frame allows valid Windows unwind metadata at every capture instruction.
 emit('41544881ecb0000000488974247048897c2478');
 save();
 emit('4531e4'); // no capture unless the career player is present
 rel('803d',storage+0x818-1);emit('00');branch('0f84','preEnd'); // trailing immediate adds one byte to RIP
 emit('488b8108bd0000488d80d0500700'); // manager and statistics root
 emit('488db0d86400004531d2');
 mark('scan');
 emit('817e04ba000080');branch('0f84','found');
 emit('4981fa4f000000');branch('0f84','preEnd');
 emit('41ffc24881c6342100004183fa28');branch('0f85','scan');
 emit('4881c630660000');branch('e9','scan'); // team-header gap
 mark('found');
 emit('4989f34889c2'); // r11=record, rdx=root
 emit('b801000000');rel('f0480fc105',storage+0x800); // lock xadd sequence
 emit('4c8d48014c898c2480000000');
 emit('4883e03f4869c000500000');rel('4c8d25',storage+0x1000);emit('4901c4');
 emit('4d890c2449c744240800000000');
 emit('49895424104d895c241849894c24204d89442428');
 if(payload)emit('418b004189442430');else emit('41c7442430feffffff49c744242800000000');
 emit('4589542434');
 emit('65488b0425480000004989442438'); // Windows TEB thread identifier
 emit('49c744244000000000'); // no stale generation markers if the rating probe is unavailable
 emit('8b8100bd00004189442450');
 emit('0f3148c1e2204809d04989442460'); // timestamp counter, not QPC
 if(payload)copy('498bf0',0x180,0x320);
 else {emit('31c0498dbc2480010000b9c8000000f3ab41c7842480010000feffffff');}
 copy('498bf3',0x500,0x2134);
 // root - 750d0 + 180760 + global-slot*16
 emit('498bc248c1e0044903442410480590b61000');
 copy('488bf0',0x100,16);
 rel('488b05',storage+0x810);emit('4885c0');branch('0f84','preEnd');
 emit('8b80000200004189442440');
 mark('preEnd');restore();
 const nativeCallOffset=size+1;rel('e8',base+target);
 save();
 emit('4d85e4');branch('0f84','postEnd');
 emit('4c8b9424800000004d391424');branch('0f85','postEnd');
 copy('498b742418',0x2800,0x2134);
 emit('418b44243448c1e0044903442410480590b61000');
 copy('488bf0',0x110,16);
 emit('0f3148c1e2204809d04989442468');
 rel('488b05',storage+0x810);emit('4885c0');branch('0f84','complete');
 emit('8b80000200004189442444');
 mark('complete');emit('4c8b9424800000004d89542408');
 mark('postEnd');restore();
 emit('4881c4b0000000415cc3');
 const code=Buffer.concat(parts);
 for(const f of fixes){if(!labels.has(f.name))throw Error('Missing label');code.writeInt32LE(labels.get(f.name)-f.at-4,f.at);}
 if(code.length>=(options.maxCodeBytes??0x800))throw Error('Code overlaps metadata');
 code.nativeCallOffset=nativeCallOffset;
 code.unwind=Buffer.from('0113070013740f000e640e000901160002c00000','hex');
 return code;
}
module.exports={buildEventProbe};
if(require.main===module){
 const fs=require('fs'),path=require('path');
 const code=buildEventProbe(0x144000000,0x140000000),output=Buffer.alloc(4096);
 const context=buildEventProbe(0x144000a00,0x140000000,{storageBase:0x144000000,targetRva:0xa23c10,payload:false,maxCodeBytes:0x300});
 code.copy(output);code.unwind.copy(output,0x900);output.writeUInt32LE(code.length,0x924);output.writeUInt32LE(0x900,0x928);
 context.copy(output,0xa00);context.unwind.copy(output,0xd00);output.writeUInt32LE(0xa00,0x92c);output.writeUInt32LE(0xa00+context.length,0x930);output.writeUInt32LE(0xd00,0x934);
 fs.writeFileSync(path.join(__dirname,'event-probe-test-code.bin'),output);
 console.log(JSON.stringify({bytes:code.length,contextBytes:context.length,slots:64,stride:0x5000,syntheticTestOnly:true}));
}
