// Observed intervals are not isolated actions. No causal rating is assigned.
const {readStudy,defaultLog}=require('./read-study.cjs');
const snapshots=readStudy(process.argv[2]||defaultLog()).snapshots;
const target=2147483834;
const changes=(a,b)=>b.flatMap((value,id)=>value===a[id]?[]:[{id,before:a[id],after:value}]);
const transitions=[];
for(let i=1;i<snapshots.length;i++){
 const a=snapshots[i-1],b=snapshots[i];
 if(a.session!==b.session||a.schema<5||b.schema<5)continue;
 if(a.match&&b.match&&a.match!==b.match)continue;
 const pa=a.players.find(p=>p.v[2]===target),pb=b.players.find(p=>p.v[2]===target);
 if(!pa||!pb||pa.v[0]!==pb.v[0]||pa.v[1]!==pb.v[1]||pb.v[4]<pa.v[4])continue;
 if(pa.v[7]===pb.v[7])continue;
 const peers=[];
 for(const p of b.players){
  if(p.v[2]===target)continue;
  const prior=a.players.find(q=>q.v[2]===p.v[2]&&q.v[0]===p.v[0]&&q.v[1]===p.v[1]);
  if(!prior||JSON.stringify(prior)!==JSON.stringify(p))peers.push(p.v[2]);
 }
 transitions.push({session:b.session,fromGeneration:a.generation,toGeneration:b.generation,
  seconds:b.time-a.time,fromMinute:pa.v[4],toMinute:pb.v[4],
  noteBefore:pa.v[7],noteAfter:pb.v[7],observedRatingChange:pb.v[7]-pa.v[7],
  changedCounters:changes(pa.s,pb.s),changedUniqueCounters:changes(pa.u,pb.u),
  changedParticipationGoals:changes(pa.t,pb.t),changedScore:changes(a.score,b.score),
  changedPlayerContext:changes(pa.v,pb.v).filter(c=>![6,7,8].includes(c.id)),
  changedPeers:peers,matchIdentityVerified:!!a.match&&a.match===b.match,historicalActionAttribution:false,
  status:'interval-requires-event-isolation'});
}
console.log(JSON.stringify({transitions,historicalActionAttribution:false},null,2));
