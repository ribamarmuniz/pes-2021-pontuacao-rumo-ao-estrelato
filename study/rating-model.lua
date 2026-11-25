-- Reference factory. The installed module embeds this factory before use.
-- A caller supplies float32 rounding. No game memory is written here.
local function create_rating_model(F)
    local model={}
    local function A(a,b)return F(F(a)+F(b))end
    local function S(a,b)return F(F(a)-F(b))end
    local function M(a,b)return F(F(a)*F(b))end
    local function D(a,b)return F(F(a)/F(b))end
    local function clamp(v,a,b)return math.max(a,math.min(b,v))end
    local function trunc(v)return v<0 and math.ceil(v) or math.floor(v)end
    local ids={
        [36]=0,[37]=1,[38]=2,[39]=3,[40]=4,[41]=6,[42]=12,[43]=17,
        [44]=21,[45]=22,[46]=23,[47]=24,[48]=25,[49]=26,[50]=27,
        [51]=28,[52]=29,[53]=30,[54]=31,[55]=78,[56]=49,[57]=50,
        [58]=51,[59]=52,[60]=54,[61]=55,[62]=56,[63]=61,[64]=62,
        [65]=63,[66]=57,[67]=58,[68]=67,[69]=65,[70]=66,[71]=131,
        [72]=132,[73]=133,[74]=134,[75]=77,[76]=78,[78]=86,[79]=87,
        [80]=89,[82]=94,
    }
    local profile={[0]=4,[1]=3,[2]=3,[3]=2,[4]=2,[5]=2,[6]=2,[7]=1,[8]=1,[9]=1}
    model.profile=profile
    function model.raw(program,p,x)
        if not program then return end
        local function resolve(id)
            if ids[id] then return p.s[ids[id]+1] end
            if id==77 then return p.s[85]+p.s[86] end
            if id==81 then return p.s[91]+p.s[92]+p.s[93]+p.s[94] end
            if id>=88 and id<=91 then return p.u[id-87] end
            if id==83 then return p.t[p.v[1]+1] end
            if id==84 then return p.t[2-p.v[1]] end
            if id==85 then return x.score[p.v[1]+1]>x.score[2-p.v[1]] and 1 or 0 end
            if id==86 then return x.score[p.v[1]+1]<x.score[2-p.v[1]] and 1 or 0 end
            if id==87 then return x.score[1]==x.score[2] and 1 or 0 end
        end
        local function eval(i)
            local n=program[i]
            if not n then return end
            if n.t==4 then return n.value end
            if n.t==5 then
                local callee=program[n.a]
                if not callee or n.b~=4294967295 then return end
                local v=resolve(callee.a)
                return v and F(v) or nil
            end
            if n.a>=i or n.b>=i then return end
            local a,b=eval(n.a),eval(n.b)
            if not a or not b then return end
            if n.t==0 then return A(a,b) end
            if n.t==1 then return S(a,b) end
            if n.t==2 then return M(a,b) end
            if n.t==3 and b~=0 then return D(a,b) end
        end
        return eval(program.count-1)
    end
    function model.normalize(x)
        local function c(off)return F(x.constants[off/4+1])end
        local p,density,n=x.players,{},0
        local initial,sum=0,0
        for i,q in ipairs(p) do
            local dur=q.v[5]-q.v[4]
            density[i]=dur>0 and D(q.v[7],math.max(45,dur)) or 0
            if dur>0 then n=n+1 end
            if q.v[1]==0 and q.v[2]==0 then initial=density[i] end
            sum=A(sum,density[i])
        end
        if n==0 then return end
        local lo,hi=initial,initial
        for _,v in ipairs(density) do lo=math.min(lo,v);hi=math.max(hi,v) end
        local mean=D(sum,n)
        local mean01=mean<=lo and 0 or mean>=hi and 1 or D(S(mean,lo),S(hi,lo))
        local range=S(hi,lo)
        hi=S(hi,M(range,.15));lo=S(lo,M(range,.1))
        local t=clamp(S(mean01,.1),F(.3),F(.7))
        local mid=A(M(S(hi,lo),t),lo)
        local scorer,maxGoals={[0]=0,[1]=0},{[0]=0,[1]=0}
        for _,q in ipairs(p) do
            if q.s[1]>0 then
                local team=q.v[1]
                scorer[team]=scorer[team]+1
                maxGoals[team]=math.max(maxGoals[team],q.s[1])
            end
        end
        local scale=math.max(1,D(trunc(x.duration),10))
        local result={}
        for i,q in ipairs(p) do
            local v,s=q.v,q.s
            local dur=v[5]-v[4]
            local part=dur<=5 and 0 or dur>=45 and 1 or D(S(dur,5),40)
            local r=density[i]
            if r>mid then r=M(clamp(r>=hi and 1 or D(S(r,mid),S(hi,mid)),0,1),.5)
            else r=M(clamp(r<=lo and 0 or r>=mid and 1 or D(S(r,lo),S(mid,lo)),0,1),-.5) end
            local normalized=A(M(A(M(part,.5),.5),r),.5)
            local base=M(S(c(0x38),c(0x40)),normalized)
            base=D(trunc(M(A(A(M(trunc(A(base,base)),.5),c(0x40)),.05),10)),10)
            base=clamp(base,c(0x40),c(0x38))
            local note,bonus=base,0
            if s[1]>0 then
                if s[1]>=trunc(M(scale,6)) then bonus=c(0x20)
                elseif s[1]>=trunc(M(scale,3)) then bonus=c(0x1c)
                elseif scorer[v[1]]>=2 and s[1]>=2 and s[1]>=maxGoals[v[1]] then bonus=c(0x10)
                elseif s[1]>=trunc(A(scale,scale)) then bonus=c(0x18) end
            end
            if bonus~=0 then note=A(note,bonus) end
            if s[5]>=trunc(A(scale,scale)) or s[5]>=trunc(M(scale,3)) then
                note=A(note,c(8));bonus=1
            elseif bonus==0 and (s[1]>0 or s[5]>0) then note=A(note,c(0x14));bonus=1 end
            local gk=0
            if s[134]>0 and s[133]>0 and s[133]>=trunc(M(scale,4)) then
                local ratio=D(s[134],s[133])
                local own,enemy=x.score[v[1]+1],x.score[2-v[1]]
                if own>=enemy and enemy<=trunc(scale) and ratio>.5 then gk=c(0x28)
                elseif enemy>0 and enemy>=trunc(M(scale,3)) and ratio<F(.3) then gk=c(0x24) end
            end
            if gk~=0 then note=A(note,gk)
            elseif bonus==0 then
                local threshold=v[6]>7 and v[6]<=12 and .3 or .2
                if s[25]>0 and D(s[96],s[25])>F(threshold) then note=A(note,c(0x30)) end
                threshold=v[6]>=5 and v[6]<=12 and .3 or .2
                local lost=s[91]+s[92]+s[93]+s[94]
                if s[66]>0 and D(lost,s[66])>F(threshold) then note=A(note,c(0x2c)) end
            end
            if v[10]>0 and v[11]>0 then
                local ratio=D(v[11],v[10])
                local off=ratio>=1 and 0x268 or ratio>=F(.9) and 0x28c or ratio>=F(.8) and 0x288
                    or ratio>=F(.7) and 0x284 or ratio>=F(.6) and 0x280 or ratio>=.5 and 0x27c
                    or ratio>=F(.4) and 0x278 or ratio>=F(.3) and 0x274 or ratio>=F(.2) and 0x270
                    or ratio>=F(.1) and 0x26c or 0
                if off~=0 and c(off)>0 then note=S(note,c(off)) end
            end
            note=clamp(note,c(0x264),c(0x260))
            if dur<5 then note=0 end
            result[i]=note
        end
        return result
    end
    function model.label(a,b)
        local groups,n={},0
        local function add(name)if not groups[name] then groups[name]=true;n=n+1 end end
        local function changed(ids)for _,id in ipairs(ids) do if b.s[id+1]>a.s[id+1] then return true end end end
        if changed({1}) then add("Gol contra") end
        if changed({0,2,3}) then add("Gol") end
        if changed({4}) then add("Assistencia") end
        if changed({6,17,21}) or b.u[2]>a.u[2] or b.u[3]>a.u[3] or b.u[4]>a.u[4] then add("Finalizacao") end
        if changed({22,23,24,25,26,27,28,29,30,31}) then add("Passe") end
        if changed({49,50}) then add("Desarme") end
        if changed({65,66}) or b.u[1]>a.u[1] then add("Drible") end
        if changed({77,78,84,85,86,87}) then add("Recuperacao") end
        if changed({89,90,91,92,93,94,95}) then add("Perda") end
        if changed({55}) then add("Falta") end
        if changed({58}) then add("Cartao vermelho") elseif changed({57}) then add("Cartao amarelo") end
        if (groups.Gol or groups["Gol contra"]) and groups.Finalizacao then groups.Finalizacao=nil;n=n-1 end
        if n==1 then for name in pairs(groups) do return name end end
        if n==0 then return changed({67}) and "Toques de bola" or "Dados individuais" end
        return "Acoes combinadas"
    end
    function model.same(a,b)
        if not a or not b or #a~=#b then return false end
        for i=1,#a do if a[i]~=b[i] then return false end end
        return true
    end
    function model.path(programs,before,after,groups,id)
        if not before or before.match~=after.match then return end
        local a,b,index
        for _,p in ipairs(before.players) do if p.v[3]==id then a=p end end
        for i,p in ipairs(after.players) do if p.v[3]==id then b=p;index=i end end
        if not a or not b or a.v[8]<=0 or b.a~=1 or a.v[1]~=b.v[1] or a.v[2]~=b.v[2]
            or a.v[4]~=b.v[4] or b.v[5]<a.v[5] then return end
        local program=programs[profile[b.v[12]]]
        if not program then return end
        local s,u=a.s,a.u
        local trial={players={},constants=after.constants,score=after.score,duration=after.duration}
        for i,p in ipairs(after.players) do trial.players[i]=p end
        local altered={v={},s=s,u=u,t=b.t,a=b.a}
        for i,v in ipairs(b.v) do altered.v[i]=v end
        trial.players[index]=altered
        local function note(stats,unique)
            altered.s,altered.u=stats,unique
            local raw=model.raw(program,altered,trial)
            if raw==nil then return end
            altered.v[7]=raw
            local values=model.normalize(trial)
            return values and values[index]
        end
        local previous=note(s,u)
        if not previous then return end
        local components,state_notes,sum={},{previous},0
        for _,g in ipairs(groups) do
            if not model.same(s,g.before_s) or not model.same(u,g.before_u) then return end
            for i,v in ipairs(g.after_s) do if v<s[i] then return end end
            for i,v in ipairs(g.after_u) do if v<u[i] then return end end
            local next_note=note(g.after_s,g.after_u)
            if not next_note then return end
            local effect=S(next_note,previous)
            if effect~=0 then components[#components+1]={label=g.label or model.label({s=s,u=u},{s=g.after_s,u=g.after_u}),effect=effect} end
            sum=A(sum,effect);previous=next_note;s=g.after_s;u=g.after_u
            state_notes[#state_notes+1]=next_note
        end
        if not model.same(s,b.s) or not model.same(u,b.u) or previous~=b.v[8] then return end
        local total=S(b.v[8],a.v[8])
        local remaining=S(total,sum)
        if A(sum,remaining)~=total then return end
        return {from=a.v[8],to=b.v[8],total=total,components=components,
            playerEffect=sum,remainingEffect=remaining,stateNotes=state_notes,historicalActionAttribution=false}
    end
    return model
end
return create_rating_model
