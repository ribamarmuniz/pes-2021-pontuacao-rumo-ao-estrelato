-- Painel 0.13: F6 mostra/oculta; F8 alterna o historico.
-- FPS mede chamadas display_frame em intervalos de 0.5 s usando o QPC.
local m = { version = "0.13" }
-- BEGIN embedded rating model
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
-- END embedded rating model
-- BEGIN embedded native path selftest
-- Synthetic fixture. Expected values produced by the original PES machine code in a separate process.
local function run_rating_selftest(model)
local before={["match"]="synthetic-path-test",["duration"]=10,["score"]={0,0},["constants"]={0,0,0.5,1,0.5,0.5,0.5,1.5,2,-0.5,0.5,-0.5,-0.5,45,7,6,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,4,2,0,0.5,1,1.5,2,2,2,2,2,0,0},["players"]={{["a"]=1,["v"]={0,0,2147483834,0,30,12,8,6,6,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={0,0}},{["a"]=1,["v"]={0,1,2,0,30,12,6.600000381469727,6,6,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={0,0}},{["a"]=1,["v"]={1,0,3,0,30,12,17.5,6.5,6.5,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={0,0}},{["a"]=1,["v"]={1,1,4,0,30,12,2.9000000953674316,5.5,5.5,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={0,0}}}}
local after={["match"]="synthetic-path-test",["duration"]=10,["score"]={1,0},["constants"]={0,0,0.5,1,0.5,0.5,0.5,1.5,2,-0.5,0.5,-0.5,-0.5,45,7,6,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,4,2,0,0.5,1,1.5,2,2,2,2,2,0,0},["players"]={{["a"]=1,["v"]={0,0,2147483834,0,30,12,131.60000610351562,7,7,100,0,9},["s"]={1,0,0,0,0,0,2,0,0,0,0,0,1,0,0,0,0,2,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,1,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,2,0,0},["t"]={1,0}},{["a"]=1,["v"]={0,1,2,0,30,12,36.599998474121094,6,6,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0}},{["a"]=1,["v"]={1,0,3,0,30,12,17.5,5,5,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0}},{["a"]=1,["v"]={1,1,4,0,30,12,2.9000000953674316,5.5,5.5,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0}}}}
local groups={{["before_s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["before_u"]={0,0,0,0},["after_s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["after_u"]={0,0,0,0}},{["before_s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["before_u"]={0,0,0,0},["after_s"]={0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["after_u"]={0,1,0,0}},{["before_s"]={0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["before_u"]={0,1,0,0},["after_s"]={1,0,0,0,0,0,2,0,0,0,0,0,1,0,0,0,0,2,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["after_u"]={0,2,0,0}},{["before_s"]={1,0,0,0,0,0,2,0,0,0,0,0,1,0,0,0,0,2,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["before_u"]={0,2,0,0},["after_s"]={1,0,0,0,0,0,2,0,0,0,0,0,1,0,0,0,0,2,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,1,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["after_u"]={0,2,0,0}}}
local expected={["from"]=6,["to"]=7,["total"]=1,["playerEffect"]=0.5,["remainingEffect"]=0.5,["stateNotes"]={6.5,6.5,6.5,7,7},["components"]={{["label"]="Gol",["effect"]=0.5}}}
local program={[0]={["t"]=4,["a"]=1060320051,["b"]=0,["value"]=0.699999988079071},[1]={["t"]=7,["a"]=68,["b"]=0,["value"]=0},[2]={["t"]=5,["a"]=1,["b"]=4294967295,["value"]=0},[3]={["t"]=2,["a"]=0,["b"]=2,["value"]=0},[4]={["t"]=4,["a"]=1084227584,["b"]=0,["value"]=5},[5]={["t"]=7,["a"]=89,["b"]=0,["value"]=0},[6]={["t"]=5,["a"]=5,["b"]=4294967295,["value"]=0},[7]={["t"]=2,["a"]=4,["b"]=6,["value"]=0},[8]={["t"]=0,["a"]=3,["b"]=7,["value"]=0},[9]={["t"]=4,["a"]=1082130432,["b"]=0,["value"]=4},[10]={["t"]=7,["a"]=90,["b"]=0,["value"]=0},[11]={["t"]=5,["a"]=10,["b"]=4294967295,["value"]=0},[12]={["t"]=2,["a"]=9,["b"]=11,["value"]=0},[13]={["t"]=0,["a"]=8,["b"]=12,["value"]=0},[14]={["t"]=4,["a"]=1073741824,["b"]=0,["value"]=2},[15]={["t"]=7,["a"]=91,["b"]=0,["value"]=0},[16]={["t"]=5,["a"]=15,["b"]=4294967295,["value"]=0},[17]={["t"]=2,["a"]=14,["b"]=16,["value"]=0},[18]={["t"]=0,["a"]=13,["b"]=17,["value"]=0},[19]={["t"]=4,["a"]=1077936128,["b"]=0,["value"]=3},[20]={["t"]=7,["a"]=43,["b"]=0,["value"]=0},[21]={["t"]=5,["a"]=20,["b"]=4294967295,["value"]=0},[22]={["t"]=2,["a"]=19,["b"]=21,["value"]=0},[23]={["t"]=0,["a"]=18,["b"]=22,["value"]=0},[24]={["t"]=4,["a"]=1117126656,["b"]=0,["value"]=75},[25]={["t"]=7,["a"]=36,["b"]=0,["value"]=0},[26]={["t"]=5,["a"]=25,["b"]=4294967295,["value"]=0},[27]={["t"]=2,["a"]=24,["b"]=26,["value"]=0},[28]={["t"]=0,["a"]=23,["b"]=27,["value"]=0},[29]={["t"]=4,["a"]=1099956224,["b"]=0,["value"]=18},[30]={["t"]=7,["a"]=39,["b"]=0,["value"]=0},[31]={["t"]=5,["a"]=30,["b"]=4294967295,["value"]=0},[32]={["t"]=2,["a"]=29,["b"]=31,["value"]=0},[33]={["t"]=1,["a"]=28,["b"]=32,["value"]=0},[34]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[35]={["t"]=7,["a"]=38,["b"]=0,["value"]=0},[36]={["t"]=5,["a"]=35,["b"]=4294967295,["value"]=0},[37]={["t"]=2,["a"]=34,["b"]=36,["value"]=0},[38]={["t"]=1,["a"]=33,["b"]=37,["value"]=0},[39]={["t"]=4,["a"]=1109393408,["b"]=0,["value"]=40},[40]={["t"]=7,["a"]=37,["b"]=0,["value"]=0},[41]={["t"]=5,["a"]=40,["b"]=4294967295,["value"]=0},[42]={["t"]=2,["a"]=39,["b"]=41,["value"]=0},[43]={["t"]=1,["a"]=38,["b"]=42,["value"]=0},[44]={["t"]=4,["a"]=1109393408,["b"]=0,["value"]=40},[45]={["t"]=7,["a"]=40,["b"]=0,["value"]=0},[46]={["t"]=5,["a"]=45,["b"]=4294967295,["value"]=0},[47]={["t"]=2,["a"]=44,["b"]=46,["value"]=0},[48]={["t"]=0,["a"]=43,["b"]=47,["value"]=0},[49]={["t"]=4,["a"]=1069547520,["b"]=0,["value"]=1.5},[50]={["t"]=7,["a"]=48,["b"]=0,["value"]=0},[51]={["t"]=5,["a"]=50,["b"]=4294967295,["value"]=0},[52]={["t"]=2,["a"]=49,["b"]=51,["value"]=0},[53]={["t"]=0,["a"]=48,["b"]=52,["value"]=0},[54]={["t"]=4,["a"]=1077936128,["b"]=0,["value"]=3},[55]={["t"]=7,["a"]=50,["b"]=0,["value"]=0},[56]={["t"]=5,["a"]=55,["b"]=4294967295,["value"]=0},[57]={["t"]=2,["a"]=54,["b"]=56,["value"]=0},[58]={["t"]=0,["a"]=53,["b"]=57,["value"]=0},[59]={["t"]=4,["a"]=1084227584,["b"]=0,["value"]=5},[60]={["t"]=7,["a"]=52,["b"]=0,["value"]=0},[61]={["t"]=5,["a"]=60,["b"]=4294967295,["value"]=0},[62]={["t"]=2,["a"]=59,["b"]=61,["value"]=0},[63]={["t"]=0,["a"]=58,["b"]=62,["value"]=0},[64]={["t"]=4,["a"]=1088421888,["b"]=0,["value"]=7},[65]={["t"]=7,["a"]=54,["b"]=0,["value"]=0},[66]={["t"]=5,["a"]=65,["b"]=4294967295,["value"]=0},[67]={["t"]=2,["a"]=64,["b"]=66,["value"]=0},[68]={["t"]=0,["a"]=63,["b"]=67,["value"]=0},[69]={["t"]=4,["a"]=1082130432,["b"]=0,["value"]=4},[70]={["t"]=7,["a"]=47,["b"]=0,["value"]=0},[71]={["t"]=5,["a"]=70,["b"]=4294967295,["value"]=0},[72]={["t"]=7,["a"]=48,["b"]=0,["value"]=0},[73]={["t"]=5,["a"]=72,["b"]=4294967295,["value"]=0},[74]={["t"]=1,["a"]=71,["b"]=73,["value"]=0},[75]={["t"]=2,["a"]=69,["b"]=74,["value"]=0},[76]={["t"]=1,["a"]=68,["b"]=75,["value"]=0},[77]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[78]={["t"]=7,["a"]=57,["b"]=0,["value"]=0},[79]={["t"]=5,["a"]=78,["b"]=4294967295,["value"]=0},[80]={["t"]=2,["a"]=77,["b"]=79,["value"]=0},[81]={["t"]=0,["a"]=76,["b"]=80,["value"]=0},[82]={["t"]=4,["a"]=1077936128,["b"]=0,["value"]=3},[83]={["t"]=7,["a"]=58,["b"]=0,["value"]=0},[84]={["t"]=5,["a"]=83,["b"]=4294967295,["value"]=0},[85]={["t"]=2,["a"]=82,["b"]=84,["value"]=0},[86]={["t"]=0,["a"]=81,["b"]=85,["value"]=0},[87]={["t"]=4,["a"]=1077936128,["b"]=0,["value"]=3},[88]={["t"]=7,["a"]=59,["b"]=0,["value"]=0},[89]={["t"]=5,["a"]=88,["b"]=4294967295,["value"]=0},[90]={["t"]=2,["a"]=87,["b"]=89,["value"]=0},[91]={["t"]=0,["a"]=86,["b"]=90,["value"]=0},[92]={["t"]=4,["a"]=1082130432,["b"]=0,["value"]=4},[93]={["t"]=7,["a"]=60,["b"]=0,["value"]=0},[94]={["t"]=5,["a"]=93,["b"]=4294967295,["value"]=0},[95]={["t"]=2,["a"]=92,["b"]=94,["value"]=0},[96]={["t"]=0,["a"]=91,["b"]=95,["value"]=0},[97]={["t"]=4,["a"]=0,["b"]=0,["value"]=0},[98]={["t"]=7,["a"]=61,["b"]=0,["value"]=0},[99]={["t"]=5,["a"]=98,["b"]=4294967295,["value"]=0},[100]={["t"]=7,["a"]=62,["b"]=0,["value"]=0},[101]={["t"]=5,["a"]=100,["b"]=4294967295,["value"]=0},[102]={["t"]=1,["a"]=99,["b"]=101,["value"]=0},[103]={["t"]=2,["a"]=97,["b"]=102,["value"]=0},[104]={["t"]=1,["a"]=96,["b"]=103,["value"]=0},[105]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[106]={["t"]=7,["a"]=66,["b"]=0,["value"]=0},[107]={["t"]=5,["a"]=106,["b"]=4294967295,["value"]=0},[108]={["t"]=2,["a"]=105,["b"]=107,["value"]=0},[109]={["t"]=1,["a"]=104,["b"]=108,["value"]=0},[110]={["t"]=4,["a"]=1112014848,["b"]=0,["value"]=50},[111]={["t"]=7,["a"]=67,["b"]=0,["value"]=0},[112]={["t"]=5,["a"]=111,["b"]=4294967295,["value"]=0},[113]={["t"]=2,["a"]=110,["b"]=112,["value"]=0},[114]={["t"]=1,["a"]=109,["b"]=113,["value"]=0},[115]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[116]={["t"]=7,["a"]=76,["b"]=0,["value"]=0},[117]={["t"]=5,["a"]=116,["b"]=4294967295,["value"]=0},[118]={["t"]=2,["a"]=115,["b"]=117,["value"]=0},[119]={["t"]=0,["a"]=114,["b"]=118,["value"]=0},[120]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[121]={["t"]=7,["a"]=77,["b"]=0,["value"]=0},[122]={["t"]=5,["a"]=121,["b"]=4294967295,["value"]=0},[123]={["t"]=2,["a"]=120,["b"]=122,["value"]=0},[124]={["t"]=0,["a"]=119,["b"]=123,["value"]=0},[125]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[126]={["t"]=7,["a"]=78,["b"]=0,["value"]=0},[127]={["t"]=5,["a"]=126,["b"]=4294967295,["value"]=0},[128]={["t"]=2,["a"]=125,["b"]=127,["value"]=0},[129]={["t"]=0,["a"]=124,["b"]=128,["value"]=0},[130]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[131]={["t"]=7,["a"]=79,["b"]=0,["value"]=0},[132]={["t"]=5,["a"]=131,["b"]=4294967295,["value"]=0},[133]={["t"]=2,["a"]=130,["b"]=132,["value"]=0},[134]={["t"]=0,["a"]=129,["b"]=133,["value"]=0},[135]={["t"]=4,["a"]=1065353216,["b"]=0,["value"]=1},[136]={["t"]=7,["a"]=81,["b"]=0,["value"]=0},[137]={["t"]=5,["a"]=136,["b"]=4294967295,["value"]=0},[138]={["t"]=2,["a"]=135,["b"]=137,["value"]=0},[139]={["t"]=1,["a"]=134,["b"]=138,["value"]=0},[140]={["t"]=4,["a"]=1065353216,["b"]=0,["value"]=1},[141]={["t"]=7,["a"]=82,["b"]=0,["value"]=0},[142]={["t"]=5,["a"]=141,["b"]=4294967295,["value"]=0},[143]={["t"]=2,["a"]=140,["b"]=142,["value"]=0},[144]={["t"]=1,["a"]=139,["b"]=143,["value"]=0},[145]={["t"]=4,["a"]=1090519040,["b"]=0,["value"]=8},[146]={["t"]=7,["a"]=88,["b"]=0,["value"]=0},[147]={["t"]=5,["a"]=146,["b"]=4294967295,["value"]=0},[148]={["t"]=2,["a"]=145,["b"]=147,["value"]=0},[149]={["t"]=0,["a"]=144,["b"]=148,["value"]=0},[150]={["t"]=4,["a"]=1101004800,["b"]=0,["value"]=20},[151]={["t"]=7,["a"]=83,["b"]=0,["value"]=0},[152]={["t"]=5,["a"]=151,["b"]=4294967295,["value"]=0},[153]={["t"]=2,["a"]=150,["b"]=152,["value"]=0},[154]={["t"]=0,["a"]=149,["b"]=153,["value"]=0},[155]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[156]={["t"]=7,["a"]=85,["b"]=0,["value"]=0},[157]={["t"]=5,["a"]=156,["b"]=4294967295,["value"]=0},[158]={["t"]=2,["a"]=155,["b"]=157,["value"]=0},[159]={["t"]=0,["a"]=154,["b"]=158,["value"]=0},["count"]=160}
local result=model.path({program},before,after,groups,2147483834)
if not result or not model.same(result.stateNotes,expected.stateNotes) then return false end
for _,key in ipairs({"from","to","total","playerEffect","remainingEffect"}) do if result[key]~=expected[key] then return false end end
if #result.components~=#expected.components then return false end
for i,p in ipairs(result.components) do if p.label~=expected.components[i].label or p.effect~=expected.components[i].effect then return false end end
return true,{before=before,after=after,groups=groups,expected=expected,programs={program}}
end
-- END embedded native path selftest
-- BEGIN embedded observed context
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
-- Synthetic inputs and expected notes verified with the original native normalizer.
local function run_observed_context_selftest(model)
local before={["schema"]=6,["match"]="synthetic-observed-context",["duration"]=10,["score"]={0,0},["constants"]={0,0,0.5,1,0.5,0.5,0.5,1.5,2,-0.5,0.5,-0.5,-0.5,45,7,6,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,4,2,0,0.5,1,1.5,2,2,2,2,2,0,0},["players"]={{["a"]=1,["v"]={0,0,2147483834,0,30,12,8,6,6,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={0,0},["nativeRaw"]=0},{["a"]=1,["v"]={0,1,2,0,30,12,6.600000381469727,6,6,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={0,0},["nativeRaw"]=0},{["a"]=1,["v"]={1,0,3,0,30,12,17.5,6.5,6.5,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={0,0},["nativeRaw"]=0},{["a"]=1,["v"]={1,1,4,0,30,12,2.9000000953674316,5.5,5.5,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={0,0},["nativeRaw"]=0}}}
local after={["schema"]=6,["match"]="synthetic-observed-context",["duration"]=10,["score"]={1,0},["constants"]={0,0,0.5,1,0.5,0.5,0.5,1.5,2,-0.5,0.5,-0.5,-0.5,45,7,6,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,4,2,0,0.5,1,1.5,2,2,2,2,2,0,0},["players"]={{["a"]=1,["v"]={0,0,2147483834,0,30,12,131.60000610351562,7,7,100,0,9},["s"]={1,0,0,0,0,0,2,0,0,0,0,0,1,0,0,0,0,2,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,1,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,2,0,0},["t"]={1,0},["nativeRaw"]=8},{["a"]=1,["v"]={0,1,2,0,30,12,36.599998474121094,6,6,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=6.600000381469727},{["a"]=1,["v"]={1,0,3,0,30,12,17.5,5,5,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=17.5},{["a"]=1,["v"]={1,1,4,0,30,12,2.9000000953674316,5.5,5.5,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=2.9000000953674316}}}
local groups={{["sequence"]=1,["valid"]=true,["before"]={["schema"]=6,["match"]="synthetic-observed-context",["duration"]=10,["score"]={1,0},["constants"]={0,0,0.5,1,0.5,0.5,0.5,1.5,2,-0.5,0.5,-0.5,-0.5,45,7,6,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,4,2,0,0.5,1,1.5,2,2,2,2,2,0,0},["players"]={{["a"]=1,["v"]={0,0,2147483834,0,30,12,38,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=8},{["a"]=1,["v"]={0,1,2,0,30,12,36.599998474121094,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=6.600000381469727},{["a"]=1,["v"]={1,0,3,0,30,12,17.5,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=17.5},{["a"]=1,["v"]={1,1,4,0,30,12,2.9000000953674316,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=2.9000000953674316}}},["after"]={["schema"]=6,["match"]="synthetic-observed-context",["duration"]=10,["score"]={1,0},["constants"]={0,0,0.5,1,0.5,0.5,0.5,1.5,2,-0.5,0.5,-0.5,-0.5,45,7,6,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,4,2,0,0.5,1,1.5,2,2,2,2,2,0,0},["players"]={{["a"]=1,["v"]={0,0,2147483834,0,30,12,40.20000076293945,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=8},{["a"]=1,["v"]={0,1,2,0,30,12,36.599998474121094,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=6.600000381469727},{["a"]=1,["v"]={1,0,3,0,30,12,17.5,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=17.5},{["a"]=1,["v"]={1,1,4,0,30,12,2.9000000953674316,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=2.9000000953674316}}},["beforeNote"]=6.5,["afterNote"]=6.5,["contextUpdate"]=false},{["sequence"]=2,["valid"]=true,["before"]={["schema"]=6,["match"]="synthetic-observed-context",["duration"]=10,["score"]={1,0},["constants"]={0,0,0.5,1,0.5,0.5,0.5,1.5,2,-0.5,0.5,-0.5,-0.5,45,7,6,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,4,2,0,0.5,1,1.5,2,2,2,2,2,0,0},["players"]={{["a"]=1,["v"]={0,0,2147483834,0,30,12,40.20000076293945,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=8},{["a"]=1,["v"]={0,1,2,0,30,12,36.599998474121094,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=6.600000381469727},{["a"]=1,["v"]={1,0,3,0,30,12,17.5,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=17.5},{["a"]=1,["v"]={1,1,4,0,30,12,2.9000000953674316,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=2.9000000953674316}}},["after"]={["schema"]=6,["match"]="synthetic-observed-context",["duration"]=10,["score"]={1,0},["constants"]={0,0,0.5,1,0.5,0.5,0.5,1.5,2,-0.5,0.5,-0.5,-0.5,45,7,6,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,4,2,0,0.5,1,1.5,2,2,2,2,2,0,0},["players"]={{["a"]=1,["v"]={0,0,2147483834,0,30,12,48.900001525878906,0,0,100,0,9},["s"]={0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,1,0,0},["t"]={1,0},["nativeRaw"]=8},{["a"]=1,["v"]={0,1,2,0,30,12,36.599998474121094,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=6.600000381469727},{["a"]=1,["v"]={1,0,3,0,30,12,17.5,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=17.5},{["a"]=1,["v"]={1,1,4,0,30,12,2.9000000953674316,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=2.9000000953674316}}},["beforeNote"]=6.5,["afterNote"]=6.5,["contextUpdate"]=false},{["sequence"]=3,["valid"]=true,["before"]={["schema"]=6,["match"]="synthetic-observed-context",["duration"]=10,["score"]={1,0},["constants"]={0,0,0.5,1,0.5,0.5,0.5,1.5,2,-0.5,0.5,-0.5,-0.5,45,7,6,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,4,2,0,0.5,1,1.5,2,2,2,2,2,0,0},["players"]={{["a"]=1,["v"]={0,0,2147483834,0,30,12,48.900001525878906,0,0,100,0,9},["s"]={0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,1,0,0},["t"]={1,0},["nativeRaw"]=8},{["a"]=1,["v"]={0,1,2,0,30,12,36.599998474121094,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=6.600000381469727},{["a"]=1,["v"]={1,0,3,0,30,12,17.5,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=17.5},{["a"]=1,["v"]={1,1,4,0,30,12,2.9000000953674316,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=2.9000000953674316}}},["after"]={["schema"]=6,["match"]="synthetic-observed-context",["duration"]=10,["score"]={1,0},["constants"]={0,0,0.5,1,0.5,0.5,0.5,1.5,2,-0.5,0.5,-0.5,-0.5,45,7,6,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,4,2,0,0.5,1,1.5,2,2,2,2,2,0,0},["players"]={{["a"]=1,["v"]={0,0,2147483834,0,30,12,131.89999389648438,0,0,100,0,9},["s"]={1,0,0,0,0,0,2,0,0,0,0,0,1,0,0,0,0,2,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,2,0,0},["t"]={1,0},["nativeRaw"]=8},{["a"]=1,["v"]={0,1,2,0,30,12,36.599998474121094,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=6.600000381469727},{["a"]=1,["v"]={1,0,3,0,30,12,17.5,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=17.5},{["a"]=1,["v"]={1,1,4,0,30,12,2.9000000953674316,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=2.9000000953674316}}},["beforeNote"]=6.5,["afterNote"]=7,["contextUpdate"]=false},{["sequence"]=4,["valid"]=true,["before"]={["schema"]=6,["match"]="synthetic-observed-context",["duration"]=10,["score"]={1,0},["constants"]={0,0,0.5,1,0.5,0.5,0.5,1.5,2,-0.5,0.5,-0.5,-0.5,45,7,6,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,4,2,0,0.5,1,1.5,2,2,2,2,2,0,0},["players"]={{["a"]=1,["v"]={0,0,2147483834,0,30,12,131.89999389648438,0,0,100,0,9},["s"]={1,0,0,0,0,0,2,0,0,0,0,0,1,0,0,0,0,2,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,2,0,0},["t"]={1,0},["nativeRaw"]=8},{["a"]=1,["v"]={0,1,2,0,30,12,36.599998474121094,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=6.600000381469727},{["a"]=1,["v"]={1,0,3,0,30,12,17.5,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=17.5},{["a"]=1,["v"]={1,1,4,0,30,12,2.9000000953674316,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=2.9000000953674316}}},["after"]={["schema"]=6,["match"]="synthetic-observed-context",["duration"]=10,["score"]={1,0},["constants"]={0,0,0.5,1,0.5,0.5,0.5,1.5,2,-0.5,0.5,-0.5,-0.5,45,7,6,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,4,2,0,0.5,1,1.5,2,2,2,2,2,0,0},["players"]={{["a"]=1,["v"]={0,0,2147483834,0,30,12,131.60000610351562,0,0,100,0,9},["s"]={1,0,0,0,0,0,2,0,0,0,0,0,1,0,0,0,0,2,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,1,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,2,0,0},["t"]={1,0},["nativeRaw"]=8},{["a"]=1,["v"]={0,1,2,0,30,12,36.599998474121094,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=6.600000381469727},{["a"]=1,["v"]={1,0,3,0,30,12,17.5,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=17.5},{["a"]=1,["v"]={1,1,4,0,30,12,2.9000000953674316,0,0,100,0,9},["s"]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},["u"]={0,0,0,0},["t"]={1,0},["nativeRaw"]=2.9000000953674316}}},["beforeNote"]=7,["afterNote"]=7,["contextUpdate"]=false}}
local expected={["from"]=6,["to"]=7,["total"]=1,["components"]={{["label"]="Placar",["effect"]=0.5,["source"]="context",["sequence"]=1},{["label"]="Gol",["effect"]=0.5,["source"]="event",["sequence"]=3}},["eventEffect"]=0.5,["contextEffect"]=0.5,["playerEffect"]=0.5,["remainingEffect"]=0.5,["stateNotes"]={6,6.5,6.5,6.5,6.5,6.5,7,7,7,7},["definition"]="native-event-marginals-at-observed-context",["historicalActionAttribution"]=false,["physicalActionValidated"]=false}
local programs={{[0]={["t"]=4,["a"]=1060320051,["b"]=0,["value"]=0.699999988079071},[1]={["t"]=7,["a"]=68,["b"]=0,["value"]=0},[2]={["t"]=5,["a"]=1,["b"]=4294967295,["value"]=0},[3]={["t"]=2,["a"]=0,["b"]=2,["value"]=0},[4]={["t"]=4,["a"]=1084227584,["b"]=0,["value"]=5},[5]={["t"]=7,["a"]=89,["b"]=0,["value"]=0},[6]={["t"]=5,["a"]=5,["b"]=4294967295,["value"]=0},[7]={["t"]=2,["a"]=4,["b"]=6,["value"]=0},[8]={["t"]=0,["a"]=3,["b"]=7,["value"]=0},[9]={["t"]=4,["a"]=1082130432,["b"]=0,["value"]=4},[10]={["t"]=7,["a"]=90,["b"]=0,["value"]=0},[11]={["t"]=5,["a"]=10,["b"]=4294967295,["value"]=0},[12]={["t"]=2,["a"]=9,["b"]=11,["value"]=0},[13]={["t"]=0,["a"]=8,["b"]=12,["value"]=0},[14]={["t"]=4,["a"]=1073741824,["b"]=0,["value"]=2},[15]={["t"]=7,["a"]=91,["b"]=0,["value"]=0},[16]={["t"]=5,["a"]=15,["b"]=4294967295,["value"]=0},[17]={["t"]=2,["a"]=14,["b"]=16,["value"]=0},[18]={["t"]=0,["a"]=13,["b"]=17,["value"]=0},[19]={["t"]=4,["a"]=1077936128,["b"]=0,["value"]=3},[20]={["t"]=7,["a"]=43,["b"]=0,["value"]=0},[21]={["t"]=5,["a"]=20,["b"]=4294967295,["value"]=0},[22]={["t"]=2,["a"]=19,["b"]=21,["value"]=0},[23]={["t"]=0,["a"]=18,["b"]=22,["value"]=0},[24]={["t"]=4,["a"]=1117126656,["b"]=0,["value"]=75},[25]={["t"]=7,["a"]=36,["b"]=0,["value"]=0},[26]={["t"]=5,["a"]=25,["b"]=4294967295,["value"]=0},[27]={["t"]=2,["a"]=24,["b"]=26,["value"]=0},[28]={["t"]=0,["a"]=23,["b"]=27,["value"]=0},[29]={["t"]=4,["a"]=1099956224,["b"]=0,["value"]=18},[30]={["t"]=7,["a"]=39,["b"]=0,["value"]=0},[31]={["t"]=5,["a"]=30,["b"]=4294967295,["value"]=0},[32]={["t"]=2,["a"]=29,["b"]=31,["value"]=0},[33]={["t"]=1,["a"]=28,["b"]=32,["value"]=0},[34]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[35]={["t"]=7,["a"]=38,["b"]=0,["value"]=0},[36]={["t"]=5,["a"]=35,["b"]=4294967295,["value"]=0},[37]={["t"]=2,["a"]=34,["b"]=36,["value"]=0},[38]={["t"]=1,["a"]=33,["b"]=37,["value"]=0},[39]={["t"]=4,["a"]=1109393408,["b"]=0,["value"]=40},[40]={["t"]=7,["a"]=37,["b"]=0,["value"]=0},[41]={["t"]=5,["a"]=40,["b"]=4294967295,["value"]=0},[42]={["t"]=2,["a"]=39,["b"]=41,["value"]=0},[43]={["t"]=1,["a"]=38,["b"]=42,["value"]=0},[44]={["t"]=4,["a"]=1109393408,["b"]=0,["value"]=40},[45]={["t"]=7,["a"]=40,["b"]=0,["value"]=0},[46]={["t"]=5,["a"]=45,["b"]=4294967295,["value"]=0},[47]={["t"]=2,["a"]=44,["b"]=46,["value"]=0},[48]={["t"]=0,["a"]=43,["b"]=47,["value"]=0},[49]={["t"]=4,["a"]=1069547520,["b"]=0,["value"]=1.5},[50]={["t"]=7,["a"]=48,["b"]=0,["value"]=0},[51]={["t"]=5,["a"]=50,["b"]=4294967295,["value"]=0},[52]={["t"]=2,["a"]=49,["b"]=51,["value"]=0},[53]={["t"]=0,["a"]=48,["b"]=52,["value"]=0},[54]={["t"]=4,["a"]=1077936128,["b"]=0,["value"]=3},[55]={["t"]=7,["a"]=50,["b"]=0,["value"]=0},[56]={["t"]=5,["a"]=55,["b"]=4294967295,["value"]=0},[57]={["t"]=2,["a"]=54,["b"]=56,["value"]=0},[58]={["t"]=0,["a"]=53,["b"]=57,["value"]=0},[59]={["t"]=4,["a"]=1084227584,["b"]=0,["value"]=5},[60]={["t"]=7,["a"]=52,["b"]=0,["value"]=0},[61]={["t"]=5,["a"]=60,["b"]=4294967295,["value"]=0},[62]={["t"]=2,["a"]=59,["b"]=61,["value"]=0},[63]={["t"]=0,["a"]=58,["b"]=62,["value"]=0},[64]={["t"]=4,["a"]=1088421888,["b"]=0,["value"]=7},[65]={["t"]=7,["a"]=54,["b"]=0,["value"]=0},[66]={["t"]=5,["a"]=65,["b"]=4294967295,["value"]=0},[67]={["t"]=2,["a"]=64,["b"]=66,["value"]=0},[68]={["t"]=0,["a"]=63,["b"]=67,["value"]=0},[69]={["t"]=4,["a"]=1082130432,["b"]=0,["value"]=4},[70]={["t"]=7,["a"]=47,["b"]=0,["value"]=0},[71]={["t"]=5,["a"]=70,["b"]=4294967295,["value"]=0},[72]={["t"]=7,["a"]=48,["b"]=0,["value"]=0},[73]={["t"]=5,["a"]=72,["b"]=4294967295,["value"]=0},[74]={["t"]=1,["a"]=71,["b"]=73,["value"]=0},[75]={["t"]=2,["a"]=69,["b"]=74,["value"]=0},[76]={["t"]=1,["a"]=68,["b"]=75,["value"]=0},[77]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[78]={["t"]=7,["a"]=57,["b"]=0,["value"]=0},[79]={["t"]=5,["a"]=78,["b"]=4294967295,["value"]=0},[80]={["t"]=2,["a"]=77,["b"]=79,["value"]=0},[81]={["t"]=0,["a"]=76,["b"]=80,["value"]=0},[82]={["t"]=4,["a"]=1077936128,["b"]=0,["value"]=3},[83]={["t"]=7,["a"]=58,["b"]=0,["value"]=0},[84]={["t"]=5,["a"]=83,["b"]=4294967295,["value"]=0},[85]={["t"]=2,["a"]=82,["b"]=84,["value"]=0},[86]={["t"]=0,["a"]=81,["b"]=85,["value"]=0},[87]={["t"]=4,["a"]=1077936128,["b"]=0,["value"]=3},[88]={["t"]=7,["a"]=59,["b"]=0,["value"]=0},[89]={["t"]=5,["a"]=88,["b"]=4294967295,["value"]=0},[90]={["t"]=2,["a"]=87,["b"]=89,["value"]=0},[91]={["t"]=0,["a"]=86,["b"]=90,["value"]=0},[92]={["t"]=4,["a"]=1082130432,["b"]=0,["value"]=4},[93]={["t"]=7,["a"]=60,["b"]=0,["value"]=0},[94]={["t"]=5,["a"]=93,["b"]=4294967295,["value"]=0},[95]={["t"]=2,["a"]=92,["b"]=94,["value"]=0},[96]={["t"]=0,["a"]=91,["b"]=95,["value"]=0},[97]={["t"]=4,["a"]=0,["b"]=0,["value"]=0},[98]={["t"]=7,["a"]=61,["b"]=0,["value"]=0},[99]={["t"]=5,["a"]=98,["b"]=4294967295,["value"]=0},[100]={["t"]=7,["a"]=62,["b"]=0,["value"]=0},[101]={["t"]=5,["a"]=100,["b"]=4294967295,["value"]=0},[102]={["t"]=1,["a"]=99,["b"]=101,["value"]=0},[103]={["t"]=2,["a"]=97,["b"]=102,["value"]=0},[104]={["t"]=1,["a"]=96,["b"]=103,["value"]=0},[105]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[106]={["t"]=7,["a"]=66,["b"]=0,["value"]=0},[107]={["t"]=5,["a"]=106,["b"]=4294967295,["value"]=0},[108]={["t"]=2,["a"]=105,["b"]=107,["value"]=0},[109]={["t"]=1,["a"]=104,["b"]=108,["value"]=0},[110]={["t"]=4,["a"]=1112014848,["b"]=0,["value"]=50},[111]={["t"]=7,["a"]=67,["b"]=0,["value"]=0},[112]={["t"]=5,["a"]=111,["b"]=4294967295,["value"]=0},[113]={["t"]=2,["a"]=110,["b"]=112,["value"]=0},[114]={["t"]=1,["a"]=109,["b"]=113,["value"]=0},[115]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[116]={["t"]=7,["a"]=76,["b"]=0,["value"]=0},[117]={["t"]=5,["a"]=116,["b"]=4294967295,["value"]=0},[118]={["t"]=2,["a"]=115,["b"]=117,["value"]=0},[119]={["t"]=0,["a"]=114,["b"]=118,["value"]=0},[120]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[121]={["t"]=7,["a"]=77,["b"]=0,["value"]=0},[122]={["t"]=5,["a"]=121,["b"]=4294967295,["value"]=0},[123]={["t"]=2,["a"]=120,["b"]=122,["value"]=0},[124]={["t"]=0,["a"]=119,["b"]=123,["value"]=0},[125]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[126]={["t"]=7,["a"]=78,["b"]=0,["value"]=0},[127]={["t"]=5,["a"]=126,["b"]=4294967295,["value"]=0},[128]={["t"]=2,["a"]=125,["b"]=127,["value"]=0},[129]={["t"]=0,["a"]=124,["b"]=128,["value"]=0},[130]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[131]={["t"]=7,["a"]=79,["b"]=0,["value"]=0},[132]={["t"]=5,["a"]=131,["b"]=4294967295,["value"]=0},[133]={["t"]=2,["a"]=130,["b"]=132,["value"]=0},[134]={["t"]=0,["a"]=129,["b"]=133,["value"]=0},[135]={["t"]=4,["a"]=1065353216,["b"]=0,["value"]=1},[136]={["t"]=7,["a"]=81,["b"]=0,["value"]=0},[137]={["t"]=5,["a"]=136,["b"]=4294967295,["value"]=0},[138]={["t"]=2,["a"]=135,["b"]=137,["value"]=0},[139]={["t"]=1,["a"]=134,["b"]=138,["value"]=0},[140]={["t"]=4,["a"]=1065353216,["b"]=0,["value"]=1},[141]={["t"]=7,["a"]=82,["b"]=0,["value"]=0},[142]={["t"]=5,["a"]=141,["b"]=4294967295,["value"]=0},[143]={["t"]=2,["a"]=140,["b"]=142,["value"]=0},[144]={["t"]=1,["a"]=139,["b"]=143,["value"]=0},[145]={["t"]=4,["a"]=1090519040,["b"]=0,["value"]=8},[146]={["t"]=7,["a"]=88,["b"]=0,["value"]=0},[147]={["t"]=5,["a"]=146,["b"]=4294967295,["value"]=0},[148]={["t"]=2,["a"]=145,["b"]=147,["value"]=0},[149]={["t"]=0,["a"]=144,["b"]=148,["value"]=0},[150]={["t"]=4,["a"]=1101004800,["b"]=0,["value"]=20},[151]={["t"]=7,["a"]=83,["b"]=0,["value"]=0},[152]={["t"]=5,["a"]=151,["b"]=4294967295,["value"]=0},[153]={["t"]=2,["a"]=150,["b"]=152,["value"]=0},[154]={["t"]=0,["a"]=149,["b"]=153,["value"]=0},[155]={["t"]=4,["a"]=1092616192,["b"]=0,["value"]=10},[156]={["t"]=7,["a"]=85,["b"]=0,["value"]=0},[157]={["t"]=5,["a"]=156,["b"]=4294967295,["value"]=0},[158]={["t"]=2,["a"]=155,["b"]=157,["value"]=0},[159]={["t"]=0,["a"]=154,["b"]=158,["value"]=0},["count"]=160}}
for _,g in ipairs(groups) do local a=model.instant(programs,g.before,2147483834);local b=model.instant(programs,g.after,2147483834);if not a or not b or a.note~=g.beforeNote or b.note~=g.afterNote then return false end end
local result=model.observed_timeline(before,after,groups,2147483834)
if not result or not model.same(result.stateNotes,expected.stateNotes) then return false end
for _,k in ipairs({"from","to","total","eventEffect","contextEffect"}) do if result[k]~=expected[k] then return false end end
if #result.components~=#expected.components then return false end
for i,p in ipairs(result.components) do local e=expected.components[i];if p.label~=e.label or p.effect~=e.effect or p.source~=e.source or p.sequence~=e.sequence then return false end end
return true,result
end

-- END embedded observed context
local rating_capture = (function()
-- Captura e validacao do calculo original. Nunca escreve notas ou estatisticas.
local m = { version = "0.13" }
local kernel, capture, next_sample, last_note, last_key, budget = nil,nil,0,nil,nil,96
local last_snapshot_time=0
local function read(address,size)
    if not address or address<0x10000 or address>0x7fffffffffff then return end
    local out,used=ffi.new("uint8_t[?]",size),ffi.new("uintptr_t[1]")
    if kernel.ReadProcessMemory(kernel.GetCurrentProcess(),ffi.cast("void *",address),out,size,used)==0 or tonumber(used[0])~=size then return end
    return out
end
local function ptr(address)
    local b=read(address,8)
    return b and tonumber(ffi.cast("uintptr_t *",b)[0])
end
local function json_numbers(values)
    local t={}
    for i=1,#values do
        local v=values[i]
        if v~=nil and v==v and math.abs(v)<1e15 then
            -- IDs, contadores e indices precisam permanecer inteiros no JSON.
            -- Nove algarismos significativos arredondavam 2147483834 para
            -- 2147483830 e impediam a identificacao exata do jogador.
            t[i]=v==math.floor(v) and string.format("%.0f",v) or string.format("%.9g",v)
        else
            t[i]="null"
        end
    end
    return "["..table.concat(t,",").."]"
end
local function archive_line(text)
    log(text)
    if not m.archive_path then return end
    local handle=kernel.CreateFileW(m.archive_path,4,3,nil,4,0x80,nil)
    if handle==nil or tonumber(ffi.cast("intptr_t",handle))==-1 then
        if not m.archive_failed then log("BAL arquivo: nao foi possivel acrescentar a captura.");m.archive_failed=true end
        return
    end
    local line=text.."\r\n"
    local written=ffi.new("uint32_t[1]")
    local ok=kernel.WriteFile(handle,line,#line,written,nil)
    kernel.CloseHandle(handle)
    if ok==0 or tonumber(written[0])~=#line then
        if not m.archive_failed then log("BAL arquivo: gravacao incompleta da captura.");m.archive_failed=true end
    end
end
local function prepare_archive()
    local path=ffi.new("uint16_t[1024]")
    local dll=kernel.GetModuleHandleA("sider.dll")
    if dll==nil then return end
    local length=tonumber(kernel.GetModuleFileNameW(dll,path,1024))
    if length<1 or length>=900 then return end
    local last
    for i=length-1,0,-1 do if path[i]==92 or path[i]==47 then last=i;break end end
    if not last then return end
    local name="bal-rating-captures.log"
    for i=1,#name do path[last+i]=string.byte(name,i) end
    path[last+#name+1]=0
    m.archive_path=path
    local tick=ffi.new("int64_t[1]")
    kernel.QueryPerformanceCounter(tick)
    m.session=tostring(tonumber(kernel.GetCurrentProcessId())).."_"..string.format("%.0f",tonumber(tick[0]))
    archive_line('BAL_RATING_SESSION {"session":"'..m.session..'","schema":5}')
end
local function team_signature(data)
    local parts,words={},ffi.cast("uint32_t *",data)
    for slot=0,39 do
        local off=0x64d8+slot*0x2134
        local started,finished=tonumber(data[off+0x18ec]),tonumber(data[off+0x18ed])
        parts[#parts+1]=string.char(started,finished)
        if started~=255 then
            parts[#parts+1]=ffi.string(data+off+4,4)
            parts[#parts+1]=ffi.string(data+off+8,135*36)
            local role,max_role=13,0
            for roleid=0,12 do
                local ticks=tonumber(words[(off+0x18fc)/4+roleid])
                if ticks>max_role then role,max_role=roleid,ticks end
            end
            parts[#parts+1]=string.char(role)
            parts[#parts+1]=ffi.string(data+off+0x1934,4)
        end
    end
    return table.concat(parts)
end
local function install_frame_capture(ctx,base)
    if ctx.bal_frame_capture_v3 then return ctx.bal_frame_capture_v3 end
    -- Epilogo da normalizacao ao vivo. RSI=objeto, R15=configuracao.
    local site=base+0xa1de6c
    local expected="\x4c\x8d\x9c\x24\xc0\x02\x00\x00"
    local previous_address=ctx.bal_frame_capture_v2 or ctx.bal_rating_capture
    local previous=previous_address and ("\xe9"..memory.pack("i32",previous_address-site-5).."\x90\x90\x90")
    local current=memory.read(site,#expected)
    if current~=expected and current~=previous then
        log("BAL frame: assinatura diferente; captura anterior mantida.");return
    end
    for step=1,224 do
        local distance=math.floor((step+1)/2)*0x1000000
        local region=kernel.VirtualAlloc(ffi.cast("void *",base+(step%2==1 and distance or -distance)),0xc0000,0x3000,0x04)
        if region~=nil then
            local a=tonumber(ffi.cast("uintptr_t",region))
            local code=""
            local function emit(bytes) code=code..bytes end
            local function relative(bytes,target)
                emit(bytes..memory.pack("i32",target-(a+#code+#bytes+4)))
            end
            local function copy(source,destination,size)
                emit(source)
                relative("\x48\x8d\x3d",a+destination)
                emit("\xb9"..memory.pack("i32",size/4).."\xf3\xa5")
            end
            -- Preserva flags e todos os registradores usados. Nao chama funcoes.
            emit("\x9c\x50\x51\x56\x57\xfc")
            relative("\xff\x05",a+512)
            relative("\x48\x89\x35",a+520)
            relative("\x4c\x89\x3d",a+536)
            emit("\x48\x8b\x86\x08\xbd\x00\x00\x48\x8d\x80\xd0\x50\x07\x00")
            relative("\x48\x89\x05",a+528)
            copy("\x48\x8b\xf0",0x1000,0xb2ca0)
            relative("\x48\x8b\x35",a+520)
            copy("\x48\x8d\xb6\xc0\x01\x00\x00",0xb4000,80*16)
            copy("\x49\x8b\xf7",0xb4500,0x298)
            relative("\x48\x8b\x35",a+520)
            copy("\x48\x8b\xb6\x08\xbd\x00\x00\x48\x8d\xb6\x60\x07\x18\x00",0xb4800,80*16)
            relative("\x48\x8b\x35",a+528)
            copy("\x48\x8d\xb6\xbc\x8d\x10\x00",0xb6000,0x2000)
            relative("\x48\x8b\x05",base+0x36f3dc8)
            for team=0,1 do
                copy("\x48\x8b\xb0"..memory.pack("i32",(team+0xa1)*40).."\x48\x8d\xb6\x00\x4c\x00\x00",0xb5000+team*128,44)
                copy("\x48\x8b\xb0"..memory.pack("i32",(team+0xa3)*40),0xb5040+team*128,48)
            end
            relative("\xff\x05",a+512)
            emit("\x5f\x5e\x59\x58\x9d"..expected)
            relative("\xe9",site+#expected)
            if #code>=512 then log("BAL frame: codigo excede area reservada.");return end
            memory.write(a,code)
            local old=ffi.new("uint32_t[1]")
            -- Somente o codigo fica executavel. As copias permanecem RW.
            if kernel.VirtualProtect(region,4096,0x40,old)==0 then log("BAL frame: protecao de codigo indisponivel.");return end
            kernel.FlushInstructionCache(kernel.GetCurrentProcess(),region,#code)
            memory.write(site,"\xe9"..memory.pack("i32",a-site-5)..string.rep("\x90",#expected-5))
            kernel.FlushInstructionCache(kernel.GetCurrentProcess(),ffi.cast("void *",site),#expected)
            ctx.bal_frame_capture_v3=a
            log("BAL frame: copia junto ao calculo instalada, bytes="..tostring(#code))
            return a
        end
    end
    log("BAL frame: nenhuma regiao livre proxima para a copia.")
end
-- BEGIN embedded event collector
-- Research collector. A native event is not automatically a physical action.
local function create_event_probe(kernel,read,ptr,json_numbers,archive_line,session,on_event,on_gap)
    local e={budget=4096,cursor=0,epoch=0}
    -- BEGIN generated event code
    local code_hex="41544881ecb0000000488974247048897c2478488944242048894c242848895424304c894424384c894c24404c895424484c895c2450fc4531e4803dd7070000000f8448010000488b8108bd0000488d80d0500700488db0d86400004531d2817e04ba0000800f842d0000004981fa4f0000000f841601000041ffc24881c6342100004183fa280f85d2ffffff4881c630660000e9c6ffffff4989f34889c2b801000000f0480fc105530700004c8d48014c898c24800000004883e03f4869c0005000004c8d25350f00004901c44d890c2449c74424080000000049895424104d895c241849894c24204d89442428418b004189442430458954243465488b042548000000498944243849c7442440000000008b8100bd000041894424500f3148c1e2204809d04989442460498bf0498dbc2480010000b9c8000000f3a5498bf3498dbc2400050000b94d080000f3a5498bc248c1e0044903442410480590b61000488bf0498dbc2400010000b904000000f3a5488b05950600004885c00f840b0000008b80000200004189442440488b742470488b7c2478488b442420488b4c2428488b5424304c8b4424384c8b4c24404c8b5424484c8b5c2450e86f1fa200488944242048894c242848895424304c894424384c894c24404c895424484c895c2450fc4d85e40f84820000004c8b9424800000004d3914240f8570000000498b742418498dbc2400280000b94d080000f3a5418b44243448c1e0044903442410480590b61000488bf0498dbc2410010000b904000000f3a50f3148c1e2204809d04989442468488b05c10500004885c00f840b0000008b800002000041894424444c8b9424800000004d89542408488b742470488b7c2478488b442420488b4c2428488b5424304c8b4424384c8b4c24404c8b5424484c8b5c24504881c4b0000000415cc3"
    local native_call_offset=445
    local context_code_hex="41544881ecb0000000488974247048897c2478488944242048894c242848895424304c894424384c894c24404c895424484c895c2450fc4531e4803dd7fdffff000f845d010000488b8108bd0000488d80d0500700488db0d86400004531d2817e04ba0000800f842d0000004981fa4f0000000f842b01000041ffc24881c6342100004183fa280f85d2ffffff4881c630660000e9c6ffffff4989f34889c2b801000000f0480fc10553fdffff4c8d48014c898c24800000004883e03f4869c0005000004c8d25350500004901c44d890c2449c74424080000000049895424104d895c241849894c24204d8944242841c7442430feffffff49c744242800000000458954243465488b042548000000498944243849c7442440000000008b8100bd000041894424500f3148c1e2204809d0498944246031c0498dbc2480010000b9c8000000f3ab41c7842480010000feffffff498bf3498dbc2400050000b94d080000f3a5498bc248c1e0044903442410480590b61000488bf0498dbc2400010000b904000000f3a5488b0580fcffff4885c00f840b0000008b80000200004189442440488b742470488b7c2478488b442420488b4c2428488b5424304c8b4424384c8b4c24404c8b5424484c8b5c2450e83a30a200488944242048894c242848895424304c894424384c894c24404c895424484c895c2450fc4d85e40f84820000004c8b9424800000004d3914240f8570000000498b742418498dbc2400280000b94d080000f3a5418b44243448c1e0044903442410480590b61000488bf0498dbc2410010000b904000000f3a50f3148c1e2204809d04989442468488b05acfbffff4885c00f840b0000008b800002000041894424444c8b9424800000004d89542408488b742470488b7c2478488b442420488b4c2428488b5424304c8b4424384c8b4c24404c8b5424484c8b5c24504881c4b0000000415cc3"
    local context_call_offset=466
    local unwind_hex="0113070013740f000e640e000901160002c00000"
    -- END generated event code
    local function build(address,base,context_update)
        local hex=context_update and context_code_hex or code_hex
        local offset=context_update and context_call_offset or native_call_offset
        local start=address+(context_update and 0xa00 or 0)
        local target=base+(context_update and 0xa23c10 or 0xa22130)
        local code=hex:gsub("..",function(h)return string.char(tonumber(h,16))end)
        return code:sub(1,offset)..memory.pack("i32",target-(start+offset+4))..code:sub(offset+5)
    end
    function e.init(ctx,base,frame)
        local site=base+0xa0d33e
        local context_site=base+0xa0d30a
        local expected="\xe8\xed\x4d\x01\x00"
        local expected_context="\xe8"..memory.pack("i32",base+0xa23c10-context_site-5)
        if ctx.bal_native_event_v2 then
            local a=ctx.bal_native_event_v2
            if memory.read(site,5)~="\xe8"..memory.pack("i32",(ctx.bal_native_context_v3 or a)-site-5)
                or memory.read(context_site,5)~="\xe8"..memory.pack("i32",a+0xa00-context_site-5) then
                log("BAL evento: detour anterior diferente, coleta bloqueada.");return
            end
            e.address=a
        else
            local original_patch=memory.read(site,5)
            local owned=ctx.bal_native_event_v1 and "\xe8"..memory.pack("i32",ctx.bal_native_event_v1-site-5)
            if (original_patch~=expected and original_patch~=owned) or memory.read(context_site,5)~=expected_context
                or memory.read(base+0xa22130,21)~="\x48\x8b\xc4\x55\x56\x57\x41\x54\x41\x55\x41\x56\x41\x57\x48\x81\xec\x90\x03\x00\x00" then
                log("BAL evento: assinatura diferente, coleta bloqueada.");return
            end
            for step=1,224 do
                local distance=math.floor((step+1)/2)*0x1000000
                local region=kernel.VirtualAlloc(ffi.cast("void *",base+(step%2==1 and distance or -distance)),0x141000,0x3000,0x04)
                if region~=nil then
                    local a=tonumber(ffi.cast("uintptr_t",region))
                    local code=build(a,base)
                    local context_code=build(a,base,true)
                    memory.write(a,code)
                    memory.write(a+0xa00,context_code)
                    local unwind_bytes=unwind_hex:gsub("..",function(h)return string.char(tonumber(h,16))end)
                    memory.write(a+0x900,unwind_bytes)
                    memory.write(a+0xd00,unwind_bytes)
                    memory.write(a+0x920,memory.pack("i32",0)..memory.pack("i32",#code)..memory.pack("i32",0x900)
                        ..memory.pack("i32",0xa00)..memory.pack("i32",0xa00+#context_code)..memory.pack("i32",0xd00))
                    ffi.cdef[[uint8_t __stdcall RtlAddFunctionTable(void *table,uint32_t count,uint64_t base);]]
                    local runtime=ffi.load("ntdll")
                    if runtime.RtlAddFunctionTable(ffi.cast("void *",a+0x920),2,a)==0 then
                        log("BAL evento: unwind indisponivel, captura nao instalada.");return
                    end
                    local previous=ffi.new("uint32_t[1]")
                    if kernel.VirtualProtect(region,4096,0x40,previous)==0 then
                        log("BAL evento: nao foi possivel preparar codigo.");return
                    end
                    kernel.FlushInstructionCache(kernel.GetCurrentProcess(),region,4096)
                    local patch="\xe8"..memory.pack("i32",a-site-5)
                    local context_patch="\xe8"..memory.pack("i32",a+0xa00-context_site-5)
                    memory.write(context_site,context_patch)
                    memory.write(site,patch)
                    kernel.FlushInstructionCache(kernel.GetCurrentProcess(),ffi.cast("void *",site),5)
                    kernel.FlushInstructionCache(kernel.GetCurrentProcess(),ffi.cast("void *",context_site),5)
                    if memory.read(site,5)~=patch or memory.read(context_site,5)~=context_patch then
                        memory.write(site,original_patch)
                        memory.write(context_site,expected_context)
                        kernel.FlushInstructionCache(kernel.GetCurrentProcess(),ffi.cast("void *",site),5)
                        kernel.FlushInstructionCache(kernel.GetCurrentProcess(),ffi.cast("void *",context_site),5)
                        log("BAL evento: instalacao nao confirmada, chamada original restaurada.");return
                    end
                    e.address=a;ctx.bal_native_event_v2=a;break
                end
            end
        end
        if not e.address then log("BAL evento: regiao proxima indisponivel.");return end
        memory.write(e.address+0x810,ffi.string(ffi.new("uint64_t[1]",frame or 0),8))
        e.cursor=ptr(e.address+0x800) or 0
        memory.write(e.address+0x818,"\x01")
        archive_line('BAL_NATIVE_EVENT_SESSION {"session":"'..session()..'","version":2,"contextUpdatesIncluded":true,"nativeEventBoundary":true,"physicalActionValidated":false,"historicalActionAttribution":false}')
        log("BAL evento: copia anterior e posterior ao despachante instalada.")
    end
    function e.reset()
        e.budget=4096
        if e.address then
            e.cursor=ptr(e.address+0x800) or e.cursor
            e.epoch=e.epoch+1
            memory.write(e.address+0x818,"\x01")
            archive_line('BAL_NATIVE_EVENT_RESET {"session":"'..session()..'","epoch":'..e.epoch..',"afterSequence":'..e.cursor..'}')
        end
    end
    local function state(bytes,record,unique)
        local words=ffi.cast("uint32_t *",bytes)
        local stats,u={},{}
        for id=0,134 do
            local n=0
            for period=0,7 do n=n+tonumber(words[record/4+2+id*9+period]) end
            stats[id+1]=n
        end
        for i=0,3 do u[i+1]=tonumber(words[unique/4+i]) end
        local note=tonumber(ffi.cast("float *",bytes)[(record+0x1934)/4])
        local player={tonumber(words[record/4+1]),tonumber(bytes[record+0x18ec]),tonumber(bytes[record+0x18ed]),note}
        return {s=stats,u=u,player=player}
    end
    local function encoded(x)
        return '{"player":'..json_numbers(x.player)..',"s":'..json_numbers(x.s)..',"u":'..json_numbers(x.u)..'}'
    end
    function e.drain(now,ctx,live_root)
        if not e.address then return end
        local head=ptr(e.address+0x800)
        if not head then return end
        if head-e.cursor>64 then
            if on_gap then on_gap() end
            archive_line('BAL_NATIVE_EVENT_GAP {"session":"'..session()..'","from":'..(e.cursor+1)..',"to":'..(head-64)..',"reason":"ring-overflow"}')
            e.cursor=head-64
        end
        while e.cursor<head do
            local sequence=e.cursor+1
            local address=e.address+0x1000+(e.cursor%64)*0x5000
            if ptr(address)~=sequence or ptr(address+8)~=sequence then return end
            local data=read(address,0x5000)
            if not data or ptr(address)~=sequence or ptr(address+8)~=sequence then return end
            local q=ffi.cast("uint64_t *",data)
            local w=ffi.cast("uint32_t *",data)
            local before,after=state(data,0x500,0x100),state(data,0x2800,0x110)
            local changed=false
            for i=1,135 do if before.s[i]~=after.s[i] then changed=true end end
            for i=1,4 do if before.u[i]~=after.u[i] then changed=true end end
            if before.player[4]~=after.player[4] then changed=true end
            local root=tonumber(q[2])
            if changed and root~=live_root then
                if on_gap then on_gap() end
                archive_line('BAL_NATIVE_EVENT_GAP {"session":"'..session()..'","from":'..sequence..',"to":'..sequence..',"reason":"root-changed"}')
            elseif changed and e.budget>0 then
                local context_update=tonumber(w[12])==4294967294
                if on_event then on_event({before_s=before.s,before_u=before.u,after_s=after.s,after_u=after.u,sequence=sequence,type=tonumber(w[12]),contextUpdate=context_update,label=context_update and "Contexto" or nil}) end
                local key=tostring(root)..":"..tostring(ctx.home_team)..":"..tostring(ctx.away_team)
                local payload=ffi.string(data+0x180,0x320):gsub(".",function(c)return string.format("%02x",string.byte(c))end)
                archive_line('BAL_NATIVE_EVENT {"session":"'..session()..'","epoch":'..e.epoch..',"match":"'..key..'","sequence":'..sequence..',"type":'..tonumber(w[12])..',"slot":'..tonumber(w[13])..',"thread":'..tonumber(q[7])..',"frame":'..tonumber(w[20])..',"generationBefore":'..tonumber(w[16])..',"generationAfter":'..tonumber(w[17])..',"observedAt":'..string.format("%.6f",now)..',"cpuTicksBefore":'..string.format("%.0f",tonumber(q[12]))..',"cpuTicksAfter":'..string.format("%.0f",tonumber(q[13]))..',"before":'..encoded(before)..',"after":'..encoded(after)..',"payload":"'..payload..'","nativeEventBoundary":'..(context_update and 'false' or 'true')..',"contextUpdate":'..(context_update and 'true' or 'false')..',"physicalActionValidated":false,"historicalActionAttribution":false}')
                e.budget=e.budget-1
                if e.budget==0 then
                    if on_gap then on_gap() end
                    memory.write(e.address+0x818,"\x00")
                    archive_line('BAL_NATIVE_EVENT_GAP {"session":"'..session()..'","from":'..(sequence+1)..',"reason":"capture-budget"}')
                end
            end
            e.cursor=sequence
        end
    end
    return e
end
-- END embedded event collector
-- BEGIN embedded context collector
-- Decode owned native copies. No game-memory access occurs here.
local function create_context_decoder()
    local function finite(n)return n==n and math.abs(n)<math.huge end
    local function state(data,offset)
        local b=data+offset
        local function u(at)return tonumber(ffi.cast("uint32_t *",b+at)[0])end
        local function f(at)return tonumber(ffi.cast("float *",b+at)[0])end
        local function q(at)return tonumber(ffi.cast("uint64_t *",b+at)[0])end
        local x={valid=u(0xec00)==1,root=q(0xec08),object=q(0xec10),frame=u(0xec18),frameBefore=u(0xec1c),generation=u(0xec28),generationBefore=u(0xec2c),schema=6}
        if not x.valid then return x end
        x.duration=f(0xec04)
        if not finite(x.duration) or x.duration<=0 or x.duration>120 then x.valid=false;return x end
        x.constants={};for i=0,165 do x.constants[i+1]=f(0xc800+i*4) end
        x.goals={};x.score={0,0};x.players={}
        local count=tonumber(b[0xcc00+0x1ef3])
        if count>198 then x.valid=false;return x end
        for i=0,count-1 do
            local team,minute=u(0xcc00+i*40+4),tonumber(b[0xcc00+i*40+12])
            if team>1 then x.valid=false;return x end
            x.goals[#x.goals+1]={team,minute};x.score[team+1]=x.score[team+1]+1
        end
        for team=0,1 do
            local categories={}
            for i=0,10 do categories[u(0xcb2c+team*128+(i+1)*4)]=u(0xcb00+team*128+i*4) end
            for slot=0,39 do
                local row=(team*40+slot)*0x280
                local start,finish=tonumber(b[row+4]),tonumber(b[row+5])
                if start~=255 then
                    local role,max=13,0
                    for i=0,12 do local n=u(row+0x24c+i*4);if n>max then role,max=i,n end end
                    local category=categories[slot]
                    local p={v={team,slot,u(row),start,finish,role,f(row+8),f(row+12),f(row+24),u(row+16),u(row+20),category or 255},s={},u={},t={0,0},a=category and 1 or 0}
                    for _,n in ipairs(p.v) do if not finite(n) then x.valid=false;return x end end
                    for i=0,134 do p.s[i+1]=u(row+0x20+i*4) end
                    for i=0,3 do p.u[i+1]=u(row+0x23c+i*4) end
                    for _,g in ipairs(x.goals) do if g[2]>=start and g[2]<=finish then p.t[g[1]+1]=p.t[g[1]+1]+1 end end
                    x.players[#x.players+1]=p
                end
            end
        end
        return x
    end
    return function(data)
        local w,q=ffi.cast("uint32_t *",data),ffi.cast("uint64_t *",data)
        local a,b=state(data,0x1000),state(data,0x10000)
        local x={before=a,after=b,sequence=tonumber(q[0]),root=tonumber(q[2]),type=tonumber(w[12]),generationBefore=tonumber(w[16]),generationAfter=tonumber(w[17]),contextUpdate=tonumber(w[12])==4294967294}
        x.valid=a.valid and b.valid and x.sequence>0 and x.sequence==tonumber(q[1]) and tonumber(w[22])==0
            and a.root==x.root and b.root==x.root and a.frame==a.frameBefore and b.frame==b.frameBefore and a.frame==b.frame
            and a.generation==a.generationBefore and b.generation==b.generationBefore
            and a.generation==x.generationBefore and b.generation==x.generationAfter and x.generationBefore==x.generationAfter
            and x.generationBefore>0 and x.generationBefore%2==0 and tonumber(w[0x180/4])==x.type and q[12]<=q[13]
        return x
    end
end
-- Independent XPRESS_HUFF buffer-mode packets, each checked by SHA256.
local function create_context_archive(kernel,archive_line)
    ffi.cdef[[
    int __stdcall CreateCompressor(uint32_t algorithm,void *allocator,void **handle);
    int __stdcall Compress(void *handle,const void *source,uintptr_t sourceSize,void *output,uintptr_t outputSize,uintptr_t *written);
    int __stdcall CloseCompressor(void *handle);
    int32_t __stdcall BCryptOpenAlgorithmProvider(void **handle,const uint16_t *name,const uint16_t *implementation,uint32_t flags);
    int32_t __stdcall BCryptHash(void *handle,void *secret,uint32_t secretSize,const void *input,uint32_t inputSize,void *output,uint32_t outputSize);
    int32_t __stdcall BCryptCloseAlgorithmProvider(void *handle,uint32_t flags);
    ]]
    local cabinet,bcrypt=ffi.load("cabinet"),ffi.load("bcrypt")
    local path=ffi.new("uint16_t[1024]")
    local dll=kernel.GetModuleHandleA("sider.dll")
    local length=tonumber(kernel.GetModuleFileNameW(dll,path,1024))
    if length<1 or length>=900 then return end
    local last
    for i=length-1,0,-1 do if path[i]==92 or path[i]==47 then last=i;break end end
    if not last then return end
    local name="bal-context-captures.balc"
    for i=1,#name do path[last+i]=string.byte(name,i) end
    path[last+#name+1]=0
    local algorithm=ffi.new("void *[1]")
    local algorithm_name=ffi.new("uint16_t[7]",{83,72,65,50,53,54,0})
    if bcrypt.BCryptOpenAlgorithmProvider(algorithm,algorithm_name,nil,0)~=0 then return end
    local output=ffi.new("uint8_t[?]",0x41000)
    local hash=ffi.new("uint8_t[32]")
    local function encode(data,size)
        local compressor,used=ffi.new("void *[1]"),ffi.new("uintptr_t[1]")
        if cabinet.CreateCompressor(4,nil,compressor)==0 then return end
        local ok=cabinet.Compress(compressor[0],data,size,output,0x41000,used)
        cabinet.CloseCompressor(compressor[0])
        if ok==0 or bcrypt.BCryptHash(algorithm[0],nil,0,data,size,hash,32)~=0 then return end
        local hex={};for i=0,31 do hex[#hex+1]=string.format("%02x",tonumber(hash[i])) end
        return ffi.string(output,tonumber(used[0])),table.concat(hex)
    end
    local test,digest=encode("abc",3)
    if not test or digest~="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" then
        bcrypt.BCryptCloseAlgorithmProvider(algorithm[0],0);return
    end
    local writer={}
    function writer.write(data,metadata)
        local compressed,sha=encode(data,0x20000)
        if not compressed then return false end
        local meta=metadata:sub(1,-2)..',"rawBytes":131072,"rawSha256":"'..sha..'"}'
        if #meta>8192 then return false end
        local bytes="BALCTX3\0"..memory.pack("i32",#compressed)..memory.pack("i32",#meta)..meta..compressed
        local handle=kernel.CreateFileW(path,4,3,nil,4,0x80,nil)
        if handle==nil or tonumber(ffi.cast("intptr_t",handle))==-1 then return false end
        local used=ffi.new("uint32_t[1]")
        local ok=kernel.WriteFile(handle,bytes,#bytes,used,nil)
        kernel.CloseHandle(handle)
        return ok~=0 and tonumber(used[0])==#bytes
    end
    return writer
end
-- Full observed-context collector, chained to the validated v2 dispatcher.
local function create_full_context_probe(kernel,read,ptr,archive_line,session,model,programs,writer,decode)
    local e={cursor=0,epoch=0,budget=32768,groups={},ready=false}
    -- BEGIN generated context code
    local code_hex="41544881ecb0000000488974247048897c2478488944242048894c242848895424304c894424384c894c24404c895424484c895c2450fc4531e4803dd72f0000000f8453040000488b8108bd0000483d000001000f8240040000488d80d0500700488db0d86400004531d2817e04ba0000800f842a0000004183fa4f0f841804000041ffc24881c6342100004183fa280f85d5ffffff4881c630660000e9c9ffffff4989f34889c2b801000000f0480fc1054a2f00004c8d48014c898c24800000004883e03f48c1e0114c8d252f3f00004901c44d890c2449c74424080000000049895424104d895c241849894c24204d89442428418b004189442430458954243465488b04254800000049894424388b8100bd00004189442450b801000000f0480fc105f72e000031d24885c00f95c20fb6d241895424580f8408000000f048ff05e12e0000488b05da2e000049894424700f3148c1e2204809d04989442460498bf0498dbc2480010000b9c8000000f3a5498dbc2400100000498b442420488b8008bd0000488d80d0500700493b4424100f85cc020000498b4424208b8000bd000089871cec0000488b055f2e00004885c00f840b0000008b8000020000e90200000031c089872cec0000498b7424104881c6e06400004d8b5c24204981c3c00100004d8b5424104981c290b610004531c08b46fc89070fb786e41800006689470466c747060000498b0348894708498b4308488947108b862c190000894718c7471c000000004883c720ba870000008b0603460403460803460c03461003461403461803461c89074883c6244883c70483ea010f85d6ffffff498b02488907498b4208488947084883c7104983c2104983c3104881c6f8050000b90d000000f3a54881c60c08000041ffc04183f8280f85070000004881c6306600004183f8500f824bffffff488b05602d00004885c00f844d000000488bb010020000493b7424100f853b000000488bb008020000493b7424200f85290000004c8b90180200004d85d20f8419000000488db000450b0041b901000000b9a6000000f3a5e90f0000004531c94531d231c0b9a6000000f3ab4883c768488b05a83a6f03483d000001000f829f000000488bb0281900004881fe000001000f828b0000004881c6004c0000b90b000000f3a5488bb0781900004881fe000001000f8269000000b90c000000f3a54883c724488bb0501900004881fe000001000f824a0000004881c6004c0000b90b000000f3a5488bb0a01900004881fe000001000f8228000000b90c000000f3a54883c724488bb0c00200004881fe000001000f8209000000448b4658e9170000004531c94531c0498dbc2400db000031c0b940000000f3ab498b7424104881c6bc8d1000b900080000f3a544890f44894704498b44241048894708498b442420488947108b8000bd00008947184c8957203b471c0f8536000000488b05e52b00004885c00f840b0000008b8000020000e90200000031c08947283b472c0f850d000000a8010f8505000000e91e000000c70700000000e913000000498dbc2400fc00004889470831c08907894704488b05912b00004885c00f840b0000008b8000020000e90200000031c04189442440488b742470488b7c2478488b442420488b4c2428488b5424304c8b4424384c8b4c24404c8b5424484c8b5c2450e8641ca200488944242048894c242848895424304c894424384c894c24404c895424484c895c2450fc4d85e40f847c0300004c8b9424800000004d3914240f8562030000498dbc2400000100498b442420488b8008bd0000488d80d0500700493b4424100f85cc020000498b4424208b8000bd000089871cec0000488b05c72a00004885c00f840b0000008b8000020000e90200000031c089872cec0000498b7424104881c6e06400004d8b5c24204981c3c00100004d8b5424104981c290b610004531c08b46fc89070fb786e41800006689470466c747060000498b0348894708498b4308488947108b862c190000894718c7471c000000004883c720ba870000008b0603460403460803460c03461003461403461803461c89074883c6244883c70483ea010f85d6ffffff498b02488907498b4208488947084883c7104983c2104983c3104881c6f8050000b90d000000f3a54881c60c08000041ffc04183f8280f85070000004881c6306600004183f8500f824bffffff488b05c82900004885c00f844d000000488bb010020000493b7424100f853b000000488bb008020000493b7424200f85290000004c8b90180200004d85d20f8419000000488db000450b0041b901000000b9a6000000f3a5e90f0000004531c94531d231c0b9a6000000f3ab4883c768488b0510376f03483d000001000f829f000000488bb0281900004881fe000001000f828b0000004881c6004c0000b90b000000f3a5488bb0781900004881fe000001000f8269000000b90c000000f3a54883c724488bb0501900004881fe000001000f824a0000004881c6004c0000b90b000000f3a5488bb0a01900004881fe000001000f8228000000b90c000000f3a54883c724488bb0c00200004881fe000001000f8209000000448b4658e9170000004531c94531c0498dbc2400cb010031c0b940000000f3ab498b7424104881c6bc8d1000b900080000f3a544890f44894704498b44241048894708498b442420488947108b8000bd00008947184c8957203b471c0f8536000000488b054d2800004885c00f840b0000008b8000020000e90200000031c08947283b472c0f850d000000a8010f8505000000e91e000000c70700000000e913000000498dbc2400ec01004889470831c08907894704488b05f92700004885c00f840b0000008b8000020000e90200000031c041894424440f3148c1e2204809d04989442468488b05e12700004989442478493b4424700f840900000041c7442458010000004c8b9424800000004d89542408f048ff0dab270000488b742470488b7c2478488b442420488b4c2428488b5424304c8b4424384c8b4c24404c8b5424484c8b5c24504881c4b0000000415cc3"
    local native_call_offset=1224
    local world_offsets={796,1716}
    local unwind_hex="0113070013740f000e640e000901160002c00000"
    -- END generated context code
    function e.gap(reason,sequence)
        e.groups={};e.ready=false;e.base=nil
        if e.last_gap~=reason then archive_line('BAL_CONTEXT_GAP {"session":"'..session()..'","epoch":'..e.epoch..',"sequence":'..(sequence or e.cursor)..',"reason":"'..reason..'"}') end
        e.last_gap=reason
    end
    function e.init(ctx,base,frame)
        if not writer or not ctx.bal_native_event_v2 then return end
        local site=base+0xa0d33e
        local previous=memory.read(site,5)
        local owned=ctx.bal_native_context_v3
        local expected="\xe8"..memory.pack("i32",(owned or ctx.bal_native_event_v2)-site-5)
        if previous~=expected then log("BAL contexto: chamada diferente, captura bloqueada.");return end
        local a=owned
        if not a then
            for step=1,224 do
                local distance=math.floor((step+1)/2)*0x1000000
                local region=kernel.VirtualAlloc(ffi.cast("void *",base+(step%2==1 and distance or -distance)),0x804000,0x3000,4)
                if region~=nil then a=tonumber(ffi.cast("uintptr_t",region));break end
            end
            if not a then return end
            local code=code_hex:gsub("..",function(h)return string.char(tonumber(h,16))end)
            code=code:sub(1,native_call_offset)..memory.pack("i32",ctx.bal_native_event_v2-a-native_call_offset-4)..code:sub(native_call_offset+5)
            for _,offset in ipairs(world_offsets) do code=code:sub(1,offset)..memory.pack("i32",base+0x36f3dc8-a-offset-4)..code:sub(offset+5) end
            memory.write(a,code)
            memory.write(a+0x2800,unwind_hex:gsub("..",function(h)return string.char(tonumber(h,16))end))
            memory.write(a+0x2840,memory.pack("i32",0)..memory.pack("i32",#code)..memory.pack("i32",0x2800))
            local runtime=ffi.load("ntdll")
            if runtime.RtlAddFunctionTable(ffi.cast("void *",a+0x2840),1,a)==0 then return end
            local protection=ffi.new("uint32_t[1]")
            if kernel.VirtualProtect(ffi.cast("void *",a),4096,0x40,protection)==0 then return end
            kernel.FlushInstructionCache(kernel.GetCurrentProcess(),ffi.cast("void *",a),4096)
            local patch="\xe8"..memory.pack("i32",a-site-5)
            memory.write(site,patch)
            kernel.FlushInstructionCache(kernel.GetCurrentProcess(),ffi.cast("void *",site),5)
            if memory.read(site,5)~=patch then memory.write(site,previous);kernel.FlushInstructionCache(kernel.GetCurrentProcess(),ffi.cast("void *",site),5);return end
            ctx.bal_native_context_v3=a
        end
        e.address=a
        memory.write(a+0x3010,ffi.string(ffi.new("uint64_t[1]",frame or 0),8))
        e.cursor=ptr(a+0x3000) or 0
        memory.write(a+0x3018,"\x01")
        archive_line('BAL_CONTEXT_SESSION {"session":"'..session()..'","version":3,"contextPerFrame":false,"chainedVersion":2,"historicalActionAttribution":false,"physicalActionValidated":false}')
    end
    function e.reset()
        e.groups={};e.base=nil;e.ready=false;e.budget=32768;e.epoch=e.epoch+1
        if e.address then e.cursor=ptr(e.address+0x3000) or e.cursor;memory.write(e.address+0x3018,"\x01") end
    end
    function e.drain(ctx,root)
        if not e.address or e.budget<=0 then return end
        local head=ptr(e.address+0x3000)
        if not head then return end
        if head-e.cursor>64 then e.gap("ring-overflow");e.cursor=head-64 end
        while e.cursor<head do
            local seq=e.cursor+1
            local address=e.address+0x4000+(e.cursor%64)*0x20000
            if ptr(address)~=seq or ptr(address+8)~=seq then return end
            local data=read(address,0x20000)
            if not data or ptr(address)~=seq or ptr(address+8)~=seq then return end
            local g=decode(data)
            if g.root~=root then e.gap("root-changed",seq)
            elseif not g.valid then e.gap("invalid-native-copy",seq)
            else
                local key=tostring(root)..":"..tostring(ctx.home_team)..":"..tostring(ctx.away_team)
                g.before.match=key;g.after.match=key;g.match=key;g.epoch=e.epoch
                local before=model.instant(programs(),g.before,2147483834)
                local after=model.instant(programs(),g.after,2147483834)
                if not before or not after then e.gap("instant-model-unavailable",seq)
                else
                    g.beforeNote=before.note;g.afterNote=after.note
                    local metadata='{"session":"'..session()..'","epoch":'..e.epoch..',"match":"'..key..'","sequence":'..seq..',"beforeNote":'..g.beforeNote..',"afterNote":'..g.afterNote..',"virtual":true}'
                    if not writer.write(data,metadata) then
                        e.gap("archive-write-failed",seq);e.budget=0;memory.write(e.address+0x3018,"\x00");return
                    end
                    e.last_gap=nil
                    if e.ready then
                        if #e.groups<1024 then e.groups[#e.groups+1]=g else e.gap("interval-budget",seq) end
                    end
                    e.budget=e.budget-1
                end
            end
            e.cursor=seq
        end
        if e.budget<=0 then e.gap("capture-budget");memory.write(e.address+0x3018,"\x00") end
    end
    function e.checkpoint(input,id,valid)
        local result
        if valid and e.base and e.ready and input.match==e.base.match then
            local groups,good={},true
            for _,g in ipairs(e.groups) do
                if g.match~=input.match or g.epoch~=e.epoch then good=false;break end
                if g.generationBefore>=e.base.generation and g.generationAfter<input.generation then groups[#groups+1]=g
                elseif g.generationBefore<input.generation and g.generationAfter>=input.generation then good=false;break end
            end
            if good then
                result=model.observed_timeline(e.base,input,groups,id)
                if result then
                    result.fromGeneration=e.base.generation;result.epoch=e.epoch
                    result.groupSource="native-observed-context";result.nativeEventSequences={}
                    for _,g in ipairs(groups) do result.nativeEventSequences[#result.nativeEventSequences+1]=g.sequence end
                end
            end
        end
        if valid then
            e.base=input;e.ready=e.address~=nil and e.budget>0
            local future={};for _,g in ipairs(e.groups) do if g.generationBefore>=input.generation then future[#future+1]=g end end;e.groups=future
        else e.base=nil;e.groups={};e.ready=false end
        return result
    end
    return e
end
-- END embedded context collector
function m.init(ctx,api,base)
    kernel=api
    if ctx.bal_native_context_v3 then memory.write(ctx.bal_native_context_v3+0x3018,"\x00") end
    local rounded=ffi.new("float[1]")
    m.model=create_rating_model(function(value) rounded[0]=value;return tonumber(rounded[0]) end)
    m.model=extend_observed_context_model(m.model,function(value)rounded[0]=value;return tonumber(rounded[0])end)
    m.input_groups={}
    m.native_groups={};m.native_chain_ready=false
    m.explanations_ready=false
    prepare_archive()
    local fixture
    m.explanations_ready,fixture=run_rating_selftest(m.model)
    archive_line('BAL_RATING_PATH_SELFTEST {"passed":'..(m.explanations_ready and 'true' or 'false')..',"reference":"original-machine-code-synthetic-fixture"}')
    if m.explanations_ready then m.explanations_ready=m.test_pipeline(fixture) end
    archive_line('BAL_RATING_PIPELINE_SELFTEST {"passed":'..(m.explanations_ready and 'true' or 'false')..',"synthetic":true}')
    m.roles_state=ctx.bal_rating_roles
    m.frame=install_frame_capture(ctx,base)
    m.events=create_event_probe(kernel,read,ptr,json_numbers,archive_line,function()return m.session end,
        function(group)m.queue_native_group(group)end,function()m.native_groups={};m.native_chain_ready=false end)
    m.events.init(ctx,base,m.frame)
    local context_ok=run_observed_context_selftest(m.model)
    archive_line('BAL_CONTEXT_SELFTEST {"passed":'..(context_ok and 'true' or 'false')..',"synthetic":true,"reference":"original-native-normalizer"}')
    if context_ok and m.frame then
        local writer=create_context_archive(kernel,archive_line)
        if writer then
            m.full_context=create_full_context_probe(kernel,read,ptr,archive_line,function()return m.session end,m.model,function()return m.program_tables end,writer,create_context_decoder())
            m.full_context.init(ctx,base,m.frame)
        else log("BAL contexto: codec indisponivel, preservada a captura anterior.") end
    end
    if m.frame then capture=ctx.bal_rating_capture;return end
    if ctx.bal_rating_capture then capture=ctx.bal_rating_capture;return end
    local site=base+0xa1de6c
    local expected="\x4c\x8d\x9c\x24\xc0\x02\x00\x00"
    if memory.read(site,#expected)~=expected then log("BAL rating: captura indisponivel: assinatura diferente.");return end
    for step=1,224 do
        local distance=math.floor((step+1)/2)*0x1000000
        local region=kernel.VirtualAlloc(ffi.cast("void *",base+(step%2==1 and distance or -distance)),4096,0x3000,0x04)
        if region~=nil then
            local a=tonumber(ffi.cast("uintptr_t",region))
            -- Stores nao alteram registradores nem flags. Reproduz a instrucao
            -- original e volta ao epilogo. Slots contem objeto, raiz e constantes.
            local code="\x48\x89\x35"..memory.pack("i32",128-7)
                .."\x4c\x89\x25"..memory.pack("i32",136-14)
                .."\x4c\x89\x3d"..memory.pack("i32",144-21)
                ..expected.."\xe9"..memory.pack("i32",site+8-(a+34))
            memory.write(a,code)
            local previous=ffi.new("uint32_t[1]")
            if kernel.VirtualProtect(region,4096,0x40,previous)~=0 then
                kernel.FlushInstructionCache(kernel.GetCurrentProcess(),region,#code)
                memory.write(site,"\xe9"..memory.pack("i32",a-site-5).."\x90\x90\x90")
                kernel.FlushInstructionCache(kernel.GetCurrentProcess(),ffi.cast("void *",site),8)
                if memory.read(site,8)=="\xe9"..memory.pack("i32",a-site-5).."\x90\x90\x90" then
                    capture=a;ctx.bal_rating_capture=a
                    log("BAL rating: captura passiva da normalizacao instalada.")
                end
            end
            break
        end
    end
end
function m.observe(now,ctx,root,address,data,player_id)
    if ctx.home_team==nil or ctx.away_team==nil or tonumber(data[0x18ec])==255 then return end
    local key=tostring(root)..":"..tostring(ctx.home_team)..":"..tostring(ctx.away_team)
    local words=ffi.cast("uint32_t *",data)
    local counts,reset={},m.observation_key~=key
    local minute=tonumber(data[0x18ed])
    local participation_reset=m.observation_minute and m.observation_minute>=5 and minute<5 or false
    if participation_reset then reset=true end
    for id=0,134 do
        local n=0
        for period=0,7 do n=n+tonumber(words[2+id*9+period]) end
        counts[id+1]=n
        if m.observation_counts and n<m.observation_counts[id+1] then reset=true;participation_reset=true end
    end
    local relative=address-root-0x64d8
    local team=math.floor(relative/0x59650)
    local slot=math.floor((relative-team*0x59650)/0x2134)
    local unq_data=team>=0 and team<=1 and slot>=0 and slot<40
        and read(root-0x750d0+0x180760+(team*40+slot)*16,16)
    local unique,unique_changes={},{}
    if unq_data then
        local u=ffi.cast("uint32_t *",unq_data)
        for id=0,3 do
            unique[id+1]=tonumber(u[id])
            if m.observation_unique and unique[id+1]<m.observation_unique[id+1] then reset=true;participation_reset=true end
        end
    end
    if reset then
        m.observation_counts=nil;m.observation_unique=nil;m.observation_budget=10240
        m.input_groups={};m.path_base=nil;m.last_explanation=nil
        m.native_groups={};m.native_chain_ready=false
        if m.events then m.events.reset() end
        if m.full_context then m.full_context.reset() end
    end
    local note=tonumber(ffi.cast("float *",data)[0x1934/4])
    local changes={}
    for id=0,134 do
        local before=m.observation_counts and m.observation_counts[id+1] or -1
        if before~=counts[id+1] then changes[#changes+1]=json_numbers({id,before,counts[id+1]}) end
    end
    for id=1,#unique do
        local before=m.observation_unique and m.observation_unique[id] or -1
        if before~=unique[id] then unique_changes[#unique_changes+1]=json_numbers({id-1,before,unique[id]}) end
    end
    if (#changes>0 or #unique_changes>0) and m.observation_counts and m.observation_unique and unq_data then
        m.queue_group(m.observation_counts,m.observation_unique,counts,unique)
    end
    if (#changes>0 or #unique_changes>0 or note~=m.observation_note) and (m.observation_budget or 0)>0 then
        local generation=0
        if m.frame and ptr(m.frame+528)==root then
            local seq=read(m.frame+512,4)
            generation=seq and tonumber(ffi.cast("uint32_t *",seq)[0]) or 0
        end
        archive_line('BAL_INPUT_OBSERVATION {"session":"'..tostring(m.session)..'","match":"'..key..'","time":'..string.format("%.6f",now)..',"generation":'..generation..',"player":'..json_numbers({player_id,tonumber(data[0x18ec]),tonumber(data[0x18ed]),note})..',"reset":'..(reset and 'true' or 'false')..',"atomicAction":false,"uniqueAvailable":'..(unq_data and 'true' or 'false')..',"uniqueChanges":['..table.concat(unique_changes,",")..'],"changes":['..table.concat(changes,",")..']}')
        m.observation_budget=m.observation_budget-1
    end
    m.observation_key,m.observation_counts,m.observation_note=key,counts,note
    m.observation_unique=unq_data and unique or nil
    m.observation_minute=minute
    return participation_reset
end
function m.sample(now,ctx,root,player_id,note)
    if (not capture and not m.frame) or now<next_sample then return end
    next_sample=now+0.125
    if m.events then m.events.drain(now,ctx,root) end
    if m.full_context then m.full_context.drain(ctx,root) end
    local obj,stats,constant
    if capture then obj,stats,constant=ptr(capture+128),ptr(capture+136),ptr(capture+144) end
    local frame,sequence=m.frame,nil
    if frame then
        if not note or note<=0 or note>10 then return end
        local seq=read(frame+512,4)
        sequence=seq and tonumber(ffi.cast("uint32_t *",seq)[0])
        if not sequence or sequence==0 or sequence%2~=0 then return end
        obj,stats,constant=ptr(frame+520),ptr(frame+528),ptr(frame+536)
    end
    local owner=obj and ptr(obj+0xbd08)
    local derived=owner and owner>=0x10000 and owner+0x750d0 or nil
    if frame and (stats~=root or derived~=stats) then return end
    if not m.status_logged then
        log("BAL rating: estado da captura objeto="..tostring(obj).." raiz="..tostring(stats).." derivada="..tostring(derived).." partida="..tostring(root).." constantes="..tostring(constant))
        m.status_logged=true
    end
    if stats~=root and derived~=root then
        if not derived then return end
        root=derived
    end
    local live_root=root
    if frame then root=frame+0x1000 end
    local engine_address=frame and frame+0xb4000 or obj and obj+0x1c0
    local config_address=frame and frame+0xb4500 or constant
    local engine,config=read(engine_address,80*16),read(config_address,0x298)
    if not engine or not config then return end
    local cf=ffi.cast("float *",config)
    if not m.config_logged then
        log("BAL rating: constantes base="..tostring(tonumber(cf[0x38/4])).."/"..tostring(tonumber(cf[0x40/4])).." final="..tostring(tonumber(cf[0x260/4])).."/"..tostring(tonumber(cf[0x264/4])))
        m.config_logged=true
    end
    if tonumber(cf[0x38/4])<4 or tonumber(cf[0x38/4])>10 then return end
    if not m.programs_logged then
        local programs={}
        m.program_tables={}
        for _,offset in ipairs({0xbe00,0xca04,0xd608,0xe20c}) do
            local program=read(obj+offset,0xc04)
            if not program then return end
            local count=tonumber(ffi.cast("uint32_t *",program)[0xc00/4])
            if not count or count<1 or count>256 then return end
            local nodes={count=count}
            local words=ffi.cast("uint32_t *",program)
            local floats=ffi.cast("float *",program)
            for i=0,count-1 do
                nodes[i]={t=tonumber(words[i*3]),a=tonumber(words[i*3+1]),b=tonumber(words[i*3+2]),value=tonumber(floats[i*3+1])}
            end
            m.program_tables[#m.program_tables+1]=nodes
            programs[#programs+1]='"'..ffi.string(program,count*12):gsub(".",function(c)return string.format("%02x",string.byte(c))end)..'"'
        end
        archive_line('BAL_RATING_PROGRAMS ['..table.concat(programs,",")..']')
        m.programs_logged=true
    end
    local key=tostring(live_root)..":"..tostring(ctx.home_team)..":"..tostring(ctx.away_team)
    if last_key~=key then
        last_key,last_note,budget,last_snapshot_time=key,nil,96,0
        m.last_generation=nil
        if not m.roles_state or m.roles_state.key~=key then
            m.roles_state={key=key,values={}}
            ctx.bal_rating_roles=m.roles_state
        end
    end
    if frame and m.last_generation==sequence then return end
    -- A nota pode permanecer igual enquanto os pontos internos sao recalculados.
    -- Amostras de acompanhamento permitem verificar esse atraso.
    if budget<=0 or (last_note~=nil and last_note==note and now-last_snapshot_time<10) then return end
    local roles_next={}
    for index,value in pairs(m.roles_state.values) do roles_next[index]=value end
    local rows,model_players,ef={},{},ffi.cast("float *",engine)
    local goal_data=frame and read(frame+0xb6000,0x2000)
    local goal_events={}
    if frame then
        if not goal_data or tonumber(goal_data[0x1ef3])>198 then return end
        local goals_words=ffi.cast("uint32_t *",goal_data)
        for i=0,tonumber(goal_data[0x1ef3])-1 do
            goal_events[#goal_events+1]={tonumber(goals_words[i*10+1]),tonumber(goal_data[i*40+12])}
        end
    end
    local team_signatures,category_sources={},{}
    local scores={0,0}
    local found=false
    local world=ptr(tonumber(ffi.cast("uintptr_t",kernel.GetModuleHandleA("PES2021.exe")))+0x36f3dc8)
    local unique_address=frame and frame+0xb4800 or owner and owner+0x180760
    local unique=read(unique_address,80*16)
    if not world or not unique then return end
    local unique_words=ffi.cast("uint32_t *",unique)
    for team=0,1 do
        local b=read(root+team*0x59650,0x59650)
        if not b then return end
        team_signatures[team+1]=team_signature(b)
        local words=ffi.cast("uint32_t *",b)
        local categories={}
        local teamdata=world and ptr(world+(team+0xa1)*40)
        local formation=world and ptr(world+(team+0xa3)*40)
        local category_address=frame and frame+0xb5000+team*128 or teamdata and teamdata+0x4c00
        local roster_address=frame and frame+0xb5040+team*128 or formation
        local category_data=read(category_address,44)
        local roster_data=read(roster_address,48)
        if not category_data or not roster_data then return end
        category_sources[team+1]={category_address,roster_address,ffi.string(category_data,44),ffi.string(roster_data,48)}
        local cats,roster=ffi.cast("uint32_t *",category_data),ffi.cast("uint32_t *",roster_data)
        for lineup=0,10 do categories[tonumber(roster[lineup+1])]=tonumber(cats[lineup]) end
        for slot=0,39 do
            local off=0x64d8+slot*0x2134
            local started=tonumber(b[off+0x18ec])
            if started~=255 then
                local stats={}
                for id=0,134 do
                    local n=0
                    for period=0,7 do n=n+tonumber(words[off/4+2+id*9+period]) end
                    stats[#stats+1]=n
                end
                scores[team+1]=scores[team+1]+stats[1]-stats[2]
                local role,max_role=13,0
                for roleid=0,12 do
                    local ticks=tonumber(words[(off+0x18fc)/4+roleid])
                    if ticks>max_role then role,max_role=roleid,ticks end
                end
                local i=(team*40+slot)*4
                local values={team,slot,tonumber(words[off/4+1]),started,tonumber(b[off+0x18ed]),role,
                    tonumber(ef[i]),tonumber(ef[i+1]),tonumber(words[(off+0x1934)/4])}
                -- A nota real e float; o ultimo campo deve manter seu valor real.
                values[9]=tonumber(ffi.cast("float *",b)[(off+0x1934)/4])
                values[10]=tonumber(ffi.cast("uint32_t *",engine)[i+2])
                values[11]=tonumber(ffi.cast("uint32_t *",engine)[i+3])
                local role_key=team*40+slot
                if categories[slot]~=nil then
                    roles_next[role_key]={id=values[3],category=categories[slot]}
                end
                local known_role=roles_next[role_key]
                values[12]=known_role and known_role.id==values[3] and known_role.category or -1
                local unq={}
                for id=0,3 do unq[#unq+1]=tonumber(unique_words[i+id]) end
                local team_goals={0,0}
                for _,event in ipairs(goal_events) do
                    if event[1]>=0 and event[1]<=1 and event[2]>=values[4] and event[2]<=values[5] then
                        team_goals[event[1]+1]=team_goals[event[1]+1]+1
                    end
                end
                local active=categories[slot]~=nil and 1 or 0
                rows[#rows+1]='{"v":'..json_numbers(values)..',"s":'..json_numbers(stats)..',"u":'..json_numbers(unq)..',"t":'..json_numbers(team_goals)..',"a":'..active..'}'
                model_players[#model_players+1]={v=values,s=stats,u=unq,t=team_goals,a=active}
                if values[3]==player_id then
                    if frame and math.abs(values[8]-note)>0.001 then return end
                    found=true
                end
            end
        end
    end
    if not found or (not frame and ptr(capture+128)~=obj) then return end
    if frame then
        scores={0,0}
        for _,event in ipairs(goal_events) do
            if event[1]>=0 and event[1]<=1 then scores[event[1]+1]=scores[event[1]+1]+1 end
        end
    end
    local again=read(engine_address,80*16)
    if not again or ffi.string(again,80*16)~=ffi.string(engine,80*16) then return end
    local config_again=read(config_address,0x298)
    if not config_again or ffi.string(config_again,0x298)~=ffi.string(config,0x298) then return end
    for team=0,1 do
        local again_team=read(root+team*0x59650,0x59650)
        if not again_team or team_signature(again_team)~=team_signatures[team+1] then return end
        local source=category_sources[team+1]
        if source then
            local category_again=read(source[1],44)
            local roster_again=read(source[2],48)
            if not category_again or not roster_again
                or ffi.string(category_again,44)~=source[3]
                or ffi.string(roster_again,48)~=source[4] then return end
        end
    end
    if unique then
        local unique_again=read(unique_address,80*16)
        if not unique_again or ffi.string(unique_again,80*16)~=ffi.string(unique,80*16) then return end
    end
    local values={}
    for i=0,0x294/4 do values[#values+1]=tonumber(cf[i]) end
    local settings=world and ptr(world+0x2c0)
    local matchtime=settings and read(settings+0x58,4)
    local duration=matchtime and tonumber(ffi.cast("float *",matchtime)[0]) or 10
    if frame then
        local seq=read(frame+512,4)
        if not seq or tonumber(ffi.cast("uint32_t *",seq)[0])~=sequence then return end
    end
    local event_json={}
    m.roles_state.values=roles_next
    for _,event in ipairs(goal_events) do event_json[#event_json+1]=json_numbers(event) end
    -- Duas leituras iguais nao provam que a captura coincide com a execucao
    -- que produziu o buffer intermediario. Esse vínculo requer validacao.
    archive_line('BAL_RATING_SNAPSHOT {"session":"'..tostring(m.session or "unavailable")..'","schema":'..(frame and '5' or '3')..',"calculation_copy":'..(frame and '1' or '0')..',"match":"'..key..'","generation":'..tostring(sequence or 0)..',"stable_reads":1,"time":'..string.format("%.6f",now)..',"duration":'..string.format("%.9g",duration)..',"score":'..json_numbers(scores)..',"goals":['..table.concat(event_json,",")..'],"constants":'..json_numbers(values)..',"players":['..table.concat(rows,",")..']}')
    if frame and m.model and m.program_tables then
        m.process_input({players=model_players,score=scores,constants=values,duration=duration,match=key,generation=sequence},live_root,player_id,now,true)
    end
    last_note=note or -1;last_snapshot_time=now;budget=budget-1;m.last_generation=sequence
end
function m.queue_group(before_s,before_u,after_s,after_u)
    if #m.input_groups<256 then
        m.input_groups[#m.input_groups+1]={before_s=before_s,before_u=before_u,after_s=after_s,after_u=after_u}
    else m.input_groups={};m.path_base=nil end
end
function m.queue_native_group(group)
    if not m.native_chain_ready then return end
    if #m.native_groups<1024 then m.native_groups[#m.native_groups+1]=group
    else m.native_groups={};m.native_chain_ready=false end
end
function m.test_pipeline(fixture)
    if not fixture then return false end
    m.program_tables=fixture.programs
    m.observation_counts,m.observation_unique=fixture.before.players[1].s,fixture.before.players[1].u
    m.process_input(fixture.before,1,2147483834,0,false)
    for _,g in ipairs(fixture.groups) do m.queue_group(g.before_s,g.before_u,g.after_s,g.after_u) end
    m.observation_counts,m.observation_unique=fixture.after.players[1].s,fixture.after.players[1].u
    local result=m.process_input(fixture.after,1,2147483834,1,false)
    local passed=result and result.total==fixture.expected.total and result.playerEffect==fixture.expected.playerEffect
        and result.remainingEffect==fixture.expected.remainingEffect and m.model.same(result.stateNotes,fixture.expected.stateNotes)
    m.path_base=nil;m.last_explanation=nil;m.input_groups={};m.native_groups={}
    m.events={address=1,budget=1}
    m.observation_counts,m.observation_unique=fixture.before.players[1].s,fixture.before.players[1].u
    m.process_input(fixture.before,1,2147483834,0,false)
    for i,g in ipairs(fixture.groups) do
        m.queue_native_group({before_s=g.before_s,before_u=g.before_u,after_s=g.after_s,after_u=g.after_u,sequence=i,type=31})
    end
    m.observation_counts,m.observation_unique=fixture.after.players[1].s,fixture.after.players[1].u
    local native_result=m.process_input(fixture.after,1,2147483834,1,false)
    passed=passed and native_result and native_result.groupSource=="native-event-boundaries"
        and native_result.total==fixture.expected.total and native_result.playerEffect==fixture.expected.playerEffect
        and native_result.remainingEffect==fixture.expected.remainingEffect and m.model.same(native_result.stateNotes,fixture.expected.stateNotes)
    m.events=nil;m.native_groups={};m.native_chain_ready=false
    m.program_tables,m.path_base,m.last_explanation=nil,nil,nil
    m.observation_counts,m.observation_unique=nil,nil
    m.input_groups={}
    m.test_explanation=passed and result or nil
    return passed and true or false
end
function m.process_input(input,live_root,player_id,now,emit)
    local model_players,sequence,key=input.players,input.generation,input.match
    local returned
    local notes=m.model.normalize(input)
    local checks,valid={},notes~=nil
    local target
    for i,p in ipairs(model_players) do
        local raw=m.model.raw(m.program_tables[m.model.profile[p.v[12]]],p,input)
        if not notes or notes[i]~=p.v[8] or (p.a==1 and raw~=p.v[7]) then valid=false end
        if p.v[3]==player_id then target=p end
        checks[#checks+1]=json_numbers({p.v[3],notes and notes[i] or -999,raw or -999,p.v[8],p.v[7],p.a})
    end
    if emit then archive_line('BAL_LUA_MODEL_CHECK {"session":"'..tostring(m.session)..'","generation":'..tostring(sequence)..',"players":['..table.concat(checks,",")..']}') end
    local observed=m.full_context and m.full_context.checkpoint(input,player_id,valid and target~=nil)
    if observed and observed.from~=observed.to and m.explanations_ready then
        observed.root=live_root;observed.time=now;m.last_explanation=observed;returned=observed
        local parts={}
        for _,part in ipairs(observed.components) do parts[#parts+1]='{"label":"'..part.label..'","effect":'..part.effect..',"source":"'..part.source..'","sequence":'..part.sequence..'}' end
        if emit then archive_line('BAL_RATING_EXPLANATION {"session":"'..m.session..'","match":"'..key..'","epoch":'..observed.epoch..',"generation":'..sequence..',"fromGeneration":'..observed.fromGeneration..',"from":'..observed.from..',"to":'..observed.to..',"total":'..observed.total..',"playerEffect":'..observed.playerEffect..',"remainingEffect":'..observed.remainingEffect..',"eventEffect":'..observed.eventEffect..',"contextEffect":'..observed.contextEffect..',"stateNotes":'..json_numbers(observed.stateNotes)..',"components":['..table.concat(parts,",")..'],"groupSource":"native-observed-context","nativeEventSequences":'..json_numbers(observed.nativeEventSequences)..',"definition":"native-event-marginals-at-observed-context","historicalActionAttribution":false,"physicalActionValidated":false}') end
    end
    local aligned=valid and target and m.model.same(target.s,m.observation_counts) and m.model.same(target.u,m.observation_unique)
    if aligned then
        if not observed and m.explanations_ready and m.path_base then
            local result
            if m.native_chain_ready then
                result=m.model.path(m.program_tables,m.path_base,input,m.native_groups,player_id)
                if result then
                    result.groupSource="native-event-boundaries";result.nativeEventSequences={}
                    for _,g in ipairs(m.native_groups) do result.nativeEventSequences[#result.nativeEventSequences+1]=g.sequence end
                end
            end
            if not result then
                result=m.model.path(m.program_tables,m.path_base,input,m.input_groups,player_id)
                if result then result.groupSource="sampled-input-groups";result.nativeEventSequences={} end
            end
            if result and result.from~=result.to then
                result.root=live_root;result.time=now;result.fromGeneration=m.path_base.generation;m.last_explanation=result;returned=result
                local details={}
                for _,part in ipairs(result.components) do
                    details[#details+1]='{"label":"'..part.label..'","effect":'..string.format("%.9g",part.effect)..'}'
                end
                if emit then archive_line('BAL_RATING_EXPLANATION {"session":"'..tostring(m.session)..'","match":"'..key..'","generation":'..tostring(sequence)..',"fromGeneration":'..result.fromGeneration..',"from":'..result.from..',"to":'..result.to..',"total":'..result.total..',"playerEffect":'..result.playerEffect..',"remainingEffect":'..result.remainingEffect..',"stateNotes":'..json_numbers(result.stateNotes)..',"components":['..table.concat(details,",")..'],"groupSource":"'..result.groupSource..'","nativeEventSequences":'..json_numbers(result.nativeEventSequences)..',"definition":"observed-input-order-with-current-context-fixed","historicalActionAttribution":false}') end
            end
        end
        m.path_base=input;m.input_groups={};m.native_groups={}
        m.native_chain_ready=m.events and m.events.address~=nil and m.events.budget>0 or false
    elseif not valid then m.path_base=nil;m.input_groups={};m.native_groups={};m.native_chain_ready=false end
    return returned
end
function m.explanation(root,from,to,now)
    local e=m.last_explanation
    if e and e.root==root and e.from==from and e.to==to and now-e.time<2 then return e end
end
function m.finish_display_test(passed)
    m.explanations_ready=m.explanations_ready and passed
    m.test_explanation=nil
    archive_line('BAL_RATING_DISPLAY_SELFTEST {"passed":'..(passed and 'true' or 'false')..',"synthetic":true}')
end
return m

end)()
local kernel, counter, frequency
local window_start, last_frame, frame_count = nil, nil, 0
local fps, sample_logged
local sample_next = 0
local stats_capture
local sider_base, width_slot, narrow_background
local user32, gdi32, measure_dc, measure_font, measure_size, client_rect
local last_text, expanded = nil, false
local opts = { text_color = "ffb34dff", background_color = "00000080", location = "top" }

local function save_status(text)
    log(text)
end

local function wide_ascii(text)
    return (text:gsub(".", function(c) return c .. "\0" end)) .. "\0\0"
end

local player_id = 2147483834
local player_name = "R. CERQUEIRA"
local player_note, player_counts, player_key, player_address, comparison_note
local note_history, last_note_text, recent_action, recent_action_time = {}, nil, nil, nil
local pending_note
local reader_message = "Aguardando estatisticas do PES"
local function comma(value, signed)
    return (string.format(signed and "%+.1f" or "%.1f", value):gsub("%.", ","))
end
local function isolated_name(label)
    return label.." (contexto fixo)"
end
local function migrate_explanation_text(text)
    return text:gsub("Sem isolamento", "Causa nao identificada")
        :gsub(" isolados", " (contexto fixo)"):gsub(" isoladas", " (contexto fixo)")
        :gsub(" isolado", " (contexto fixo)"):gsub(" isolada", " (contexto fixo)")
end
local function note_transition(previous,current)
    if not current or current~=current or current<=0 or current>10 then return "invalid",previous end
    if not previous then return "first",current end
    local delta=current-previous
    if math.abs(delta)>=0.049 then return "change",current,delta end
    return "same",current
end
local function format_explanation(delta,e)
    if e.definition=="native-event-marginals-at-observed-context" then
        local reason=#e.components==0 and "Contexto da partida" or (#e.components==1 and e.components[1].label or "Efeitos combinados")
        local compact=comma(delta,true).." "..reason
        local lines={}
        for _,part in ipairs(e.components) do lines[#lines+1]=comma(part.effect,true).." "..part.label end
        local history=#lines>0 and table.concat(lines,"\n") or compact
        return compact,history
    end
    local reason=#e.components==0 and "Contexto da partida" or (#e.components==1 and e.remainingEffect==0 and isolated_name(e.components[1].label) or "Efeitos combinados")
    local compact=comma(delta,true).." "..reason
    local lines={}
    for _,part in ipairs(e.components) do lines[#lines+1]=comma(part.effect,true).." "..isolated_name(part.label) end
    if e.remainingEffect~=0 then lines[#lines+1]=comma(e.remainingEffect,true).." Contexto da partida" end
    local history=#lines>0 and table.concat(lines,"\n") or compact
    return compact,history
end
local function test_note_transitions()
    -- Regressao do caso relatado: --, --, 7, 8, 8.5; leitura temporariamente
    -- indisponivel nao cria uma nova nota inicial nem apaga a comparacao.
    local values={0,0,7,8,8.5,0,8.5,9}
    local kinds={"invalid","invalid","first","change","change","invalid","same","change"}
    local deltas={0,0,0,1,0.5,0,0,0.5}
    local previous
    for i=1,#values do
        local kind,next_note,delta=note_transition(previous,values[i])
        if kind~=kinds[i] or math.abs((delta or 0)-deltas[i])>0.001 then return false end
        previous=next_note
    end
    local kind,first=note_transition(nil,7)
    return kind=="first" and first==7
end
local action_fields = {
    {0,"Gol"},{4,"Assistencia"},{1,"Gol contra"},{58,"Cartao vermelho"},
    {57,"Cartao amarelo"},{56,"Impedimento"},{55,"Falta"},
    {17,"Chute no gol"},{6,"Finalizacao"},{77,"Bola recuperada"},
    {89,"Perda da bola"},{31,"Cruzamento certo"},{27,"Passe em profundidade certo"},
    {29,"Passe longo certo"},{25,"Passe rasteiro certo"},{50,"Desarme certo"},
}
local function sample_player(now, ctx)
    if now < sample_next then return end
    sample_next = now + 0.125
    local process = kernel.GetCurrentProcess()
    local function read(address, size)
        if not address or address < 0x10000 or address > 0x7fffffffffff then return nil end
        local data, used = ffi.new("uint8_t[?]", size), ffi.new("uintptr_t[1]")
        if kernel.ReadProcessMemory(process, ffi.cast("const void *", address), data, size, used) == 0 or tonumber(used[0]) ~= size then return nil end
        return data
    end
    local captured = stats_capture and read(stats_capture + 64,8)
    local manager = captured and tonumber(ffi.cast("uint64_t *",captured)[0])
    if not manager or manager < 0x10000 then reader_message="Aguardando estatisticas do PES";return end
    local root = manager + 0x750d0
    local key = tostring(manager)..":"..tostring(ctx.home_team)..":"..tostring(ctx.away_team)
    if key ~= player_key then
        player_key, player_note, player_counts, player_address, comparison_note = key,nil,nil,nil,nil
        note_history, last_note_text, recent_action, recent_action_time = {},nil,nil,nil
        pending_note=nil
    end
    local data = player_address and read(player_address,0x2134)
    if not data or tonumber(ffi.cast("uint32_t *",data)[1]) ~= player_id then
        data, player_address = nil, nil
        for team=0,1 do
            for slot=0,39 do
                local address = root + team*0x59650 + 0x64d8 + slot*0x2134
                local head = read(address,8)
                if head and tonumber(ffi.cast("uint32_t *",head)[1]) == player_id then
                    player_address = address
                    data = read(address,0x2134)
                    break
                end
            end
            if data then break end
        end
    end
    if not data then player_note=nil;reader_message="Jogador fora desta partida";return end
    local integers, floats = ffi.cast("uint32_t *",data), ffi.cast("float *",data)
    local counts={}
    for _,field in ipairs(action_fields) do
        local total=0
        for period=0,7 do total=total+tonumber(integers[2+field[1]*9+period]) end
        counts[field[1]]=total
    end
    if player_counts then
        for index,value in pairs(counts) do
            if value < player_counts[index] then
                player_note,player_counts,comparison_note=nil,nil,nil
                note_history,last_note_text,recent_action,recent_action_time={},nil,nil,nil
                pending_note=nil
                break
            end
        end
    end
    if player_counts then
        local changed={}
        for _,field in ipairs(action_fields) do
            if counts[field[1]] > player_counts[field[1]] then
                changed[#changed+1]=field
            end
        end
        if #changed>0 then
            local labels={}
            local goal=counts[0]>player_counts[0]
            local shot=counts[17]>player_counts[17]
            for _,field in ipairs(changed) do
                if not (goal and (field[1]==6 or field[1]==17)) and not (shot and field[1]==6) then labels[#labels+1]=field[2] end
            end
            recent_action, recent_action_time=#labels==1 and labels[1] or "acoes combinadas",now
        end
    end
    local note=tonumber(floats[1613])
    if rating_capture then
        local new_participation=rating_capture.observe(now,ctx,root,player_address,data,player_id)
        if new_participation then
            player_note,comparison_note=nil,nil
            note_history,last_note_text,recent_action,recent_action_time={},nil,nil,nil
            pending_note=nil
        end
        rating_capture.sample(now,ctx,root,player_id,note)
    end
    local transition,next_comparison,delta=note_transition(comparison_note,note)
    local previous_comparison=comparison_note
    comparison_note=next_comparison
    if transition~="invalid" then
        if transition=="change" then
            last_note_text=comma(delta,true).." Causa nao identificada"
            pending_note={root=root,from=previous_comparison,to=note,delta=delta}
            table.insert(note_history,1,last_note_text)
            if #note_history > 60 then table.remove(note_history) end
            save_status("Nota original "..comma(note).."; "..last_note_text)
        elseif transition=="first" then
            pending_note=nil
            last_note_text=string.format("%.1f Nota inicial",note)
            table.insert(note_history,1,last_note_text)
            save_status("Primeira nota original "..comma(note).."; sem nota anterior para comparar.")
        end
        player_note, reader_message=note,"Nota original do PES"
    else
        player_note=nil;reader_message="PES ainda nao calculou a nota"
    end
    if pending_note and not pending_note.done and note==pending_note.to then
        local e=rating_capture and rating_capture.explanation(root,pending_note.from,pending_note.to,now)
        if e then
            local history
            last_note_text,history=format_explanation(pending_note.delta,e)
            note_history[1]=history;pending_note.done=true
            save_status("Explicacao isolada conferida "..last_note_text)
        end
    end
    player_counts=counts
    ctx.bal_note_state={key=player_key,address=player_address,note=player_note,comparison=comparison_note,counts=player_counts,history=note_history,last=last_note_text,action=recent_action,action_time=recent_action_time,pending=pending_note}

end



local function compact_header()
    -- Sider 7.4.1 x64: modifica apenas uma string de formato na memoria.
    -- Os tres argumentos continuam consumidos; aparece somente o texto do modulo.
    -- O binario sider.dll no disco permanece intacto.
    local base = kernel.GetModuleHandleA("sider.dll")
    if base == nil then return false end
    local address = tonumber(ffi.cast("uintptr_t", base)) + 0x1624f8
    local expected = wide_ascii("%s | %s | %s")
    local replacement = wide_ascii("%.0s%.0s%s")
    replacement = replacement .. string.rep("\0", #expected - #replacement)
    local current = memory.read(address, #expected)
    if current:sub(1, #wide_ascii("%.0s%.0s%s")) == wide_ascii("%.0s%.0s%s") then return true end
    if current ~= expected then return false end
    memory.write(address, replacement)
    return memory.read(address, #expected) == replacement
end

local function prepare_background()
    -- draw_ui: rc.right recebe a largura da tela. Redireciona somente essa
    -- leitura para quatro bytes livres depois do terminador do formato.
    -- Toda a alteracao ocorre na memoria desta copia do Sider 7.4.1 x64.
    local address = sider_base + 0x250fc
    local expected = "\x8b\x05\xb6\xbb\x18\x00\x89\x84\x24\x80\x00\x00\x00\x8b\x05\xad\xbb\x18\x00"
    local patched = "\x8b\x05\x0c\xd4\x13\x00" .. expected:sub(7)
    local current = memory.read(address, #expected)
    if current ~= expected and current ~= patched then return false end
    width_slot = sider_base + 0x16250e
    memory.write(width_slot, memory.pack("i32", 300))
    if current == expected then memory.write(address + 2, "\x0c\xd4\x13\x00") end
    return memory.read(address, #patched) == patched
end

local function fit_background(text)
    if not narrow_background or text == last_text then return end
    local width = 100
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local wide = wide_ascii(line)
        if measure_dc and gdi32.GetTextExtentPoint32W(measure_dc, ffi.cast("const uint16_t *", wide), #line, measure_size) ~= 0 then
            width = math.max(width, tonumber(measure_size[0]) + 18)
        else
            width = math.max(width, #line * 16 + 18)
        end
    end
    local window = user32.GetForegroundWindow()
    if window ~= nil and user32.GetClientRect(window, client_rect) ~= 0 then
        local screen_width = tonumber(client_rect[2] - client_rect[0])
        if screen_width > 320 then width = math.min(width, screen_width) end
    end
    memory.write(width_slot, memory.pack("i32", math.floor(width)))
    last_text = text
end

function m.display_frame(ctx)
    if not counter then return end
    if kernel.QueryPerformanceCounter(counter) == 0 then return end
    local now = tonumber(counter[0]) / frequency
    sample_player(now, ctx)
    if not window_start or (last_frame and now - last_frame > 1) then
        window_start, last_frame, frame_count, fps = now, now, 0, nil
        return
    end
    last_frame = now
    frame_count = frame_count + 1
    local elapsed = now - window_start
    if elapsed >= 0.5 then
        fps = frame_count / elapsed
        frame_count, window_start = 0, now
        if not sample_logged then
            local sample = string.format("BAL Painel 0.13: primeira amostra %.1f FPS (display_frame/QPC).", fps)
            log(sample)
            save_status(sample)
            sample_logged = true
        end
    end
end

function m.show(ctx)
    expanded = false
    save_status("Painel mostrado pelo atalho do Sider.")
end

function m.key_up(ctx, vkey)
    if vkey == 0x77 then
        expanded = not expanded
        save_status(expanded and "F8: historico aberto." or "F8: painel basico.")
    end
end

function m.hide(ctx)
    save_status("Painel ocultado pelo atalho do Sider.")
end

function m.overlay_on(ctx)
    local text = fps and fps > 0 and string.format("FPS %.0f",fps) or "FPS --"
    text=text.."\n"..(player_note and comma(player_note) or "--")
    if expanded then
        text=text.."\nHistorico da nota"
        if #note_history == 0 then text=text.."\nNenhuma alteracao ainda" end
        for _,change in ipairs(note_history) do
            -- Older cached entries contain a summary followed by indented effects.
            if change:find("\n  ",1,true) then change=change:match("\n(.*)$"):gsub("^%s+",""):gsub("\n%s+","\n") end
            text=text.."\n"..change
        end
    elseif last_note_text then
        text=text.."\n"..last_note_text
    end
    fit_background(text)
    return text,nil,opts
end

function m.init(ctx)
    log(test_note_transitions() and "BAL rating: 9 testes de transicao aprovados." or "BAL rating: falha no teste de transicao.")
    if ctx.bal_note_state then
        local state=ctx.bal_note_state
        player_key,player_address,player_note,player_counts=state.key,state.address,state.note,state.counts
        comparison_note=state.comparison or state.note
        pending_note=state.pending
        note_history,last_note_text,recent_action,recent_action_time=state.history,state.last,state.action,state.action_time
        local initial=state.note
        for _,entry in ipairs(note_history) do
            local delta=entry:match("^([%+%-]%d+[,.]%d+)")
            if delta and initial then initial=initial-tonumber((delta:gsub(",","."))) end
        end
        for i,text in ipairs(note_history) do
            if text:find("Primeira nota registrada",1,true) then
                local recorded=text:match("^(%d+[,.]%d+)")
                local value=recorded and tonumber((recorded:gsub(",","."))) or initial
                if value then text=string.format("%.1f Nota inicial",value) end
            end
            note_history[i]=text:gsub(" | ", " "):gsub("%*", ""):gsub(" apos .*$", " Sem isolamento"):gsub(" Atualizacao do PES$", " Sem isolamento"):gsub("Outros fatores", "Contexto da partida")
        end
        if last_note_text then last_note_text=last_note_text:gsub(" | ", " "):gsub("%*", ""):gsub(" apos .*$", " Sem isolamento"):gsub(" Atualizacao do PES$", " Sem isolamento"):gsub("Outros fatores", "Contexto da partida") end
        for i,text in ipairs(note_history) do note_history[i]=migrate_explanation_text(text) end
        if last_note_text then last_note_text=migrate_explanation_text(last_note_text) end
    end
    if ffi then
        ffi.cdef[[
            int __stdcall QueryPerformanceCounter(int64_t *value);
            int __stdcall QueryPerformanceFrequency(int64_t *value);
            void * __stdcall GetModuleHandleA(const char *name);
            void * __stdcall GetCurrentProcess(void);
            int __stdcall ReadProcessMemory(void *process, const void *address, void *buffer, uintptr_t size, uintptr_t *read);
            uint32_t __stdcall GetModuleFileNameW(void *module, uint16_t *path, uint32_t length);
            uint32_t __stdcall GetCurrentProcessId(void);
            void * __stdcall CreateFileW(const uint16_t *path, uint32_t access, uint32_t share,
                void *security, uint32_t creation, uint32_t flags, void *template_file);
            int __stdcall WriteFile(void *file, const void *buffer, uint32_t size, uint32_t *written, void *overlapped);
            int __stdcall CloseHandle(void *handle);
            void * __stdcall VirtualAlloc(void *address, uintptr_t size, uint32_t allocation, uint32_t protection);
            int __stdcall VirtualProtect(void *address, uintptr_t size, uint32_t protection, uint32_t *previous);
            int __stdcall FlushInstructionCache(void *process, const void *address, uintptr_t size);
            void * __stdcall GetForegroundWindow(void);
            int __stdcall GetClientRect(void *window, void *rect);
            void * __stdcall CreateCompatibleDC(void *dc);
            void * __stdcall CreateFontA(int height, int width, int escapement, int orientation, int weight,
                uint32_t italic, uint32_t underline, uint32_t strikeout, uint32_t charset, uint32_t precision,
                uint32_t clip, uint32_t quality, uint32_t pitch, const char *name);
            void * __stdcall SelectObject(void *dc, void *object);
            int __stdcall GetTextExtentPoint32W(void *dc, const uint16_t *text, int length, void *size);
        ]]
        kernel = ffi.load("kernel32")
        local game_base = tonumber(ffi.cast("uintptr_t", kernel.GetModuleHandleA("PES2021.exe")))
        rating_capture.init(ctx,kernel,game_base)
        local example=rating_capture.test_explanation
        local display_ok=false
        if example then
            local compact,history=format_explanation(example.total,example)
            display_ok=compact=="+1,0 Efeitos combinados" and history=="+0,5 Gol (contexto fixo)\n+0,5 Contexto da partida"
        end
        local observed_example={definition="native-event-marginals-at-observed-context",remainingEffect=0.5,components={{label="Gol",effect=0.5,source="event"},{label="Placar",effect=0.5,source="context"}}}
        local observed_compact,observed_history=format_explanation(1,observed_example)
        display_ok=display_ok and observed_compact=="+1,0 Efeitos combinados" and observed_history=="+0,5 Gol\n+0,5 Placar"
        local context_example={definition="native-event-marginals-at-observed-context",remainingEffect=-0.5,components={}}
        local context_compact,context_history=format_explanation(-0.5,context_example)
        display_ok=display_ok and context_compact=="-0,5 Contexto da partida" and context_history==context_compact
        rating_capture.finish_display_test(display_ok)
        local getter = game_base + 0xa3e8a0
        local expected_getter = "\x48\x8d\x81\xd0\x50\x07\x00\xc3"
        local actual_getter = memory.read(getter,8)
        save_status("Getter observado: " .. (actual_getter:gsub(".",function(c)return string.format("%02x",string.byte(c))end)))
        if ctx.bal_stats_capture then
            stats_capture = ctx.bal_stats_capture
        elseif memory.read(getter, 8) == expected_getter then
            -- Captura passiva do argumento do getter original; mesma saida e registradores.
            -- 7 bytes mov [rip+39h],rcx; os 8 bytes originais; slot no offset 64.
            for step=1,224 do
                local distance=math.floor((step+1)/2)*0x1000000
                local target=game_base + (step%2==1 and distance or -distance)
                local region = kernel.VirtualAlloc(ffi.cast("void *", target),4096,0x3000,0x04)
                if region ~= nil then
                    local address = tonumber(ffi.cast("uintptr_t",region))
                    memory.write(address, "\x48\x89\x0d\x39\x00\x00\x00" .. expected_getter)
                    local previous=ffi.new("uint32_t[1]")
                    if kernel.VirtualProtect(region,4096,0x40,previous) ~= 0 then
                        memory.write(getter,"\xe9"..memory.pack("i32",address-getter-5).."\x90\x90\x90")
                        if memory.read(getter,1)=="\xe9" then
                            stats_capture = address
                            ctx.bal_stats_capture = address
                            save_status("Captura passiva do getter de estatisticas ativada.")
                        end
                    end
                    break
                end
            end
        end
        user32, gdi32 = ffi.load("user32"), ffi.load("gdi32")
        local base = kernel.GetModuleHandleA("sider.dll")
        if base ~= nil then sider_base = tonumber(ffi.cast("uintptr_t", base)) end
        client_rect, measure_size = ffi.new("int32_t[4]"), ffi.new("int32_t[2]")
        if ctx.bal_panel_measure then
            measure_dc, measure_font = ctx.bal_panel_measure.dc, ctx.bal_panel_measure.font
        else
            measure_dc = gdi32.CreateCompatibleDC(nil)
            measure_font = gdi32.CreateFontA(24, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 4, 1, "Lucida Console")
            if measure_dc ~= nil and measure_font ~= nil then
                gdi32.SelectObject(measure_dc, measure_font)
                ctx.bal_panel_measure = {dc = measure_dc, font = measure_font}
            end
        end
        local freq = ffi.new("int64_t[1]")
        if kernel.QueryPerformanceFrequency(freq) ~= 0 and tonumber(freq[0]) > 0 then
            frequency, counter = tonumber(freq[0]), ffi.new("int64_t[1]")
            ctx.register("display_frame", m.display_frame)
        end
        local compact = compact_header()
        if compact and sider_base then narrow_background = prepare_background() end
        local message = "BAL Painel 0.13: cabecalho compacto " .. (compact and "aplicado." or "nao aplicado: versao diferente ou formato inesperado.")
        log(message)
        save_status(message)
        save_status(narrow_background and "Fundo limitado a largura do texto." or "Fundo compacto indisponivel para este binario.")
    end
    ctx.register("overlay_on", m.overlay_on)
    ctx.register("show", m.show)
    ctx.register("hide", m.hide)
    ctx.register("key_up", m.key_up)
    log("BAL Painel 0.13: FPS; F8 alterna historico. Nota original extraida da memoria do jogo.")
    save_status("Painel 0.13 ativo. F6 mostra/oculta; F8 alterna historico; inicia oculto.")
end

return m
