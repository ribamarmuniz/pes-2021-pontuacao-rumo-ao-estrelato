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
return create_context_archive
