const fs=require('fs'),path=require('path'),{readPe}=require('./pe-reader.cjs');
const pe=readPe(),events=[];
for(let type=0;type<=40;type++){
 const branch=pe.at(0xa22698+type,1)[0],destination=pe.at(0xa2264c+branch*4,4).readUInt32LE();
 const bytes=pe.at(destination,40);let call;
 // Handler branches consist of argument moves followed by one direct call.
 if(destination!==0xa22619)for(let i=0;i+5<=bytes.length;i++)if(bytes[i]===0xe8){call=destination+i+5+bytes.readInt32LE(i+1);break;}
 events.push({type,branch,destination:destination.toString(16),firstDirectCall:call?.toString(16),
  noHandler:destination===0xa22619,firstCallMayBeHelper:true});
}
const report={dispatcher:'a22130',callSite:'a0d33e',payloadBytes:0x320,staticAnalysisOnly:true,events};
fs.writeFileSync(path.join(__dirname,'event-dispatch-map.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
