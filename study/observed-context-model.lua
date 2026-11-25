-- Adds virtual recalculation at the observed native-event contexts.
-- The result is never used as the original note displayed by the game.
local function extend_observed_context_model(model,F)
    local function add(a,b)return F(F(a)+F(b))end
    local function sub(a,b)return F(F(a)-F(b))end
    local function target(input,id)
        local found,index
        for i,p in ipairs(input.players) do
            if p.v[3]==id then if found then return end;found,index=p,i end
        end
        return found,index
    end
    function model.instant(programs,input,id)
        if not programs or input.valid==false then return end
        local raw={}
        for _,p in ipairs(input.players) do
            p.nativeRaw=F(p.v[7]);p.v[7]=p.nativeRaw
            if p.a==1 then
                local program=programs[model.profile[p.v[12]]]
                local points=model.raw(program,p,input)
                if not points or points~=points or math.abs(points)==math.huge then return end
                p.v[7]=points
            end
            raw[#raw+1]={p.v[1]*40+p.v[2],p.v[7]}
        end
        local notes=model.normalize(input)
        local p,index=target(input,id)
        if not notes or not p or not notes[index] or notes[index]~=notes[index] then return end
        return {note=notes[index],raw=raw,notes=notes,input=input,virtual=true}
    end
    function model.context_label(a,b)
        if #a.players~=#b.players or F(a.duration)~=F(b.duration) then return "Contexto da partida" end
        if #a.constants~=#b.constants then return "Contexto da partida" end
        for i,v in ipairs(a.constants) do
            local other=b.constants[i]
            if type(v)~="number" or type(other)~="number" or v~=v or other~=other
                or F(v)~=F(other) then return "Contexto da partida" end
        end
        local time_changed,participation_changed=false,false
        for i,p in ipairs(a.players) do
            local q=b.players[i]
            for _,k in ipairs({1,2,3,4,6,10,11}) do if p.v[k]~=q.v[k] then return "Contexto da partida" end end
            if p.a~=q.a or (p.a==1 and p.v[12]~=q.v[12]) or (p.a==0 and F(p.v[7])~=F(q.v[7]))
                or not model.same(p.s,q.s) or not model.same(p.u,q.u) then return "Contexto da partida" end
            if p.v[5]~=q.v[5] then time_changed=true end
            if not model.same(p.t,q.t) then participation_changed=true end
        end
        local score_changed=not model.same(a.score,b.score)
        if score_changed and not time_changed then return "Placar" end
        if time_changed and not score_changed then return participation_changed and "Participacao" or "Tempo em campo" end
        return "Contexto da partida"
    end
    function model.event_label(a,b,id)
        local p,q=target(a,id),target(b,id)
        if not p or not q then return "Evento da partida" end
        if model.same(p.s,q.s) and model.same(p.u,q.u) then
            return not model.same(a.score,b.score) and "Placar" or "Jogo coletivo"
        end
        if q.s[134]>p.s[134] then return "Defesa" end
        if q.s[55]>p.s[55] then return "Afastamento" end
        if q.s[57]>p.s[57] then return "Impedimento" end
        return model.label(p,q)
    end
    function model.observed_timeline(before,after,groups,id)
        local a,b=target(before,id),target(after,id)
        if not a or not b or before.match~=after.match or a.v[8]<=0 or b.v[8]<=0
            or a.v[1]~=b.v[1] or a.v[2]~=b.v[2] or a.v[4]~=b.v[4] or b.v[5]<a.v[5] then return end
        local components,notes={}, {a.v[8]}
        local current,last_input,event_sum,context_sum=a.v[8],before,0,0
        local function append(label,effect,source,sequence)
            if effect~=0 then components[#components+1]={label=label,effect=effect,source=source,sequence=sequence or 0} end
            if source=="event" then event_sum=add(event_sum,effect) else context_sum=add(context_sum,effect) end
        end
        for _,g in ipairs(groups) do
            if g.valid==false or not g.beforeNote or not g.afterNote or g.beforeNote<=0 or g.afterNote<=0 then return end
            local ga,gb=target(g.before,id),target(g.after,id)
            if g.before.match~=before.match or g.after.match~=before.match or not ga or not gb
                or ga.v[1]~=a.v[1] or gb.v[1]~=a.v[1] or ga.v[2]~=a.v[2] or gb.v[2]~=a.v[2]
                or ga.v[4]~=a.v[4] or gb.v[4]~=a.v[4] then return end
            append(model.context_label(last_input,g.before),sub(g.beforeNote,current),"context",g.sequence)
            append(g.contextUpdate and model.context_label(g.before,g.after) or model.event_label(g.before,g.after,id),
                sub(g.afterNote,g.beforeNote),g.contextUpdate and "context" or "event",g.sequence)
            notes[#notes+1]=g.beforeNote;notes[#notes+1]=g.afterNote
            current,last_input=g.afterNote,g.after
        end
        append(model.context_label(last_input,after),sub(b.v[8],current),"context",0)
        notes[#notes+1]=b.v[8]
        local total=sub(b.v[8],a.v[8])
        if add(event_sum,context_sum)~=total then return end
        return {from=a.v[8],to=b.v[8],total=total,components=components,eventEffect=event_sum,contextEffect=context_sum,
            playerEffect=event_sum,remainingEffect=context_sum,stateNotes=notes,
            definition="native-event-marginals-at-observed-context",historicalActionAttribution=false,physicalActionValidated=false}
    end
    return model
end
return extend_observed_context_model
