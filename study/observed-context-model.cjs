const {label}=require('./explain.cjs');
const f=Math.fround,add=(a,b)=>f(f(a)+f(b)),sub=(a,b)=>f(f(a)-f(b));
const same=(a,b)=>a&&b&&a.length===b.length&&a.every((n,i)=>n===b[i]);
const target=(x,id)=>{const found=x.players.filter(p=>p.v[2]===id);return found.length===1?found[0]:null;};
function contextLabel(a,b){
 if(a.players.length!==b.players.length||f(a.duration)!==f(b.duration)||a.constants.some((n,i)=>f(n)!==f(b.constants[i])))return 'Contexto da partida';
 let time=false,participation=false;
 for(let i=0;i<a.players.length;i++){
  const p=a.players[i],q=b.players[i];
  if([0,1,2,3,5,9,10].some(k=>p.v[k]!==q.v[k])||p.a!==q.a||(p.a===1&&p.v[11]!==q.v[11])
   ||(p.a===0&&f(p.v[6])!==f(q.v[6]))||!same(p.s,q.s)||!same(p.u,q.u))return 'Contexto da partida';
  if(p.v[4]!==q.v[4])time=true;if(!same(p.t,q.t))participation=true;
 }
 const score=!same(a.score,b.score);if(score&&!time)return 'Placar';if(time&&!score)return participation?'Participacao':'Tempo em campo';return 'Contexto da partida';
}
function eventLabel(a,b,id){
 const p=target(a,id),q=target(b,id);if(!p||!q)return 'Evento da partida';
 if(same(p.s,q.s)&&same(p.u,q.u))return !same(a.score,b.score)?'Placar':'Jogo coletivo';
 if(q.s[133]>p.s[133])return 'Defesa';if(q.s[54]>p.s[54])return 'Afastamento';if(q.s[56]>p.s[56])return 'Impedimento';return label(p,q);
}
function observedTimeline(before,after,groups,id=2147483834){
 const a=target(before,id),b=target(after,id);
 if(!a||!b||before.match!==after.match||a.v[7]<=0||b.v[7]<=0||a.v[0]!==b.v[0]||a.v[1]!==b.v[1]||a.v[3]!==b.v[3]||b.v[4]<a.v[4])return null;
 const components=[],stateNotes=[a.v[7]];let current=a.v[7],last=before,event=0,context=0;
 function append(label,effect,source,sequence=0){if(effect)components.push({label,effect,source,sequence});if(source==='event')event=add(event,effect);else context=add(context,effect);}
 for(const g of groups){
  if(g.valid===false||!Number.isFinite(g.beforeNote)||!Number.isFinite(g.afterNote)||g.beforeNote<=0||g.afterNote<=0)return null;
  const ga=target(g.before,id),gb=target(g.after,id);
  if(g.before.match!==before.match||g.after.match!==before.match||!ga||!gb||[0,1,3].some(k=>ga.v[k]!==a.v[k]||gb.v[k]!==a.v[k]))return null;
  append(contextLabel(last,g.before),sub(g.beforeNote,current),'context',g.sequence);
  append(g.contextUpdate?contextLabel(g.before,g.after):eventLabel(g.before,g.after,id),sub(g.afterNote,g.beforeNote),g.contextUpdate?'context':'event',g.sequence);
  stateNotes.push(g.beforeNote,g.afterNote);current=g.afterNote;last=g.after;
 }
 append(contextLabel(last,after),sub(b.v[7],current),'context');stateNotes.push(b.v[7]);
 const total=sub(b.v[7],a.v[7]);if(add(event,context)!==total)return null;
 return {from:a.v[7],to:b.v[7],total,components,eventEffect:event,contextEffect:context,playerEffect:event,remainingEffect:context,stateNotes,
  definition:'native-event-marginals-at-observed-context',historicalActionAttribution:false,physicalActionValidated:false};
}
module.exports={contextLabel,eventLabel,observedTimeline};
