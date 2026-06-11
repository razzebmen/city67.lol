-- Серверная интеграция IGS (City67)
-- Обрабатываем чат-команды для открытия донат-меню сами,
-- не полагаясь на scc (его может не быть или он не успевает зарегистрироваться).

if CLIENT then return end

util.AddNetworkString("igs_broadcast_msg")
util.AddNetworkString("igs_open_donate_client")

-- Все варианты команд для открытия донат-меню
local OPEN_CMDS = {
    ["!donate"]  = true, ["/donate"]  = true,
    ["!донат"]   = true, ["/донат"]   = true,
    ["!shop"]    = true, ["/shop"]    = true,
    ["!магазин"] = true, ["/магазин"] = true,
}

-- Приоритет -100 — как в zcity_reports/!report,
-- чтобы наш хук гарантированно сработал до прочих обработчиков чата.
hook.Add("PlayerSay", "igs_donate_chat_cmds", function(ply, text)
    local t = string.lower(string.Trim(text or ""))
    if OPEN_CMDS[t] then
        net.Start("igs_open_donate_client")
        net.Send(ply)
        return ""
    end
end, -100)

-- ─── Периодическая рассылка ──────────────────────────────────────────────────

local function sendBroadcast()
    if #player.GetAll() == 0 then return end
    net.Start("igs_broadcast_msg")
    net.WriteUInt(1, 4)
    net.Broadcast()
end

-- Первая рассылка через 3 минуты после старта, затем каждые 5 минут
timer.Simple(180, function()
    sendBroadcast()
    timer.Create("igs_donate_broadcast", 300, 0, sendBroadcast)
end)
