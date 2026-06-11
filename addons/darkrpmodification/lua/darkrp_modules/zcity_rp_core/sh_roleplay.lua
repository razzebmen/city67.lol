-- [ZCITY_PORT] Файл автоматически мигрирован из gamemodes/zcity/.../modes/roleplay/sh_roleplay.lua
-- Источник: _backup_20260522_182916/zcity/gamemode/modes/roleplay/
-- Все обращения к CurrentRound()/MODE/round заменены на ZCity_RP.
-- ZCity_RP — это таблица-обёртка, имитирующая старый MODE-namespace,
--           содержит Jobs, AddMoney, TakeMoney, GetMoney, CityTaxRate и т.д.
-- Реализация в darkrp_modules/zcity_rp_core/sh_zcity_rp_namespace.lua

-- [ZCITY_PORT] Безопасный bootstrap: если по какой-то причине autorun
-- (sh_zcity_namespace.lua) не успел отработать — создаём минимальную таблицу.
ZCity_RP = ZCity_RP or {}
local MODE = ZCity_RP
_G.MODE = MODE  -- глобально, чтобы остальные мигрированные файлы тоже видели

-- [ZCITY_PORT] config.lua переименован в sh_config.lua и грузится DarkRP-loader'ом автоматически
-- (раньше: include("config.lua") + AddCSLuaFile)

-- Основные параметры режима
MODE.name = "roleplay"
MODE.PrintName = "Roleplay"

zb = zb or {}
zb.Points = zb.Points or {}

-- Точки спавна для режима Roleplay
zb.Points.ROLEPLAY_SPAWN = zb.Points.ROLEPLAY_SPAWN or {}
zb.Points.ROLEPLAY_SPAWN.Color = Color(100, 255, 100)
zb.Points.ROLEPLAY_SPAWN.Name = "ROLEPLAY_SPAWN"

-- Настройки режима для разных карт (из конфига или дефолтные)
MODE.Maps = ROLEPLAY_MAP_CLASSES and {
    ["rp_*"] = {DefaultClass = ROLEPLAY_MAP_CLASSES["rp_*"] or "citizen"},
    ["gm_*"] = {DefaultClass = ROLEPLAY_MAP_CLASSES["gm_*"] or "citizen"},
    ["*"] = {DefaultClass = ROLEPLAY_MAP_CLASSES["*"] or "citizen"}
} or {
    ["rp_*"] = {DefaultClass = "citizen"},
    ["gm_*"] = {DefaultClass = "citizen"},
    ["*"] = {DefaultClass = "citizen"}
}

-- ============================================================================
-- Безопасные зоны
-- ----------------------------------------------------------------------------
-- Вокруг каждой точки спавна (ROLEPLAY_SPAWN) радиусом SafeZoneRadius юнитов
-- игрок не может стрелять.
-- NWBool "rp_safezone" пишется на сервере в sv_roleplay.lua, читается на обоих
-- сторонах для корректного клиентского предсказания.
-- ============================================================================

MODE.SafeZoneRadius = 600

function MODE:HG_MovementCalc_2( mul, ply, cmd, mv )
    if not IsValid(ply) or not cmd then return end
    if not ply:GetNWBool("rp_safezone", false) then return end

    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)
    if mv then
        mv:RemoveKey(IN_ATTACK)
        mv:RemoveKey(IN_ATTACK2)
    end
end
