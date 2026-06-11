--[[---------------------------------------------------------------------------
ZCity RP — эмуляция жизненного цикла раунда
---------------------------------------------------------------------------
В старом geymode zcity цикл был такой:
    1. Intermission()       — при старте карты, перед раундом
    2. RoundStart()          — при старте раунда (после Intermission)
    3. RoundThink()          — каждый Think пока раунд идёт
    4. EndRound()            — при завершении раунда
    5. PostCleanupMap        — после game.CleanUpMap()
В DarkRP такого нет. Поэтому:
    • Intermission НЕ вызываем (она делает game.CleanUpMap, что убьёт DarkRP)
    • RoundStart вызываем один раз через InitPostEntity
    • RoundThink вызываем каждые 1 сек (для зарплат, респавна, войны)
    • EndRound никогда (раунд бесконечный)
---------------------------------------------------------------------------]]
if not SERVER then return end

-- RoundStart: один раз при загрузке карты (загружаем car-spawns и пр.)
hook.Add("InitPostEntity", "ZCity_RP_RoundStart", function()
    timer.Simple(2, function()
        if ZCity_RP and ZCity_RP.RoundStart then
            local ok, err = pcall(ZCity_RP.RoundStart, ZCity_RP)
            if not ok then
                ErrorNoHalt("[ZCity RP] RoundStart error: " .. tostring(err) .. "\n")
            end
        end
    end)
end)

-- RoundThink: раз в секунду (зарплаты, респавн, война и комендантский час)
local lastThink = 0
hook.Add("Think", "ZCity_RP_RoundThink", function()
    if CurTime() - lastThink < 1 then return end
    lastThink = CurTime()

    if ZCity_RP and ZCity_RP.RoundThink then
        local ok, err = pcall(ZCity_RP.RoundThink, ZCity_RP)
        if not ok then
            ErrorNoHalt("[ZCity RP] RoundThink error: " .. tostring(err) .. "\n")
        end
    end
end)

print("[ZCity RP] Round lifecycle hooks attached (RoundStart, RoundThink)")
