-- [ZCITY_PORT] Файл автоматически мигрирован из gamemodes/zcity/.../modes/roleplay/cl_buildmode.lua
-- Источник: _backup_20260522_182916/zcity/gamemode/modes/roleplay/
-- Все обращения к CurrentRound()/MODE/round заменены на ZCity_RP.
-- ZCity_RP — это таблица-обёртка, имитирующая старый MODE-namespace,
--           содержит Jobs, AddMoney, TakeMoney, GetMoney, CityTaxRate и т.д.
-- Реализация в darkrp_modules/zcity_rp_core/sh_zcity_rp_namespace.lua

--[[
    ZCity RP — Билд мод (клиент)
    Кнопка в ESC-меню (верхняя панель GMod), HUD-индикатор, синхронизация состояния
]]

local BUILD_GROUPS = {
    vip         = true,
    moderator   = true,
    dmoderator  = true,
    dadmin      = true,
    admin       = true,
    superadmin  = true,
    dsuperadmin = true,
}

local function HasBuildAccess()
    local ply = LocalPlayer()
    return IsValid(ply) and BUILD_GROUPS[ply:GetUserGroup()]
end

local function IsRoleplay()
    return true
end

-- ============================================
-- СИНХРОНИЗАЦИЯ СОСТОЯНИЯ
-- ============================================

-- Состояние хранится в NWBool, этот net — для визуального обновления
net.Receive("rp_buildmode_sync", function()
    net.ReadBool() -- обрабатываем, данные берём из NWBool
end)

-- ESC-меню: кнопка добавлена в lua/initpost/menu-n-derma/derma/cl_menu_panel.lua

-- ============================================
-- HUD ИНДИКАТОР
-- ============================================

hook.Add("HUDPaint", "BuildModeHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not ply:GetNWBool("rp_buildmode", false) then return end

    local scrW = ScrW()
    local w, h = 170, 28
    local x = scrW - w - 12
    local y = 12

    -- Фон
    draw.RoundedBox(4, x, y, w, h, Color(30, 140, 70, 210))
    -- Левая полоска-акцент
    draw.RoundedBox(4, x, y, 4, h, Color(80, 220, 120, 255))
    -- Текст
    draw.SimpleText("[ БИЛД МОД — ВКЛ ]", "DermaDefault", x + w / 2 + 2, y + h / 2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- ============================================
-- СООБЩЕНИЕ В ЧАТЕ при открытии ESC (подсказка один раз)
-- ============================================

local hintShown = false
hook.Add("OnPlayerChat", "BuildModeEscHint", function(ply, msg)
    if ply ~= LocalPlayer() then return end
    -- После того как игрок первый раз набрал !стройка — дальше подсказка не нужна
end)

-- Подсказка при входе в RP раунд
hook.Add("ZB_RoundStart", "BuildModeHint", function(roundData)
    if not HasBuildAccess() then return end
    if not roundData or roundData.name ~= "roleplay" then return end
    timer.Simple(3, function()
        if not HasBuildAccess() then return end
        chat.AddText(
            Color(100, 200, 255), "[Билд мод] ",
            Color(200, 200, 200), "Переключить: ",
            Color(255, 220, 80), "ESC → Билд мод",
            Color(200, 200, 200), "  или  ",
            Color(255, 220, 80), "!стройка"
        )
    end)
end)
