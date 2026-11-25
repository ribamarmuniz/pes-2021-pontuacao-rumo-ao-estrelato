const {evaluate}=require('./compiled-program.cjs'),{resolve,formulaByCategory}=require('./validate-raw.cjs'),{normalize}=require('./validate.cjs');
function instantModel(input,programs,id=2147483834){
 if(input.valid===false||!programs||input.schema<5)return null;
 const raw=[];
 for(const player of input.players){
  player.nativeRaw=Math.fround(player.v[6]);player.v[6]=player.nativeRaw;
  if(player.a===1){
   const index=[2,0,3,1][formulaByCategory[player.v[11]]];if(index===undefined)return null;
   const points=evaluate(programs[index],name=>resolve(name,player,input));if(!Number.isFinite(points))return null;
   player.v[6]=points;
  }
  raw.push([player.v[0]*40+player.v[1],player.v[6]]);
 }
 const notes=normalize(input);if(!notes||notes.length!==input.players.length||notes.some(n=>!Number.isFinite(n.predicted)))return null;
 const targets=notes.filter(n=>n.id===id);if(targets.length!==1)return null;const target=targets[0];
 return {note:target.predicted,raw,notes,input,virtual:true};
}
module.exports={instantModel};
