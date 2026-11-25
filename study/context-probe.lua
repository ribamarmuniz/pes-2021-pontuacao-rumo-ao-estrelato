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
return create_full_context_probe
