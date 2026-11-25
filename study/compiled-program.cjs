// Names read from the expression-function table of the inspected executable.
const names = [
 'Goal','OwnGoal','FKGoal','PKGoal','Assist','Shoot','ShootSuccess','ShootInFrame',
 'ShootPK','Pass','PassSuccess','PassShort','PassShortSuccess','PassThrouh',
 'PassThrouhSuccess','PassLong','PassLongSuccess','Centering','CenteringSuccess',
 'CutPass','Tackle','TackleSuccess','DispossessDelay','DispossessPress','Clear',
 'Foul','OffSide','FK','IndirectFK','CK','CardYellow','CardRed','BallTouch','Dribble',
 'DribbleSuccess','GKShootFaced','GKInframeShootFaced','GKSave','GKShootPA',
 'SnatchTotal','SnatchByPassCut','SnatchByTackle','SnatchByBlock','SnatchByWedge',
 'SnatchedTotal','SnatchedDuringDribble','SnatchedDuringPass',
].map(name => 'StatsPlayer' + name).concat([
 'StatsTeamMyScore','StatsTeamEnemyScore','StatsTeamWin','StatsTeamLose','StatsTeamDraw',
 'UnqStatsPlayerDribbleAttack','UnqStatsPlayerShootShort','UnqStatsPlayerShootMiddle','UnqStatsPlayerShootLong',
]);
function evaluate(hex, resolve) {
 const data=Buffer.from(hex,'hex');
 if (!data.length || data.length%12) throw Error('Invalid program length');
 const count=data.length/12, active=new Set();
 function node(index){
  if(index<0||index>=count||active.has(index))throw Error('Invalid expression node');
  active.add(index);
  const offset=index*12, type=data.readUInt32LE(offset);
  const left=data.readUInt32LE(offset+4),right=data.readUInt32LE(offset+8);
  let result;
  if(type===4)result=data.readFloatLE(offset+4);
  else if(type===5){
   if(left>=count||right!==0xffffffff)throw Error('Unsupported expression arguments');
   const id=data.readUInt32LE(left*12+4);
   const name=names[id-36];
   if(!name)throw Error('Unknown function '+id);
   result=Math.fround(resolve(name));
  }else{
   const a=node(left),b=node(right);
   if(type===0)result=Math.fround(a+b);
   else if(type===1)result=Math.fround(a-b);
   else if(type===2)result=Math.fround(a*b);
   else if(type===3)result=Math.fround(a/b);
   else throw Error('Unknown expression type '+type);
  }
  active.delete(index);
  return result;
 }
 return node(count-1);
}
module.exports={evaluate,names};
