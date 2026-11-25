const fs=require('fs');
const {defaultLog}=require('./read-study.cjs');
const file=process.argv[2]||defaultLog(),session=process.argv[3];
const source=fs.readFileSync(file,'utf8'),lines=source.split(/\r?\n/);
const report={observations:0,baselines:0,counterChanges:0,notes:[],goalIntervals:[],atomicAction:false};
let previous;
for(let i=0;i<lines.length;i++){
 const marker='BAL_INPUT_OBSERVATION ';
 if(!lines[i].includes(marker))continue;
 let value;
 try{value=JSON.parse(lines[i].split(marker)[1]);}
 catch(error){if(i===lines.length-1&&!source.endsWith('\n'))break;throw error;}
 if(session&&value.session!==session)continue;
 report.observations++;
 if(value.reset){report.baselines++;previous=value;continue;}
 report.counterChanges+=value.changes.length;
 if(previous&&previous.session===value.session&&previous.match===value.match){
  const interval={session:value.session,match:value.match,from:previous.time,to:value.time,
   seconds:value.time-previous.time,minute:value.player[2],changes:value.changes,
   uniqueAvailable:value.uniqueAvailable===true,uniqueChanges:value.uniqueChanges||[],
   atomicAction:false,historicalActionAttribution:false};
  if(value.player[3]!==previous.player[3])report.notes.push({...interval,
   before:previous.player[3],after:value.player[3]});
  if(value.changes.some(c=>c[0]===0&&c[2]>c[1]))report.goalIntervals.push(interval);
 }
 previous=value;
}
report.status=report.observations?'observed-intervals':'awaiting-observations';
console.log(JSON.stringify(report,null,2));
if(!report.observations)process.exitCode=2;
