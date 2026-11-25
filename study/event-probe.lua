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
return create_event_probe
