-- Server-side XGUI Roleplay module
-- Запись убийств производится в sv_roleplay.lua (gamemode).
-- Здесь только сетевая строка, право доступа и команда запроса.

util.AddNetworkString("XGUI_KillLogs")

-- Регистрируем ULX-право (видно в XGUI → Groups)
hook.Add("ULibPostInit", "XGUI_KillLogs_RegisterAccess", function()
    ULib.ucl.registerAccess(
        "xgui_killlogs",
        "admin",
        "Просмотр логов убийств на вкладке Логи в XGUI.",
        "XGUI"
    )
end)

local function hasKillLogsAccess(ply)
    return IsValid(ply) and ULib.ucl.query(ply, "xgui_killlogs")
end

-- ============================================================
--  КОМАНДА ЗАПРОСА ЛОГОВ
-- ============================================================
concommand.Add("xgui_getkilllogs", function(ply, cmd, args)
    if not hasKillLogsAccess(ply) then return end

    local filter   = args[1] or ""
    local logs     = RoleplayKillLogs or {}
    local filtered = {}

    if filter == "" then
        filtered = logs
    else
        local lf = string.lower(filter)
        for _, entry in ipairs(logs) do
            if string.find(string.lower(entry.killer or ""), lf, 1, true)
            or string.find(string.lower(entry.victim or ""), lf, 1, true) then
                table.insert(filtered, entry)
            end
        end
    end

    net.Start("XGUI_KillLogs")
    net.WriteTable(filtered)
    net.Send(ply)
end)
