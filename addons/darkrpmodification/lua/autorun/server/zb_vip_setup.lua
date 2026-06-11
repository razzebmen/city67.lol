-- VIP-конфигурация сервера:
--   * VIP reserved slots ПОЛНОСТЬЮ ОТКЛЮЧЕНЫ (по запросу)
--   * Регистрация иконки VIP для клиентов (оставлена — к слотам отношения не имеет)

if not SERVER then return end

-- resource.AddFile — клиенты скачают иконку VIP (для VGUI/Scoreboard).
resource.AddFile("materials/zcity_icons/vip.png")
resource.AddFile("materials/zcity_icons/vip.vtf")

-- ULX reserved slots ОТКЛЮЧЕНЫ.
-- Сбрасываем ЯВНО после загрузки: ulx_rslots* — FCVAR_ARCHIVE, поэтому без
-- явного сброса остались бы старые значения (mode=2, slots=5) из конфига ULX.
-- rslotsMode 0 = система зарезервированных слотов выключена (резервируют только
-- режимы 1/2/3 — см. ulx/modules/slots.lua: calcSlots).
hook.Add("InitPostEntity", "ZCity_VIP_RslotsConfig", function()
    timer.Simple(2, function()
        RunConsoleCommand("ulx_rslotsMode",    "0")
        RunConsoleCommand("ulx_rslots",        "0")
        RunConsoleCommand("ulx_rslotsVisible", "0")
        print("[VIP] Reserved slots ОТКЛЮЧЕНЫ (mode=0, slots=0)")
    end)
end)
