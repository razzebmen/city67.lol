--[[---------------------------------------------------------------------------
FrePorts — клиентское подавление "@ текст" в обычном чате для стаффа.
Когда стафф пишет "@ текст", сообщение уходит в ULX asay (работает),
но ZChat/GMod дополнительно показывает "@ текст" в обычном чате локально.
Хук OnPlayerChat с return true убирает это визуальное дублирование.
---------------------------------------------------------------------------]]
if not CLIENT then return end

hook.Add("OnPlayerChat", "freports_suppress_at_staff", function(ply, text)
    if not IsValid(ply) or not isstring(text) then return end
    -- Проверяем только сообщения начинающиеся с "@ "
    local cmd = (freports and freports.config and freports.config.command) or "@"
    if string.sub(text, 1, #cmd + 1) ~= cmd .. " " then return end
    -- Подавляем только если говорящий — стафф (WhoCanReceiveReports)
    local groups = freports and freports.config and freports.config.WhoCanReceiveReports
    if groups and groups[ply:GetUserGroup()] then
        return true -- скрыть из обычного чата
    end
end)
