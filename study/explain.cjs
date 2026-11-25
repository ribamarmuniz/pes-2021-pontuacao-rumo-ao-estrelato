const {normalize}=require('./validate.cjs');
const {evaluate}=require('./compiled-program.cjs');
const {resolve,formulaByCategory}=require('./validate-raw.cjs');
function label(before,after){
 const d=id=>after.s[id]-before.s[id],groups=new Set();
 const has=ids=>ids.some(id=>d(id)>0);
 if(d(1)>0)groups.add('Gol contra');
 if(has([0,2,3]))groups.add('Gol');
 if(d(4)>0)groups.add('Assistencia');
 if(has([6,17,21])||after.u.slice(1).some((n,i)=>n>before.u[i+1]))groups.add('Finalizacao');
 if(has([22,23,24,25,26,27,28,29,30,31]))groups.add('Passe');
 if(has([49,50]))groups.add('Desarme');
 if(has([65,66])||after.u[0]>before.u[0])groups.add('Drible');
 if(has([77,78,84,85,86,87]))groups.add('Recuperacao');
 if(has([89,90,91,92,93,94,95]))groups.add('Perda');
 if(has([55]))groups.add('Falta');
 if(d(58)>0)groups.add('Cartao vermelho');else if(d(57)>0)groups.add('Cartao amarelo');
 if(groups.has('Gol')||groups.has('Gol contra'))groups.delete('Finalizacao');
 if(groups.size===1)return [...groups][0];
 if(!groups.size&&d(67)>0)return 'Toques de bola';
 return groups.size?'Acoes combinadas':'Dados individuais';
}
function explain(before,after,id=2147483834){
 if(!before.match||before.match!==after.match||before.session!==after.session)return null;
 const a=before.players.find(p=>p.v[2]===id),b=after.players.find(p=>p.v[2]===id);
 if(!a||!b||a.a!==1||b.a!==1||a.v[0]!==b.v[0]||a.v[1]!==b.v[1]||a.v[3]!==b.v[3]
  ||b.v[4]<a.v[4]||b.s.some((n,i)=>n<a.s[i])||b.u.some((n,i)=>n<a.u[i]))return null;
 const programs=after._programs;
 if(!programs||normalize(after).some(p=>p.difference!==0)||normalize(before).some(p=>p.difference!==0))return null;
 for(const p of after.players){
  if(p.a!==1)continue;
  const i=[2,0,3,1][formulaByCategory[p.v[11]]];
  if(i===undefined||evaluate(programs[i],name=>resolve(name,p,after))!==Math.fround(p.v[6]))return null;
 }
 const i=[2,0,3,1][formulaByCategory[b.v[11]]];if(i===undefined)return null;
 const trial=structuredClone(after),p=trial.players.find(p=>p.v[2]===id);
 p.s=[...a.s];p.u=[...a.u];
 p.v[6]=evaluate(programs[i],name=>resolve(name,p,trial));
 const isolated=normalize(trial).find(p=>p.id===id).predicted;
 const playerEffect=Math.fround(b.v[7]-isolated),total=Math.fround(b.v[7]-a.v[7]);
 return {label:label(a,b),from:a.v[7],to:b.v[7],total,playerEffect,
  contextEffect:Math.fround(total-playerEffect),trial,
  definition:'previous-player-counters-at-current-context',historicalActionAttribution:false};
}
function marginal(after,oldStats,oldUnique,id=2147483834){
 const p=after.players.find(p=>p.v[2]===id),programs=after._programs;
 if(!p||p.a!==1||!programs||!oldStats||!oldUnique)return null;
 if(normalize(after).some(q=>q.difference!==0))return null;
 for(const q of after.players){
  if(q.a!==1)continue;
  const k=[2,0,3,1][formulaByCategory[q.v[11]]];
  if(k===undefined||evaluate(programs[k],name=>resolve(name,q,after))!==Math.fround(q.v[6]))return null;
 }
 const i=[2,0,3,1][formulaByCategory[p.v[11]]];if(i===undefined)return null;
 const trial=structuredClone(after),changed=trial.players.find(q=>q.v[2]===id);
 changed.s=[...oldStats];changed.u=[...oldUnique];
 changed.v[6]=evaluate(programs[i],name=>resolve(name,changed,trial));
 const isolated=normalize(trial).find(q=>q.id===id).predicted;
 return {label:label(changed,p),playerEffect:Math.fround(p.v[7]-isolated),trial};
}
function explainPath(before,after,groups,id=2147483834){
 const a=before.players.find(p=>p.v[2]===id),b=after.players.find(p=>p.v[2]===id);
 const same=(a,b)=>a&&b&&a.length===b.length&&a.every((n,i)=>n===b[i]);
 if(!a||!b||a.v[7]<=0||before.match!==after.match||before.session!==after.session||b.a!==1
  ||a.v[0]!==b.v[0]||a.v[1]!==b.v[1]||a.v[3]!==b.v[3]||b.v[4]<a.v[4])return null;
 const initial=marginal(after,a.s,a.u,id);if(!initial)return null;
 let s=a.s,u=a.u,previous=after.players.find(p=>p.v[2]===id).v[7]-initial.playerEffect,sum=0;
 const components=[],trials=[initial.trial],stateNotes=[previous];
 for(const group of groups){
  if(!group.previous||!same(s,group.previous.s)||!same(u,group.previous.u)||!group.chainCoherent)return null;
  if(group.s.some((n,i)=>n<s[i])||group.u.some((n,i)=>n<u[i]))return null;
  const e=marginal(after,group.s,group.u,id);if(!e)return null;
  const next=b.v[7]-e.playerEffect,effect=Math.fround(next-previous);
  if(effect)components.push({label:group.label||label({s,u},{s:group.s,u:group.u}),effect});
  sum=Math.fround(sum+effect);previous=next;s=group.s;u=group.u;trials.push(e.trial);stateNotes.push(next);
 }
 if(!same(s,b.s)||!same(u,b.u))return null;
 const total=Math.fround(b.v[7]-a.v[7]),rest=Math.fround(total-sum);
 if(Math.fround(sum+rest)!==total)return null;
 return {from:a.v[7],to:b.v[7],total,components,playerEffect:sum,remainingEffect:rest,trials,stateNotes,
  definition:'observed-input-order-with-current-context-fixed',historicalActionAttribution:false};
}
module.exports={label,explain,marginal,explainPath};
