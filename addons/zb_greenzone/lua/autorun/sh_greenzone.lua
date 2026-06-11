-- =====================================================
-- ZB Greenzone — shared init
-- =====================================================
-- Безопасные («зелёные») зоны: AABB-области, где игрок автоматически
-- получает god mode. Расставляются админом через тулган zb_greenzone.
-- Сохраняются per-карта в data/zb_greenzones/<map>.json.

ZBGreenzone = ZBGreenzone or {}
ZBGreenzone.Version = 1

-- Список net-строк, регистрируемых на сервере и используемых обеими сторонами
ZBGreenzone.NET = {
    SYNC   = "zb_greenzone_sync",     -- сервер→клиент: полный список зон
    CREATE = "zb_greenzone_create",   -- клиент→сервер: создать зону (mins/maxs)
    DELETE = "zb_greenzone_delete",   -- клиент→сервер: удалить ближайшую к точке
    NOTIFY = "zb_greenzone_notify",   -- сервер→клиент (targeted): "Безопасная зона"
}

if SERVER then
    for _, name in pairs(ZBGreenzone.NET) do
        util.AddNetworkString(name)
    end

    -- Гарантируем доставку клиентских/общих файлов
    AddCSLuaFile("autorun/sh_greenzone.lua")
    AddCSLuaFile("autorun/client/cl_greenzone.lua")
    AddCSLuaFile("weapons/gmod_tool/stools/zb_greenzone.lua")
    print("[Greenzone] sh_greenzone.lua: SERVER + AddCSLuaFile зарегистрированы")
else
    print("[Greenzone] sh_greenzone.lua: CLIENT, ZBGreenzone.NET=" .. tostring(ZBGreenzone.NET and ZBGreenzone.NET.SYNC))
end
