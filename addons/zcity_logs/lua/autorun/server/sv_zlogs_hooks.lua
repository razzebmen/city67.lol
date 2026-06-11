--[[
    ZCity Logs — стандартные хуки GMod.
    Все эвенты, не специфичные для RP-режима.
]]

if not ZLogs then return end

-- ============================================
-- ЧАТ
-- ZCity использует кастомный хук HG_PlayerSay вместо стандартного PlayerSay.
-- Источник: lua/homigrad/zchat/sh_chat.lua:227
-- Сигнатура: (ply, txtTbl, text) — text это готовая строка
-- ============================================

hook.Add("HG_PlayerSay", "zlogs_chat", function(ply, txtTbl, text)
    if not IsValid(ply) then return end
    text = tostring(text or "")
    if text == "" then return end

    ZLogs.Add("chat", ply, ply:Nick() .. ": " .. text, {
        msg = string.sub(text, 1, 256),
    })
end)

-- ============================================
-- ПОДКЛЮЧЕНИЯ / ОТКЛЮЧЕНИЯ
-- ============================================

hook.Add("PlayerInitialSpawn", "zlogs_connect", function(ply)
    timer.Simple(0.5, function()
        if not IsValid(ply) then return end
        ZLogs.Add("connect", ply, ply:Nick() .. " подключился (" .. ply:SteamID() .. ")", {
            ip     = ply:IPAddress() or "",
            steam64 = ply:SteamID64() or "",
        })
    end)
end)

hook.Add("PlayerDisconnected", "zlogs_disconnect", function(ply)
    if not IsValid(ply) then return end
    ZLogs.Add("connect", ply, ply:Nick() .. " отключился", {
        steam64 = ply.SteamID64 and ply:SteamID64() or "",
    })
end)

hook.Add("ULibPlayerNameChanged", "zlogs_namechange", function(ply, oldName, newName)
    if not IsValid(ply) then return end
    ZLogs.Add("connect", ply, "Смена ника: " .. tostring(oldName) .. " → " .. tostring(newName), {
        old_nick = oldName,
        new_nick = newName,
    })
end)

-- ============================================
-- УБИЙСТВА
-- ============================================
-- Используем уже существующую логику kill-логгера из sv_roleplay.lua —
-- она надёжнее отлавливает атакующего через HomigradDamage.
-- Подписываемся на хук PlayerDeath НИЖЕ по приоритету (PostHook), используя ply._lastKillLogAttacker
-- который уже выставил RP-логгер. Но также делаем самостоятельный fallback.

hook.Add("PlayerDeath", "zlogs_kill", function(victim, inflictor, attacker)
    if not IsValid(victim) then return end

    -- Берём реального атакующего тем же способом что и RP-kill-логгер
    local realAttacker = victim._lastKillLogAttacker

    if not IsValid(realAttacker) then
        realAttacker = attacker
        if IsValid(realAttacker) and not realAttacker:IsPlayer() then
            local owner = realAttacker:GetOwner()
            if IsValid(owner) and owner:IsPlayer() then
                realAttacker = owner
            end
        end
    end

    local weapon = "неизвестно"
    if IsValid(inflictor) then
        if inflictor:IsWeapon() then
            weapon = inflictor:GetClass()
        elseif inflictor:IsPlayer() and IsValid(inflictor:GetActiveWeapon()) then
            weapon = inflictor:GetActiveWeapon():GetClass()
        elseif inflictor:GetClass() then
            weapon = inflictor:GetClass()
        end
    end

    -- Суицид / падение / прочее
    if not IsValid(realAttacker) or not realAttacker:IsPlayer() or realAttacker == victim then
        local reason = "погиб"
        if IsValid(inflictor) and inflictor:GetClass() == "trigger_hurt" then
            reason = "погиб (зона смерти)"
        elseif weapon ~= "неизвестно" then
            reason = "погиб (" .. weapon .. ")"
        end
        ZLogs.Add("kill", victim, victim:Nick() .. " " .. reason, {
            weapon = weapon,
            self   = true,
            pos    = victim:GetPos(),
        })
        return
    end

    -- Полноценное убийство
    local dist = math.floor(realAttacker:GetPos():Distance(victim:GetPos()))
    local txt  = realAttacker:Nick() .. " убил " .. victim:Nick() ..
                 " (" .. weapon .. ", " .. dist .. "u)"

    ZLogs.Add("kill", realAttacker, txt, {
        target      = victim,
        weapon      = weapon,
        distance    = dist,
        attacker_pos = realAttacker:GetPos(),
        victim_pos   = victim:GetPos(),
    })
end)

-- ============================================
-- УРОН (с группировкой — иначе будет спам)
-- ============================================
-- Накапливаем DMG между парой "attacker → victim" и сбрасываем раз в N секунд

