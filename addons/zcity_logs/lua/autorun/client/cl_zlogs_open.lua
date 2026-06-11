--[[
    ZCity Logs — клиентские команды открытия меню.
]]

if not ZLogs then return end

-- Сервер просит клиента открыть меню
net.Receive("zlogs_open_menu", function()
    if ZLogs.OpenMenu then ZLogs.OpenMenu() end
end)

-- Локальная концоманда (на случай если игрок биндит на клавишу).
-- Без клиентского гейта по группам — сервер проверит права в zlogs_open_request
-- (раньше из-за устаревшего списка групп админам "operator"/кастомным рангам
--  выскакивало "Доступ только для модераторов и выше" ещё до запроса на сервер).
concommand.Add("zlogs_open", function()
    net.Start("zlogs_open_request")
    net.SendToServer()
end)

-- Чат-команда !logs / !лог / !логи — фолбэк, если ULX или серверный PlayerSay
-- не подцепили команду. Server решает, открывать меню или отказать.
hook.Add("OnPlayerChat", "zlogs_chatcmd", function(ply, msg)
    if ply ~= LocalPlayer() then return end
    local m = string.lower(string.Trim(msg or ""))
    if m == "!logs" or m == "/logs" or m == "!лог" or m == "!логи" or m == "/лог" or m == "/логи" then
        timer.Simple(0.05, function()
            RunConsoleCommand("zlogs_open")
        end)
        return true
    end
end)

-- Сервер подтвердил права — открываем меню
net.Receive("zlogs_open_request", function()
    if ZLogs.OpenMenu then ZLogs.OpenMenu() end
end)
