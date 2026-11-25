local m = { version = "1.0" }

function m.init(ctx)
    if not ffi then
        log("BAL afinidade: FFI indisponivel; usar o iniciador com mascara FFF.")
        return
    end
    ffi.cdef[[
        void * __stdcall GetCurrentProcess(void);
        int __stdcall SetProcessAffinityMask(void *process, uintptr_t mask);
    ]]
    local kernel = ffi.load("kernel32")
    local ok = kernel.SetProcessAffinityMask(kernel.GetCurrentProcess(), 0xfff)
    if ok ~= 0 then
        log("BAL afinidade: processadores 0 a 11 aplicados ao PES (FFF).")
    else
        log("BAL afinidade: Windows nao confirmou a mascara FFF.")
    end
end

return m
