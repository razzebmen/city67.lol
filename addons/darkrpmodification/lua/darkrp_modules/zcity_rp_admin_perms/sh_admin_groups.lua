--[[---------------------------------------------------------------------------
ZCity RP — права групп (BlockSpawn / NoClip / SpawnMenu / CanTool / CanProperty)
---------------------------------------------------------------------------
Перенесено из gamemodes/zcity/.../shared.lua и init.lua (бэкап).

Группы доступа:
  • SPAWN_FULL_GROUPS   — admin/superadmin/dsuperadmin/dadmin/operator
                          → всё в Q-меню (оружие, NPC, vehicle, пропы, эффекты)
  • SPAWN_LIMITED_GROUPS — moderator/dmoderator
                          → ТОЛЬКО пропы/эффекты/objects/ragdolls
  • остальные → ничего
---------------------------------------------------------------------------]]

-- ============================================================================
-- 1. BlockSpawn (PlayerSpawn* хуки)
-- ============================================================================

local SPAWN_FULL_GROUPS = {
    admin       = true,
    superadmin  = true,
    dsuperadmin = true,
    dadmin      = true,
    operator    = true,
}

local SPAWN_LIMITED_GROUPS = {
    vip        = true,
    moderator  = true,
    dmoderator = true,
}

local SPAWN_LIMITED_HOOKS = {
    PlayerSpawnProp    = true,
    PlayerSpawnEffect  = true,
    PlayerSpawnObject  = true,
    PlayerSpawnRagdoll = true,
}

local function makeBlockSpawn(hookname)
    return function(ply, ent)
        if game.SinglePlayer() then return true end
        if not IsValid(ply) then return false end
        local group = string.lower(ply:GetUserGroup() or "")
        if SPAWN_LIMITED_GROUPS[group] then
            return SPAWN_LIMITED_HOOKS[hookname] == true
        end
        if SPAWN_FULL_GROUPS[group] then return true end
        if ply:IsAdmin() then return true end
        return false
    end
end

local spawnHooks = {
    "PlayerGiveSWEP", "PlayerSpawnEffect", "PlayerSpawnNPC",
    "PlayerSpawnObject", "PlayerSpawnProp", "PlayerSpawnRagdoll",
    "PlayerSpawnSENT", "PlayerSpawnSWEP", "PlayerSpawnVehicle",
}
for _, v in ipairs(spawnHooks) do
    hook.Add(v, "ZCity_BlockSpawn", makeBlockSpawn(v))
end

-- ============================================================================
-- 2. NoClip — только указанные группы могут включить
-- ============================================================================

local NOCLIP_GROUPS = {
    moderator   = true,
    admin       = true,
    superadmin  = true,
    dmoderator  = true,
    dadmin      = true,
    dsuperadmin = true,
    operator    = true,
}

hook.Add("PlayerNoClip", "ZCity_NoClipWhitelist", function(ply, desiredState)
    if desiredState == false then return true end -- выключение всем разрешено
    if not IsValid(ply) then return false end
    local group = string.lower(ply:GetUserGroup() or "")
    if NOCLIP_GROUPS[group] then return true end
    return false
end)

-- ============================================================================
-- 3. SpawnMenu (Q-меню) — только указанные группы
-- ============================================================================

if CLIENT then
    local SPAWNMENU_GROUPS = {
        vip         = true,
        superadmin  = true,
        admin       = true,
        dadmin      = true,
        dsuperadmin = true,
        operator    = true,
        moderator   = true,
        dmoderator  = true,
    }

    hook.Add("SpawnMenuOpen", "ZCity_SpawnMenuWhitelist", function()
        local ply = LocalPlayer()
        local group = string.lower(ply:GetUserGroup() or "")
        if SPAWNMENU_GROUPS[group] then return end
        if ply:IsSuperAdmin() then return end
        if ply:IsAdmin() then return end
        return false
    end)
end

-- ============================================================================
-- 4. CanTool — moderator/dmoderator только whitelist инструментов,
--    админы — что угодно на чём угодно (обход FPP по владельцу)
-- ============================================================================
-- ВАЖНО: вешаем на HOOK_HIGH (ULib priority = -1). Так наш хук вызывается
-- ДО FPP.Protect.CanTool (priority 0). Если мы возвращаем не-nil, hook.Call
-- немедленно прерывается и FPP не успевает заблокировать tool по владельцу.
-- Иначе после переноса на DarkRP FPP блочит даже admin'ам tool на чужих пропах.
-- ============================================================================

