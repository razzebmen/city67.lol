-- [ZCITY_PORT] Файл автоматически мигрирован из gamemodes/zcity/.../modes/roleplay/sv_buildmode.lua
-- Источник: _backup_20260522_182916/zcity/gamemode/modes/roleplay/
-- Все обращения к CurrentRound()/MODE/round заменены на ZCity_RP.
-- ZCity_RP — это таблица-обёртка, имитирующая старый MODE-namespace,
--           содержит Jobs, AddMoney, TakeMoney, GetMoney, CityTaxRate и т.д.
-- Реализация в darkrp_modules/zcity_rp_core/sh_zcity_rp_namespace.lua

--[[
    ZCity RP — Билд мод (сервер)
    Доступ: moderator, dmoderator и выше
    Команды: !стройка / !build через чат, кнопка в ESC-меню
    Эффект: выдаёт физган + тулган при включении, забирает при выключении
]]

util.AddNetworkString("rp_toggle_buildmode")
util.AddNetworkString("rp_buildmode_sync")

local BUILD_GROUPS = {
    vip         = true,
    moderator   = true,
    dmoderator  = true,
    dadmin      = true,
    admin       = true,
    superadmin  = true,
    dsuperadmin = true,
}

local function SetBuildMode(ply, state)
    ply:SetNWBool("rp_buildmode", state)

    if state then
        local physgun = ply:Give("weapon_physgun")
        local toolgun = ply:Give("gmod_tool")
        -- Помечаем оружие чтобы EntityCreated в sv_roleplay не удалил его сразу
        if IsValid(physgun) then physgun.BuildModeWeapon = true end
        if IsValid(toolgun) then toolgun.BuildModeWeapon = true end
        ply:ChatPrint("[Билд мод] ВКЛ — физган и тулган выданы")
    else
        ply:StripWeapon("weapon_physgun")
        ply:StripWeapon("gmod_tool")
        ply:ChatPrint("[Билд мод] ВЫКЛ — физган и тулган убраны")
    end

    net.Start("rp_buildmode_sync")
    net.WriteBool(state)
    net.Send(ply)
end

local function ToggleBuildMode(ply)
    if not IsValid(ply) then return end
    if not BUILD_GROUPS[ply:GetUserGroup()] then
        ply:ChatPrint("[Билд мод] Доступ только для модераторов и выше")
        return
    end
    SetBuildMode(ply, not ply:GetNWBool("rp_buildmode", false))
end

-- Запрос toggle от клиента (ESC-меню)
net.Receive("rp_toggle_buildmode", function(_, ply)
    ToggleBuildMode(ply)
end)

-- Снимаем физган/тулган ДО снапшота инвентаря, чтобы они не попали
-- в инвентарь трупа (иначе их можно «залутать» — пусть бесполезные, но валяются)
local BUILD_WEAPONS_TO_STRIP = { "weapon_physgun", "gmod_tool" }

hook.Add("DoPlayerDeath", "BuildModeStripGuns", function(ply)
    if not IsValid(ply) then return end
    if not ply:GetNWBool("rp_buildmode", false) then return end
    for _, cls in ipairs(BUILD_WEAPONS_TO_STRIP) do
        if ply:HasWeapon(cls) then ply:StripWeapon(cls) end
    end
end, HOOK_HIGH)

-- Подчищаем ragdoll-инвентарь после transfer (страховка на случай других хуков)
hook.Add("ItemsTransfered", "BuildModeStripRagdollInv", function(ply, ragdoll)
    if not IsValid(ragdoll) then return end
    local inv = ragdoll.inventory
    if not inv or not inv.Weapons then return end
    local changed = false
    for _, cls in ipairs(BUILD_WEAPONS_TO_STRIP) do
        if inv.Weapons[cls] then
            local w = inv.Weapons[cls]
            if isentity(w) and IsValid(w) then w:Remove() end
            inv.Weapons[cls] = nil
            changed = true
        end
    end
    if changed then ragdoll:SetNetVar("Inventory", inv) end
end)

-- Сбрасываем флаг билд-режима при смерти
hook.Add("PlayerDeath", "BuildModeOnDeath", function(ply)
    if not IsValid(ply) then return end
    if not ply:GetNWBool("rp_buildmode", false) then return end
    ply:SetNWBool("rp_buildmode", false)

    net.Start("rp_buildmode_sync")
    net.WriteBool(false)
    net.Send(ply)

    ply:ChatPrint("[Билд мод] Выключен — вы погибли")
end)

-- Сбрасываем всем при конце раунда
hook.Add("ZB_RoundEnd", "BuildModeRoundEnd", function()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:GetNWBool("rp_buildmode", false) then continue end
        SetBuildMode(ply, false)
    end
end)

-- Чат-команды !стройка / !build
hook.Add("PlayerSay", "BuildModeChatCmd", function(ply, text)
    if not IsValid(ply) then return end
    local t = string.lower(string.Trim(text or ""))
    if t ~= "!стройка" and t ~= "/стройка" and t ~= "!build" and t ~= "/build" then return end
    if not BUILD_GROUPS[ply:GetUserGroup()] then return end
    ToggleBuildMode(ply)
    return ""
end)
