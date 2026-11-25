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
return create_context_decoder
