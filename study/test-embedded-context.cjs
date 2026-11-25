const fs=require('fs'),path=require('path'),{buildContextProbe}=require('./event-context-code.cjs');
const source=fs.readFileSync(path.join(__dirname,'..','modules','bal_painel.lua'),'utf8').split('-- BEGIN embedded context collector')[1].split('-- END embedded context collector')[0];
const template=Buffer.from(source.match(/local code_hex="([a-f0-9]+)"/)[1],'hex');
const call=Number(source.match(/local native_call_offset=(\d+)/)[1]);
const worlds=source.match(/local world_offsets=\{([^}]+)\}/)[1].split(',').map(Number);
const base=0x140000000;
for(const address of [0x144000000,0x138000000,0x140000000+0x7e000000]){
 const expected=buildContextProbe(address,base),actual=Buffer.from(template);
 actual.writeInt32LE(base+0xa22130-address-call-4,call);
 for(const at of worlds)actual.writeInt32LE(base+0x36f3dc8-address-at-4,at);
 if(!actual.equals(expected))throw Error('Embedded machine-code relocation differs');
}
const report={passed:true,relocations:3,codeBytes:template.length,worldRelocations:worlds.length,chainedOriginalCall:true};
fs.writeFileSync(path.join(__dirname,'embedded-context-selftest.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
