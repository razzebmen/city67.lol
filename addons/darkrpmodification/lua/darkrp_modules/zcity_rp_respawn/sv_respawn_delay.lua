--[[---------------------------------------------------------------------------
ZCity RP — задержка респавна 15 секунд (точная)
---------------------------------------------------------------------------
DarkRP в sv_gamemode_functions.lua:548 ставит:
    ply.NextSpawnTime = CurTime() + math.Clamp(GAMEMODE.Config.respawntime, 0, 10)
Это ограничивает максимум 10 секундами. Нам нужно 15 как в старом zcity-RP.

ПРОБЛЕМА которая была:
    MODE:RoundThink опрашивает раз в 1 сек — респавн запаздывал на ~1 сек,
    а HUD-таймер исчезал ровно в 0, в итоге игрок видел "пустой экран" между
    концом таймера и фактическим спавном.

РЕШЕНИЕ:
    Запускаем точный timer.Simple(15, ply:Spawn()) сразу после PlayerDeath.
    NextSpawnTime/NextRespawn оставляем для совместимости (RoundThink, DarkRP).
---------------------------------------------------------------------------]]
if not SERVER then return end

local RP_RESPAWN_DELAY = 15

local function ScheduleRespawn(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID() or tostring(ply:EntIndex())
    local tname = "ZCity_RP_Respawn_" .. sid

    timer.Create(tname, RP_RESPAWN_DELAY, 1, function()
        if not IsValid(ply) then return end
        if ply:Alive() then return end
        if ply.isArrested and ply:isArrested() then return end
        if ply:Team() == TEAM_SPECTATOR then return end
        ply:Spawn()
    end)
end

hook.Add("PlayerDeath", "ZCity_RP_RespawnDelay", function(ply, inflictor, attacker)
    if not IsValid(ply) then return end
    if ply.isArrested and ply:isArrested() then return end -- арестованных не трогаем

    -- Бипасс: при смене профы сами вызовем ply:Spawn() сразу — таймер не нужен.
    if ply.RP_InstantRespawn then
        ply.NextSpawnTime  = CurTime()
        ply.RP_RespawnDeadline = nil
        return
    end

    local deadline = CurTime() + RP_RESPAWN_DELAY
    ply.RP_RespawnDeadline = deadline
    ply.NextSpawnTime      = deadline
    ply.NextRespawn        = deadline

    -- DarkRP-gamemode (GAMEMODE:PlayerDeath, sv_gamemode_functions.lua:548) ВЫЗЫВАЕТСЯ
    -- ПОСЛЕ всех hook.Add("PlayerDeath", ...) и переписывает NextSpawnTime на
    -- CurTime + math.Clamp(respawntime, 0, 10) — то есть максимум 10 сек.
    -- Из-за этого Sandbox-овский GM:PlayerDeathThink начинал слушать ЛКМ уже
    -- через 10 сек и игрок спавнился на ~4 сек раньше нашего таймера.
    --
    -- Восстанавливаем дедлайн на следующем тике, когда gamemode уже отработал.
    timer.Simple(0, function()
        if IsValid(ply) and not ply:Alive() and ply.RP_RespawnDeadline then
            ply.NextSpawnTime = ply.RP_RespawnDeadline
            ply.NextRespawn   = ply.RP_RespawnDeadline
        end
    end)

    -- Шлём клиенту таймер для отображения на HUD
    if util.NetworkStringToID("roleplay_respawn_timer") ~= 0 then
        net.Start("roleplay_respawn_timer")
        net.WriteFloat(RP_RESPAWN_DELAY)
        net.Send(ply)
    end

    -- Точный таймер на спавн (избегает 1-сек погрешности RoundThink)
    ScheduleRespawn(ply)
end)

-- Защита от ЛКМ-респавна: Sandbox-овский GM:PlayerDeathThink смотрит ТОЛЬКО на
-- ply.NextSpawnTime и не уважает возвращаемое значение hook'ов. Поэтому держим
-- NextSpawnTime «впереди» каждый тик пока дедлайн не наступил. Если кто-то
-- другой (плагин, gamemode-override) опять перепишет это поле — мы тут же
-- вернём правильное значение, и Sandbox не пропустит ни одного нажатия.
hook.Add("PlayerDeathThink", "ZCity_RP_RespawnDelay", function(ply)
    if not IsValid(ply) then return end
    if ply.isArrested and ply:isArrested() then return end
    if ply.RP_InstantRespawn then return end -- разрешаем спавн при смене профы

    local deadline = ply.RP_RespawnDeadline
    if deadline and CurTime() < deadline then
        ply.NextSpawnTime = deadline
        ply.NextRespawn   = deadline
        return false -- даже если другие хуки сделают true, не пропустим
    end
end)

-- Сбрасываем флаг instant-респавна и дедлайн сразу после спавна
hook.Add("PlayerSpawn", "ZCity_RP_ClearInstantRespawn", function(ply)
    if IsValid(ply) then
        ply.RP_InstantRespawn   = nil
        ply.RP_RespawnDeadline  = nil
    end
end)

-- Если игрок дисконнектнулся — гасим таймер
hook.Add("PlayerDisconnected", "ZCity_RP_RespawnDelay_Cleanup", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID() or tostring(ply:EntIndex())
    local tname = "ZCity_RP_Respawn_" .. sid
    if timer.Exists(tname) then timer.Remove(tname) end
end)

print("[ZCity RP] Respawn delay = " .. RP_RESPAWN_DELAY .. " seconds (precise timer)")
