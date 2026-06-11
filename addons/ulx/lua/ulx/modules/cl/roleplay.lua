------------------------------ Roleplay Commands (Client) ------------------------------
-- Клиентская часть команд для управления режимом Roleplay

local CATEGORY_NAME = "Roleplay"

-- Получение сообщения о блокировке профессии
net.Receive("ULX_JobBanned", function()
    local jobName = net.ReadString()
    local timeStr = net.ReadString()
    local reason = net.ReadString()
    
    chat.AddText(
        Color(255, 100, 100), "[ULX] ",
        Color(255, 255, 255), "Вам заблокирована профессия ",
        Color(255, 200, 100), "'" .. jobName .. "'",
        Color(255, 255, 255), " на ",
        Color(100, 255, 100), timeStr
    )
    
    if reason ~= "" then
        chat.AddText(
            Color(255, 100, 100), "[ULX] ",
            Color(255, 255, 255), "Причина: ",
            Color(255, 150, 150), reason
        )
    end
end)

-- Получение сообщения о разблокировке профессии
net.Receive("ULX_JobUnbanned", function()
    local jobName = net.ReadString()
    
    chat.AddText(
        Color(100, 255, 100), "[ULX] ",
        Color(255, 255, 255), "Профессия ",
        Color(255, 200, 100), "'" .. jobName .. "'",
        Color(255, 255, 255), " разблокирована"
    )
end)

-- Получение цветного списка блокировок
net.Receive("ULX_JobBanList", function()
    local playerName = net.ReadString()
    local hasBans = net.ReadBool()
    
    if not hasBans then
        chat.AddText(
            Color(100, 200, 255), "[ULX] ",
            Color(255, 255, 255), "У игрока ",
            Color(255, 200, 100), playerName,
            Color(255, 255, 255), " нет блокировок профессий"
        )
        return
    end
    
    local bans = net.ReadTable()
    
    chat.AddText(
        Color(100, 200, 255), "[ULX] ",
        Color(255, 255, 255), "Блокировки профессий для ",
        Color(255, 200, 100), playerName,
        Color(255, 255, 255), ":"
    )
    
    for _, ban in ipairs(bans) do
        chat.AddText(
            Color(255, 100, 100), "  • ",
            Color(255, 200, 100), ban.job,
            Color(255, 255, 255), ": ",
            Color(100, 255, 100), ban.time,
            Color(255, 255, 255), " (Причина: ",
            Color(255, 150, 150), ban.reason,
            Color(255, 255, 255), ")"
        )
    end
end)

-- Список профессий для автодополнения
local jobList = {
    "Гражданский",
    "Полицейский",
    "Спецназ",
    "Мэр",
    "Глава Полиции",
    "Бандит",
    "Продавец Оружия",
    "Солдат ЦАХАЛ",
    "Глава ЦАХАЛ"
}

-- Команда для блокировки профессии
function ulx.jobban(calling_ply, target_ply, jobName, duration, reason)
    -- Клиентская часть пустая, вся логика на сервере
end

local jobban = ulx.command(CATEGORY_NAME, "ulx jobban", ulx.jobban, "!jobban")
jobban:addParam{type=ULib.cmds.PlayerArg}
jobban:addParam{type=ULib.cmds.StringArg, hint="профессия", completes=jobList}
jobban:addParam{type=ULib.cmds.NumArg, min=1, default=60, hint="минуты"}
jobban:addParam{type=ULib.cmds.StringArg, hint="причина", ULib.cmds.optional}
jobban:defaultAccess(ULib.ACCESS_ADMIN)
jobban:help("Блокирует игроку доступ к профессии на указанное время")

-- Команда для разблокировки профессии
function ulx.jobunban(calling_ply, target_ply, jobName)
    -- Клиентская часть пустая, вся логика на сервере
end

local jobunban = ulx.command(CATEGORY_NAME, "ulx jobunban", ulx.jobunban, "!jobunban")
jobunban:addParam{type=ULib.cmds.PlayerArg}
jobunban:addParam{type=ULib.cmds.StringArg, hint="профессия", completes=jobList}
jobunban:defaultAccess(ULib.ACCESS_ADMIN)
jobunban:help("Разблокирует игроку доступ к профессии")

-- Команда для просмотра блокировок игрока
function ulx.jobbanlist(calling_ply, target_ply)
    -- Клиентская часть пустая, вся логика на сервере
end

local jobbanlist = ulx.command(CATEGORY_NAME, "ulx jobbanlist", ulx.jobbanlist, "!jobbanlist")
jobbanlist:addParam{type=ULib.cmds.PlayerArg}
jobbanlist:defaultAccess(ULib.ACCESS_ADMIN)
jobbanlist:help("Показывает список блокировок профессий игрока")

-- Уведомление о получении денег от администратора
net.Receive("ULX_GiveMoney", function()
    local amount = net.ReadInt(32)
    local adminName = net.ReadString()

    chat.AddText(
        Color(100, 255, 100), "[ULX] ",
        Color(255, 255, 255), "Администратор ",
        Color(255, 200, 100), adminName,
        Color(255, 255, 255), " выдал вам ",
        Color(100, 255, 100), "$" .. amount
    )
end)

-- Команда выдачи денег игроку
function ulx.givemoney(calling_ply, target_ply, amount)
    -- Клиентская часть пустая, вся логика на сервере
end

local givemoney = ulx.command(CATEGORY_NAME, "ulx givemoney", ulx.givemoney, "!givemoney")
givemoney:addParam{type=ULib.cmds.PlayerArg}
givemoney:addParam{type=ULib.cmds.NumArg, min=1, max=1000000, hint="сумма"}
givemoney:defaultAccess(ULib.ACCESS_SUPERADMIN)
givemoney:help("Выдаёт игроку указанную сумму денег в режиме Roleplay")
