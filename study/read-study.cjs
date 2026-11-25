const fs=require('fs');
const path=require('path');
function defaultLog(){
 const archive=path.resolve(__dirname,'..','bal-rating-captures.log');
 return fs.existsSync(archive)?archive:path.resolve(__dirname,'..','sider.log');
}
function readStudy(file){
 const text=fs.readFileSync(file,'utf8'),lines=text.split(/\r?\n/);
 const snapshots=[],programSets=[];
 let programs=null;
 for(let i=0;i<lines.length;i++){
  const line=lines[i];
  const kind=['SESSION','PROGRAMS','SNAPSHOT'].find(kind=>line.includes('BAL_RATING_'+kind+' '));
  if(!kind)continue;
  let value;
  try{value=JSON.parse(line.split('BAL_RATING_'+kind+' ')[1]);}
  catch(error){
   if(i===lines.length-1&&!text.endsWith('\n'))break;
   throw new Error('Registro invalido na linha '+(i+1),{cause:error});
  }
  if(kind==='SESSION')programs=null;
  else if(kind==='PROGRAMS'){programs=value;programSets.push(value);}
  else{
   Object.defineProperty(value,'_programs',{value:programs,enumerable:false});
   snapshots.push(value);
  }
 }
 return {snapshots,programSets};
}
module.exports={defaultLog,readStudy};
