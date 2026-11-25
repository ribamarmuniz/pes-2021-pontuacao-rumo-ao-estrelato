const fs=require('fs');
function readNativeEvents(file,session){
 const source=fs.readFileSync(file,'utf8'),lines=source.split(/\r?\n/),events=[],gaps=[],resets=[];
 for(let i=0;i<lines.length;i++)for(const [marker,into] of [['BAL_NATIVE_EVENT ',events],['BAL_NATIVE_EVENT_GAP ',gaps],['BAL_NATIVE_EVENT_RESET ',resets]]){
  if(!lines[i].includes(marker))continue;
  let value;try{value=JSON.parse(lines[i].split(marker)[1]);}
  catch(error){if(i===lines.length-1&&!source.endsWith('\n'))break;throw error;}
  if(!session||value.session===session)into.push(value);
 }
 return {events,gaps,resets};
}
module.exports={readNativeEvents};