if SERVER then
    local MODER_ALLOWED_TOOLS = {
        textscreen = true, advdupe2 = true, keypad_willox = true,
        light = true, button = true, fading_door = true,
        stacker_improved = true, remover = true, camera = true,
        material = true, colour = true,
    }
    local MODER_GROUPS = { vip = true, moderator = true, dmoderator = true }

    local TOOL_FULL_GROUPS = {
        admin       = true,
        dadmin      = true,
        superadmin  = true,
        dsuperadmin = true,
        operator    = true,
    }

    hook.Add("CanTool", "ZCity_ToolWhitelist", function(ply, tr, toolname)
        if not IsValid(ply) then return end
        local group = string.lower(ply:GetUserGroup() or "")

        -- Полные группы: обход FPP — true для любых пропов
        if TOOL_FULL_GROUPS[group] or ply:IsAdmin() then
            return true
        end

        -- Модер-группы: только whitelist tools, на любых пропах
        if MODER_GROUPS[group] then
            if MODER_ALLOWED_TOOLS[toolname] then return true end
            return false
        end

        -- Остальным — никаких tools (стандартный DarkRP)
        return false
    end, HOOK_HIGH)
end

-- ============================================================================
-- 5. CanProperty (C-меню: материал/цвет/удаление/skin/bodygroup)
-- ============================================================================
-- ВАЖНО: HOOK_HIGH. До переноса на DarkRP не было FPP, поэтому C-меню работало.
-- После переноса FPP.Protect.CanProperty (priority 0) проверяет владельца пропа
-- и блокирует всё, что не принадлежит игроку — даже админам. Наш хук на -1
-- возвращает true для админских групп → FPP не вызывается → C-меню работает,
-- включая удаление.
-- ============================================================================

local CMENU_ALLOWED_GROUPS = {
    dadmin      = true,
    admin       = true,
    superadmin  = true,
    dsuperadmin = true,
    operator    = true,
}

hook.Add("CanProperty", "ZCity_CMenuPerms", function(ply, property, ent)
    if not IsValid(ply) then return end
    if CMENU_ALLOWED_GROUPS[ply:GetUserGroup()] or ply:IsAdmin() then
        return true
    end
    return false
end, HOOK_HIGH)

-- ============================================================================
-- 6. Лимит пропов для не-админских групп (20 шт.)
-- ============================================================================
-- Все группы ДО admin (user/vip/moderator/dmoderator/operator и т.п.) ограничены
-- 20 пропами. Без лимита: admin / dadmin / superadmin / dsuperadmin.
-- Проверка идёт через хук на HOOK_HIGH, чтобы сработать раньше ZCity_BlockSpawn,
-- который возвращает true и блокирует дальнейшую обработку хуков.

if SERVER then
    local PROP_LIMIT = 20

    local NO_PROP_LIMIT_GROUPS = {
        admin       = true,
        dadmin      = true,
        superadmin  = true,
        dsuperadmin = true,
    }

    local function isUnlimited(ply)
        if not IsValid(ply) then return false end
        return NO_PROP_LIMIT_GROUPS[string.lower(ply:GetUserGroup() or "")] == true
    end

    hook.Add("PlayerSpawnProp", "ZCity_PropLimit", function(ply, model)
        if not IsValid(ply) then return end
        if isUnlimited(ply) then return end
        local count = ply.GetCount and ply:GetCount("props") or 0
        if count >= PROP_LIMIT then
            if DarkRP and DarkRP.notify then
                DarkRP.notify(ply, 1, 5, "Достигнут лимит пропов: " .. PROP_LIMIT)
            else
                ply:ChatPrint("[Сервер] Достигнут лимит пропов: " .. PROP_LIMIT)
            end
            return false
        end
    end, HOOK_HIGH)

    -- Дублируем лимит через SetMaxCount — это уважается движком и отображается
    -- в счётчике "props" в Q-меню / sbox_maxprops.
    local function applyPropLimit(ply)
        if not IsValid(ply) or not ply.SetMaxCount then return end
        if isUnlimited(ply) then return end
        ply:SetMaxCount("props", PROP_LIMIT)
    end

    hook.Add("PlayerInitialSpawn", "ZCity_PropLimit_Init", function(ply)
        -- даём ULib/ULX время выдать группу
        timer.Simple(1, function() applyPropLimit(ply) end)
    end)

    -- При смене группы (ULX adduser) пересчитываем
    hook.Add("CAMI.PlayerUsergroupChanged", "ZCity_PropLimit_GroupChange",
        function(ply, _, newGroup)
            timer.Simple(0.1, function() applyPropLimit(ply) end)
        end)
end

