local F=function(x)return (string.unpack("f",string.pack("f",x)))end
local model=extend_observed_context_model(create_rating_model(F),F)
assert(run_observed_context_selftest(model),"Existing native-reference fixture failed")
local function state(counter,note,minute,actor)
    local players={}
    for slot=0,1 do
        local stats={};for i=1,135 do stats[i]=0 end
        stats[23]=(slot==0 and counter or actor or 0)
        players[#players+1]={a=1,v={0,slot,slot==0 and 2147483834 or 2,0,minute or 44,12,0,note,note,100,0,9},s=stats,u={0,0,0,0},t={0,0}}
    end
    return {generation=70,match="retention-match",duration=10,constants={1},score={0,0},players=players}
end
local function group(sequence,generation,a,b,from,to)
    return {sequence=sequence,generationBefore=generation,generationAfter=generation,
        valid=true,epoch=0,match=a.match,before=a,after=b,beforeNote=from,afterNote=to}
end
local function equal(a,b)
    assert(type(a)==type(b),"Different result type")
    if type(a)=="table" then
        for k,v in pairs(a) do equal(v,b[k]) end
        for k in pairs(b) do assert(a[k]~=nil,"Unexpected result key") end
    else assert(a==b,"Different result value "..tostring(a).." / "..tostring(b)) end
end
memory={write=function()end}
local e=create_full_context_probe(nil,nil,function()return 4097 end,function()end,function()return "test" end,model)
local original={}
local before=state(0,6)
for i=1,4096 do
    local from=i<=3000 and 6 or 6.5
    local to=i<3000 and 6 or 6.5
    local a,b=state(i-1,from),state(i,to)
    local g=group(i,70,a,b,from,to)
    original[#original+1]=group(i,70,a,b,from,to)
    e.retain(g)
end
local after=state(4096,6.5,45);after.generation=72
local expected=model.observed_timeline(before,after,original,2147483834)
local actual=model.observed_timeline(before,after,e.groups,2147483834)
assert(expected and actual,"Missing interval result")
equal(actual,expected)
assert(#e.groups==4096,"Events discarded")
local full=0
for _,g in ipairs(e.groups) do
    if g.before.players[1].s then full=full+1 end
    if g.after.players[1].s then full=full+1 end
end
assert(full==2,"Intermediate contexts retained")
e.base=before;e.ready=true;e.address=1
local futureBefore=state(4096,6.5,45)
local futureAfter=state(4096,7,46,1)
e.retain(group(4097,72,futureBefore,futureAfter,6.5,7))
local result=e.checkpoint(after,2147483834,true)
equal(result.components,expected.components)
assert(#e.groups==1 and e.groups[1].before.players[1].s,"Future generation lost its first context")
local secondAfter=state(4096,7,46,1);secondAfter.generation=74
local second=e.checkpoint(secondAfter,2147483834,true)
assert(second and second.total==0.5 and second.components[1].label=="Jogo coletivo","Halftime/future context differs")
e.gap("synthetic-loss",4098)
assert(not e.checkpoint(secondAfter,2147483834,true),"Missing evidence produced explanation")
e.reset()
assert(#e.groups==0 and not e.base and not e.ready,"Reset retained match data")
assert(loadfile(moduleFile),"Module syntax failed")
print("Retention passed: 4096 events, 2 full contexts, exact timeline, future generation, gap and reset")
