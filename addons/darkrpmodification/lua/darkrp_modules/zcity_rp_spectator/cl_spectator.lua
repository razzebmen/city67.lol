--[[---------------------------------------------------------------------------
ZCity RP — клиент death-camera (свободный полёт WASD)
---------------------------------------------------------------------------]]
if not CLIENT then return end

spect, prevspect, viewmode = nil, nil, 3

local hullscale = Vector(0, 0, 0)
local roamPos = nil

net.Receive("ZB_SpectatePlayer", function()
    pcall(function() net.ReadEntity() end)
    pcall(function() net.ReadEntity() end)
    pcall(function() net.ReadInt(4)   end)

    timer.Simple(0.1, function()
        local lply = LocalPlayer()
        if not IsValid(lply) or lply:Alive() then return end

        lply:SetHull(-hullscale, hullscale)
        lply:SetHullDuck(-hullscale, hullscale)
        -- НЕ ставим MoveType/ObserverMode клиентом: сервер делает это сам
        -- через PlayerDeath/PlayerDeathThink в sv_spectator.lua. Клиентская
        -- перезапись приводит к рассинхрону Alive/ObserverMode после респавна.

        if not roamPos then
            roamPos = lply:GetShootPos()
        end
    end)
end)

hook.Add("Think", "ZCity_RP_DeathRoaming", function()
    local lply = LocalPlayer()
    if not IsValid(lply) then return end

    if lply:Alive() then
        if roamPos then
            roamPos = nil
        end
        return
    end

    if follow ~= nil then
        follow = nil
    end

    -- Если игрок выбрал цель через спектатор-меню — пропускаем WASD free-roam,
    -- движок сам показывает вид от цели (OBS_MODE_IN_EYE / OBS_MODE_CHASE).
    local obs = lply:GetObserverMode()
    if obs == OBS_MODE_IN_EYE or obs == OBS_MODE_CHASE then
        roamPos = nil
        return
    end

    -- ВАЖНО: НЕ форсим клиентом MoveType/ObserverMode. Эти поля на LocalPlayer'е
    -- являются NW-флагами и синкаются от сервера. На клиенте Alive() и
    -- ObserverMode() обновляются разными network-message'ами и могут на 1-2
    -- тика расходиться. Если в этом окне мы насильно ставим OBS_MODE_ROAMING,
    -- то после респавна сервер уже отослал UnSpectate (Alive=true), но клиент
    -- ещё видит Alive=false и пишет ROAMING поверх. Через тик Alive=true,
    -- ObserverMode остаётся 6 → камеру колбасит. Серверный PlayerDeathThink
    -- сам гарантирует MOVETYPE_NOCLIP+OBS_MODE_ROAMING пока игрок мёртв.

    if not roamPos then
        roamPos = lply:GetShootPos()
    end

    local speed = 1000
    if lply:KeyDown(IN_SPEED) then speed = 2500 end
    if lply:KeyDown(IN_WALK) or lply:KeyDown(IN_DUCK) then speed = 300 end

    local vel = Vector(0, 0, 0)
    local ang = lply:EyeAngles()
    local forward = ang:Forward()
    local right = ang:Right()

    if lply:KeyDown(IN_FORWARD) then vel = vel + forward end
    if lply:KeyDown(IN_BACK) then vel = vel - forward end
    if lply:KeyDown(IN_MOVERIGHT) then vel = vel + right end
    if lply:KeyDown(IN_MOVELEFT) then vel = vel - right end

    if vel:Length() > 0 then
        vel:Normalize()
        roamPos = roamPos + vel * speed * RealFrameTime()
    end
end)

hook.Add("CalcView", "ZCity_RP_DeathCamera", function(ply, origin, angles, fov)
    if not IsValid(ply) then return end

    -- Не перебиваем админский FSpectate
    if FSpectate and FSpectate.getSpecEnt and FSpectate.getSpecEnt() then
        return
    end

    if ply:Alive() then
        if roamPos then
            roamPos = nil
        end
        return
    end

    -- При спектатинге игрока (OBS_MODE_IN_EYE/CHASE) view рисует движок
    local obs = ply:GetObserverMode()
    if obs == OBS_MODE_IN_EYE or obs == OBS_MODE_CHASE then
        return
    end

    if not roamPos then return end

    return {
        origin = roamPos,
        angles = ply:EyeAngles(),
        fov = fov,
        drawviewer = true,
    }
end)

hook.Add("PlayerSpawn", "ZCity_RP_SpectReset", function(ply)
    if ply ~= LocalPlayer() then return end
    roamPos = nil
    -- НЕ ставим SetObserverMode клиентом: на LocalPlayer'е это NW-флаг,
    -- сервер сам его сбрасывает через UnSpectate в sv_spectator.lua
    -- (хук ZCity_RP_SpectUnspectateOnSpawn).
end)

-- Серверный sv_spectator.lua после респавна шлёт ZCity_RP_ForceUnspectate.
-- Клиентский m_iObserverMode иногда не обновляется через NW-репликацию
-- (после быстрого death→spawn остаётся OBS_MODE_ROAMING), и HGAddView
-- начинает считать камеру криво при ходьбе. Принудительно сбрасываем.
net.Receive("ZCity_RP_ForceUnspectate", function()
    local lply = LocalPlayer()
    if not IsValid(lply) then return end
    if lply:GetObserverMode() ~= OBS_MODE_NONE then
        lply:SetObserverMode(OBS_MODE_NONE)
    end
end)
