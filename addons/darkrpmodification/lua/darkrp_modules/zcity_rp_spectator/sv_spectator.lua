--[[---------------------------------------------------------------------------
ZCity RP — сервер-логика спектатора (упрощённая: ТОЛЬКО свободный полёт)
---------------------------------------------------------------------------
При смерти игрока:
  • Включаем OBS_MODE_ROAMING + MOVETYPE_NOCLIP
  • Шлём клиенту net "ZB_SpectatePlayer" чтобы тот включил локальный noclip
  • Никаких клавиш / переключений цели / третьего лица.
---------------------------------------------------------------------------]]
if not SERVER then return end

util.AddNetworkString("ZB_SpectatePlayer")
util.AddNetworkString("ZB_ChooseSpecPly") -- держим стрингу зарегистрированной для совместимости
util.AddNetworkString("ZCity_RP_ForceUnspectate")

local hullscale = Vector(1, 1, 1)

-- Игнорируем сообщения переключения цели (раньше ZB_ChooseSpecPly от R/LMB/RMB)
net.Receive("ZB_ChooseSpecPly", function() end)

-- Каждый Think гарантируем что мёртвый игрок может летать (свободный полёт).
hook.Add("PlayerDeathThink", "ZCity_RP_SpectFly", function(ply)
    if not IsValid(ply) or ply:Alive() then return end

    -- TEAM_SPECTATOR — вечный зритель. Базовый GM:PlayerDeathThink
    -- (base/gamemode/player.lua) спавнит по IN_ATTACK/IN_ATTACK2/IN_JUMP, как
    -- только NextSpawnTime прошёл, и НЕ уважает возвращаемые значения хуков.
    -- Поэтому каждый тик держим NextSpawnTime в будущем — иначе ЛКМ+ПКМ
    -- заспавнивает зрителя обратно в игру. Выход из спектатора — только
    -- кнопкой PLAYING в табе (ZB_SpecMode → changeTeam+Spawn в sv_specmode.lua,
    -- который зовёт Spawn() напрямую в обход NextSpawnTime).
    if ply:Team() == TEAM_SPECTATOR then
        ply.NextSpawnTime = CurTime() + 1
        ply.NextRespawn   = CurTime() + 1
    end

    if ply:GetMoveType() ~= MOVETYPE_NOCLIP then
        ply:SetMoveType(MOVETYPE_NOCLIP)
    end
    if ply:GetObserverMode() ~= OBS_MODE_ROAMING then
        ply:Spectate(OBS_MODE_ROAMING)
    end
end)

-- При смерти включаем free-roam и шлём клиенту
hook.Add("PlayerDeath", "ZCity_RP_SpectInit", function(ply, inflictor, attacker)
    if not IsValid(ply) then return end

    ply:Spectate(OBS_MODE_ROAMING)
    ply:SetMoveType(MOVETYPE_NOCLIP)
    ply:SetHull(-hullscale, hullscale)
    ply:SetHullDuck(-hullscale, hullscale)

    timer.Simple(0.05, function()
        if not IsValid(ply) or ply:Alive() then return end
        net.Start("ZB_SpectatePlayer")
        net.WriteEntity(NULL)
        net.WriteEntity(NULL)
        net.WriteInt(3, 4) -- viewmode = free-roam
        net.Send(ply)
    end)
end)

-- При спавне ОБЯЗАТЕЛЬНО снимаем спектатор-режим. Если не снять,
-- ply:GetObserverMode() остаётся OBS_MODE_ROAMING, и движок считает view
-- криво (двойственное состояние "живой walk + observer roaming") — камеру
-- начинает рвать при ходьбе.
hook.Add("PlayerSpawn", "ZCity_RP_SpectUnspectateOnSpawn", function(ply, transition)
    if not IsValid(ply) then return end
    if ply:GetObserverMode() ~= OBS_MODE_NONE then
        ply:UnSpectate()
    end

    -- На сервере UnSpectate ставит obs=0, но NW-репликация на клиента
    -- иногда теряется (после быстрого death→spawn клиент остаётся с obs=6).
    -- Шлём отдельный net-message чтобы клиент локально обновил m_iObserverMode.
    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() then return end
        net.Start("ZCity_RP_ForceUnspectate")
        net.Send(ply)
    end)
end)

-- Анти-баг: HL2 npc_combine_s со shotgun должен быть skin=1 (унаследовано)
hook.Add("EntityKeyValue", "ZCity_CombineSkin", function(ent, key, value)
    if ent:GetClass() == "npc_combine_s" then
        ent:SetLagCompensated(true)
        if key == "additionalequipment" and value == "weapon_shotgun" then
            ent:SetSkin(1)
        end
    end
end)

RunConsoleCommand("mp_show_voice_icons", "0")

print("[ZCity RP] Spectator system loaded (free-roam only)")
