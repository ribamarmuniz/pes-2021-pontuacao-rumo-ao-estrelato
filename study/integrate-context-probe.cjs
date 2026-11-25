// One-time, assertion-checked integration of observed-context captures.
const fs=require('fs'),path=require('path');
const moduleFile=path.join(__dirname,'..','modules','bal_painel.lua');let source=fs.readFileSync(moduleFile,'utf8');
function replace(a,b){if(!source.includes(a))throw Error('Integration anchor absent: '+a.slice(0,100));source=source.replace(a,b);}
replace('local m = { version = "0.10" }','local m = { version = "0.11" }');
replace('if memory.read(site,5)~="\\xe8"..memory.pack("i32",a-site-5)',
 'if memory.read(site,5)~="\\xe8"..memory.pack("i32",(ctx.bal_native_context_v3 or a)-site-5)');
replace('    kernel=api\n    local rounded=', '    kernel=api\n    if ctx.bal_native_context_v3 then memory.write(ctx.bal_native_context_v3+0x3018,"\\x00") end\n    local rounded=');
replace('    m.input_groups={}\n    m.native_groups={};m.native_chain_ready=false',
 '    m.model=extend_observed_context_model(m.model,function(value)rounded[0]=value;return tonumber(rounded[0])end)\n    m.input_groups={}\n    m.native_groups={};m.native_chain_ready=false');
replace('    m.events.init(ctx,base,m.frame)\n',
 '    m.events.init(ctx,base,m.frame)\n    local context_ok=run_observed_context_selftest(m.model)\n    archive_line(\'BAL_CONTEXT_SELFTEST {"passed":\'..(context_ok and \'true\' or \'false\')..\',"synthetic":true,"reference":"original-native-normalizer"}\')\n    if context_ok and m.frame then\n        local ok,writer=pcall(create_context_archive,kernel,archive_line)\n        if ok and writer then\n            m.full_context=create_full_context_probe(kernel,read,ptr,archive_line,function()return m.session end,m.model,function()return m.program_tables end,writer,create_context_decoder())\n            m.full_context.init(ctx,base,m.frame)\n        else log("BAL contexto: codec indisponivel, preservada a captura anterior.") end\n    end\n');
replace('        if m.events then m.events.reset() end',
 '        if m.events then m.events.reset() end\n        if m.full_context then m.full_context.reset() end');
replace('    if m.events then m.events.drain(now,ctx,root) end',
 '    if m.events then m.events.drain(now,ctx,root) end\n    if m.full_context then m.full_context.drain(ctx,root) end');
replace('    local aligned=valid and target and m.model.same(target.s,m.observation_counts)',
 `    local observed=m.full_context and m.full_context.checkpoint(input,player_id,valid and target~=nil)
    if observed and observed.from~=observed.to and m.explanations_ready then
        observed.root=live_root;observed.time=now;m.last_explanation=observed;returned=observed
        local parts={}
        for _,part in ipairs(observed.components) do parts[#parts+1]='{"label":"'..part.label..'","effect":'..part.effect..',"source":"'..part.source..'","sequence":'..part.sequence..'}' end
        if emit then archive_line('BAL_RATING_EXPLANATION {"session":"'..m.session..'","match":"'..key..'","epoch":'..observed.epoch..',"generation":'..sequence..',"fromGeneration":'..observed.fromGeneration..',"from":'..observed.from..',"to":'..observed.to..',"total":'..observed.total..',"playerEffect":'..observed.playerEffect..',"remainingEffect":'..observed.remainingEffect..',"eventEffect":'..observed.eventEffect..',"contextEffect":'..observed.contextEffect..',"stateNotes":'..json_numbers(observed.stateNotes)..',"components":['..table.concat(parts,",")..'],"groupSource":"native-observed-context","nativeEventSequences":'..json_numbers(observed.nativeEventSequences)..',"definition":"native-event-marginals-at-observed-context","historicalActionAttribution":false,"physicalActionValidated":false}') end
    end
    local aligned=valid and target and m.model.same(target.s,m.observation_counts)`);
replace('        if m.explanations_ready and m.path_base then','        if not observed and m.explanations_ready and m.path_base then');
replace('    local reason=#e.components==0 and "Outros fatores"',
 `    if e.definition=="native-event-marginals-at-observed-context" then
        local reason=#e.components==1 and e.components[1].label or "Efeitos combinados"
        local compact=comma(delta,true).." "..reason
        local history=compact
        for _,part in ipairs(e.components) do history=history.."\\n  "..comma(part.effect,true).." "..part.label end
        return compact,history
    end
    local reason=#e.components==0 and "Outros fatores"`);
// The public module carries its own version as well.
source=source.replace(/version\s*=\s*"0\.10"/g,'version = "0.11"');
fs.writeFileSync(moduleFile,source);console.log(JSON.stringify({integrated:true,bytes:Buffer.byteLength(source)}));