-- ============================================================================
-- 7. Физган админа — поднимает ВСЁ (обход FPP / DarkRP-блокировок по владельцу)
-- ============================================================================
-- Жалобы: админам с ранга dmoderator движок DarkRP/FPP блокирует чужие пропы;
-- moderator/dmoderator/operator не могли поднимать игроков, т.к. у них не было
-- ULX-привилегии `ulx physgunplayer` (была только у admin/dadmin/dsuperadmin).
--
-- Решение: на HOOK_HIGH принудительно возвращаем true для PhysgunPickup,
-- OnPhysgunReload, GravGunPickupAllowed, GravGunPunt и PlayerUse, чтобы FPP
-- (default-priority) уже не успел заблокировать. Это применяется И к пропам,
-- И к игрокам, но для игроков мы уважаем ULX can_target (модер не подымет
-- суперадмина) если ULib доступен.

if SERVER then
    local PHYSGUN_FULL_GROUPS = {
        dmoderator  = true,
        moderator   = true,
        dadmin      = true,
        admin       = true,
        dsuperadmin = true,
        superadmin  = true,
        operator    = true,
    }

    local function hasFullPhysgun(ply)
        if not IsValid(ply) then return false end
        return PHYSGUN_FULL_GROUPS[string.lower(ply:GetUserGroup() or "")] == true
    end

    -- Проверка иерархии: модер не должен таскать суперадмина физганом.
    -- Возвращает true если ply может таргетить target.
    -- Логика: блокируем только если target СТРОГО выше по рангу
    -- (равные ранги — можно, нижестоящих — можно).
    local rankOrder = {
        user = 0, vip = 1, operator = 2,
        moderator = 3, dmoderator = 3,
        admin = 4, dadmin = 4,
        superadmin = 5, dsuperadmin = 5,
    }

    local function canTargetPlayer(ply, target)
        if not IsValid(ply) or not IsValid(target) then return false end
        if ply == target then return true end -- себя всегда можно
        local plyR = rankOrder[string.lower(ply:GetUserGroup() or "")] or 0
        local tgtR = rankOrder[string.lower(target:GetUserGroup() or "")] or 0
        if tgtR > plyR then return false end -- target строго выше — нельзя
        return true
    end

    -- ----------------------------------------------------------------------
    -- Двери и окна: запрещено двигать физганом/грави-ганом ДАЖЕ админам.
    -- Защищает мап от смещения дверей и стёкол, которые игроки потом не могут
    -- использовать (двери "залипают" в стенах, окна выпадают и т.д.).
    -- ----------------------------------------------------------------------
    local DOOR_CLASSES = {
        ["func_door"]          = true,
        ["func_door_rotating"] = true,
        ["prop_door_rotating"] = true,
    }
    local WINDOW_CLASSES = {
        ["func_breakable"]      = true,
        ["func_breakable_surf"] = true,
    }

    local function isDoorOrWindow(ent)
        if not IsValid(ent) then return false end
        local class = ent:GetClass()
        if DOOR_CLASSES[class] then return true end
        if WINDOW_CLASSES[class] then return true end
        -- DarkRP-метод для prop_door / func_door
        if isfunction(ent.isDoor) and ent:isDoor() then return true end
        -- Пропы со стеклянными моделями (окна-пропы на картах)
        if class == "prop_physics" or class == "prop_dynamic" then
            local model = string.lower(ent:GetModel() or "")
            if string.find(model, "glass", 1, true) or
               string.find(model, "window", 1, true) then
                return true
            end
        end
        return false
    end

    -- Берём пропы и игроков физганом
    hook.Add("PhysgunPickup", "ZCity_AdminPhysgunAll", function(ply, ent)
        if not IsValid(ent) then return end
        if not hasFullPhysgun(ply) then return end
        if ent:IsPlayer() then
            -- Игроки: разрешаем если ply имеет право таргетить ent
            if not canTargetPlayer(ply, ent) then return end
            return true
        end
        if isDoorOrWindow(ent) then return false end
        return true
    end, HOOK_HIGH)

    -- Reload физгана (заморозка/разморозка)
    hook.Add("OnPhysgunReload", "ZCity_AdminPhysgunReload", function(weapon, ply, ent)
        if IsValid(ent) and not ent:IsPlayer() and isDoorOrWindow(ent) then return false end
        if not hasFullPhysgun(ply) then return end
        if IsValid(ent) and ent:IsPlayer() and not canTargetPlayer(ply, ent) then return end
        return true
    end, HOOK_HIGH)

    -- Грави-ган: пикап и пинок
    hook.Add("GravGunPickupAllowed", "ZCity_AdminGravgunAll", function(ply, ent)
        if not IsValid(ent) then return end
        if not hasFullPhysgun(ply) then return end
        if ent:IsPlayer() then
            if not canTargetPlayer(ply, ent) then return end
            return true
        end
        if isDoorOrWindow(ent) then return false end
        return true
    end, HOOK_HIGH)

    hook.Add("GravGunPunt", "ZCity_AdminGravgunPunt", function(ply, ent)
        if not IsValid(ent) then return end
        if not hasFullPhysgun(ply) then return end
        if ent:IsPlayer() then
            if not canTargetPlayer(ply, ent) then return end
            return true
        end
        if isDoorOrWindow(ent) then return false end
        return true
    end, HOOK_HIGH)

    -- E (использование) — чтобы админы могли жать на чужие двери/кнопки/keypad'ы.
    -- Для игроков НЕ разрешаем (E на игроке = подобрать оружие/предмет —
    -- админу не нужно).
    hook.Add("PlayerUse", "ZCity_AdminUseAll", function(ply, ent)
        if not IsValid(ent) or ent:IsPlayer() then return end
        if hasFullPhysgun(ply) then return true end
    end, HOOK_HIGH)

    -- ----------------------------------------------------------------------
    -- ULX physgunplayer: автоматически выдаём всем PHYSGUN_FULL_GROUPS.
    -- Это нужно если другие аддоны (FAdmin, Nova и т.п.) дополнительно
    -- проверяют ULib-привилегию вместо чистого хука PhysgunPickup.
    -- ----------------------------------------------------------------------
    local function grantPhysgunPlayerAccess()
        if not (ULib and ULib.ucl and ULib.ucl.groupAllow) then return end
        for grp in pairs(PHYSGUN_FULL_GROUPS) do
            if ULib.ucl.groups and ULib.ucl.groups[grp] then
                ULib.ucl.groupAllow(grp, "ulx physgunplayer")
            end
        end
    end

    hook.Add("Initialize", "ZCity_GrantPhysgunPlayer", function()
        timer.Simple(5, grantPhysgunPlayerAccess)
    end)
    hook.Add("UCLChanged", "ZCity_GrantPhysgunPlayer_OnUCLChange", grantPhysgunPlayerAccess)

    -- ============================================================================
    -- 8. Расширенные права модератора
    -- ============================================================================
    -- Базовый набор модера в groups.txt был очень узким (kick/ban/jail/mute/gag).
    -- Для нормальной модерации DarkRP-сервера нужно больше: спектатор,
    -- jobban, slap/slay/whip, gimp/blind, очистка пропов и т.д.
    --
    -- Намеренно НЕ выдаём модеру:
    --   * ulx hp / ulx armor          — медицина не задача модера
    --   * ulx ragdoll / unragdoll     — потенциал эксплоита (застрявшие)
    --   * ulx sslay                   — silent slay, серьёзная санкция → только admin
    --   * ulx playsound               — потенциал спама
    --   * ulx map                     — смена карты
    --   * ulx voteban / votekick      — модер сам банит/кикает
    --   * darkrp_admincommands        — слишком широко
    --   * darkrp_getadminweapons      — модеру не нужно админ-оружие
    --   * darkrp_setdoorowner         — слишком много власти над имуществом
    -- ============================================================================
    local MODERATOR_PRIVILEGES = {
        -- Дополнительные санкции
        "ulx slap", "ulx slay", "ulx whip", "ulx strip",
        "ulx ignite", "ulx unignite", "ulx unigniteall",
        "ulx gimp", "ulx ungimp",
        "ulx blind", "ulx unblind",
        -- Расследование / наблюдение
        "ulx spectate",
        "fspectate", "fspectateteleport",
        "darkrp_seeevents",
        -- Перемещение нарушителя
        "ulx jailtp", "ulx send", "ulx teleport",
        -- DarkRP-специфика: модер должен уметь забанить работу
        "ulx jobban", "ulx jobunban", "ulx jobbanlist",
        -- Пропы: подбор/использование (мы уже даём через хуки, ULX-привилегия
        -- нужна для совместимости с FAdmin/FPP-аддонами которые её проверяют)
        "ulx physgunplayer",
        "fpp_cleanup", "fpp_touchotherplayersprops",
    }

    local MODERATOR_GROUPS = { "moderator", "dmoderator" }

    local function grantModeratorPrivileges()
        if not (ULib and ULib.ucl and ULib.ucl.groupAllow) then return end
        if not ULib.ucl.groups then return end
        for _, grp in ipairs(MODERATOR_GROUPS) do
            if ULib.ucl.groups[grp] then
                for _, priv in ipairs(MODERATOR_PRIVILEGES) do
                    ULib.ucl.groupAllow(grp, priv)
                end
            end
        end
    end

    hook.Add("Initialize", "ZCity_GrantModerator", function()
        timer.Simple(5, grantModeratorPrivileges)
    end)
    hook.Add("UCLChanged", "ZCity_GrantModerator_OnUCLChange", grantModeratorPrivileges)
end

print("[ZCity RP] Admin perms loaded (BlockSpawn / NoClip / SpawnMenu / CanTool-HIGH / CanProperty-HIGH / PropLimit-20 / Physgun-all-incl-players / NoDoorWindow)")
