const fs=require('fs');
function readObservations(file){
 const source=fs.readFileSync(file,'utf8'),lines=source.split(/\r?\n/),states=[],current=new Map();
 for(let i=0;i<lines.length;i++){
  const marker='BAL_INPUT_OBSERVATION ';if(!lines[i].includes(marker))continue;
  let row;try{row=JSON.parse(lines[i].split(marker)[1]);}catch(error){if(i===lines.length-1&&!source.endsWith('\n'))break;throw error;}
  const key=row.session+':'+row.match,previous=row.reset?null:current.get(key);
  const s=previous?[...previous.s]:Array(135),u=previous&&previous.u?[...previous.u]:Array(4);
  let coherent=true;
  for(const [values,changes] of [[s,row.changes],[u,row.uniqueChanges||[]]])for(const [id,before,after] of changes){
   if(before!==-1&&values[id]!==undefined&&values[id]!==before)coherent=false;
   values[id]=after;
  }
  const next={...row,s,u:row.uniqueAvailable?u:null,previous,chainCoherent:coherent&&(!previous||previous.chainCoherent)};
  current.set(key,next);states.push(next);
 }
 return states;
}
module.exports={readObservations};
