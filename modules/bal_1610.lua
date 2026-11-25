-- Aspect-ratio technique: Durandil67; Sider adaptation published by eskay993.
-- https://github.com/eskay993/gamefiles/tree/main/sp-football-life-2023
-- This variant checks the surrounding bytes observed in the user's executable.
local m = { version = "0.2" }

function m.init(ctx)
    local signature = "\x80\x7b\x7c\x00\x0f\x28"
    local expected = "\x80\x7b\x7c\x00\x0f\x28\x74\x24\x20\x75\x06\x80\x7b\x7d\x00\x74\x08"
    local already_patched = "\x80\x7b\x7c\x01\x0f\x28\x74\x24\x20\x75\x06\x80\x7b\x7d\x00\x74\x08"
    local addr, section = memory.search_process(signature)
    if not addr then
        if memory.search_process(already_patched) then
            log("BAL 16:10: correcao ja presente nesta sessao.")
        else
            log("BAL 16:10: assinatura nao encontrada. Nenhuma alteracao aplicada.")
        end
        return
    end
    if not section or addr + #expected > section.finish then
        log("BAL 16:10: trecho incompleto. Nenhuma alteracao aplicada.")
        return
    end
    if memory.read(addr, #expected) ~= expected then
        log("BAL 16:10: trecho diferente do executavel conferido. Nenhuma alteracao aplicada.")
        return
    end
    -- Exactly the byte changed by the published fix; process memory only.
    memory.write(addr + 3, "\x01")
    if memory.read(addr, #already_patched) == already_patched then
        log("BAL 16:10: correcao aplicada em " .. memory.hex(addr) .. ". Testar dentro da partida.")
    else
        log("BAL 16:10: escrita nao confirmada.")
    end
end

return m