local damageBuckets = {}

local function flushDamage()
    for key, bucket in pairs(damageBuckets) do
        if bucket.total >= 25 then -- логируем только если суммарный урон ощутимый
            local atk = bucket.attacker
            local vic = bucket.victim
            if IsValid(atk) and IsValid(vic) then
                local atkName = atk:IsPlayer() and atk:Nick() or atk:GetClass()
                local vicName = vic:IsPlayer() and vic:Nick() or vic:GetClass()
                local txt = atkName .. " нанёс " .. bucket.total .. " урона " .. vicName ..
                            " (" .. bucket.hits .. " попад., " .. bucket.weapon .. ")"
                local atkPly = atk:IsPlayer() and atk or nil
                ZLogs.Add("damage", atkPly, txt, {
                    target  = vic:IsPlayer() and vic or nil,
                    weapon  = bucket.weapon,
                    total   = bucket.total,
                    hits    = bucket.hits,
                })
            end
        end
    end
    damageBuckets = {}
end

timer.Create("zlogs_damage_flush", ZLogs.DAMAGE_FLUSH_SEC, 0, flushDamage)

hook.Add("EntityTakeDamage", "zlogs_damage", function(target, dmg)
    if not IsValid(target) or not target:IsPlayer() then return end

    local attacker = dmg:GetAttacker()
    if not IsValid(attacker) then return end
    if IsValid(attacker) and not attacker:IsPlayer() then
        local owner = attacker:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then
            attacker = owner
        end
    end
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if attacker == target then return end

    local amount = math.floor(dmg:GetDamage())
    if amount <= 0 then return end

    local weapon = "—"
    local inf = dmg:GetInflictor()
    if IsValid(inf) then
        if inf:IsWeapon() then weapon = inf:GetClass()
        elseif inf:GetClass() then weapon = inf:GetClass() end
    end

    local key = attacker:SteamID() .. ">" .. target:SteamID() .. "|" .. weapon
    local b = damageBuckets[key]
    if not b then
        b = { attacker = attacker, victim = target, weapon = weapon, total = 0, hits = 0 }
        damageBuckets[key] = b
    end
    b.total = b.total + amount
    b.hits  = b.hits + 1
end)

-- ============================================
-- СПАВН ОРУЖИЯ / МАШИН / NPC / SENT / ЭФФЕКТОВ
-- ============================================

hook.Add("PlayerGiveSWEP", "zlogs_swep", function(ply, weapon)
    if not IsValid(ply) then return end
    ZLogs.Add("weapon", ply, ply:Nick() .. " выдал себе оружие: " .. tostring(weapon), {
        weapon = weapon,
    })
end)

hook.Add("PlayerSpawnedVehicle", "zlogs_vehicle", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    ZLogs.Add("weapon", ply, ply:Nick() .. " заспавнил машину: " .. ent:GetClass(), {
        class = ent:GetClass(),
    })
end)

hook.Add("PlayerSpawnedNPC", "zlogs_npc", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    ZLogs.Add("weapon", ply, ply:Nick() .. " заспавнил NPC: " .. ent:GetClass(), {
        class = ent:GetClass(),
    })
end)

hook.Add("PlayerSpawnedSENT", "zlogs_sent", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    ZLogs.Add("weapon", ply, ply:Nick() .. " заспавнил энтити: " .. ent:GetClass(), {
        class = ent:GetClass(),
    })
end)

-- ============================================
-- ULX-КОМАНДЫ (бан, кик, мут и т.д.)
-- ============================================

-- Grace period: не логировать первые 20 секунд после старта сервера
-- (ULX инициализируется и эмитит кучу служебных ULibCommandCalled)
local _adminGracePeriod = os.time() + 20

hook.Add("ULibCommandCalled", "zlogs_ulx", function(ply, cmd, argv)
    if not cmd then return end
    -- Пропускаем стартовый спам ULX-инициализации
    if os.time() < _adminGracePeriod then return end
    -- Игнорим служебные команды
    local skip = {
        ["ulx help"]    = true,
        ["ulx menu"]    = true,
        ["ulx logs"]    = true,
        ["ulx version"] = true,
    }
    if skip[cmd] then return end
    -- Игнорим ulx log* (logEcho, logFile и т.д.) — служебный ULX logging
    if string.sub(cmd, 1, 7) == "ulx log" then return end

    local nick = IsValid(ply) and ply:Nick() or "Консоль"
    local args = (argv and #argv > 0) and (" " .. table.concat(argv, " ")) or ""
    ZLogs.Add("admin", ply, nick .. " -> " .. cmd .. args, {
        cmd  = cmd,
        argv = argv,
    })
end)

MsgN("[ZLogs] Стандартные хуки загружены")
