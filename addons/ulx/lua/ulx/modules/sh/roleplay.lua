------------------------------ Roleplay Commands (Server) ------------------------------
-- Серверная часть команд для управления режимом Roleplay

local CATEGORY_NAME = "Roleplay"

-- Сетевые сообщения (только на сервере)
if SERVER then
    util.AddNetworkString("ULX_JobBanList")
    util.AddNetworkString("ULX_JobBanned")
    util.AddNetworkString("ULX_JobUnbanned")
    util.AddNetworkString("ULX_GiveMoney")
end

-- Таблица для хранения блокировок профессий
ulx.jobBans = ulx.jobBans or {}

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

-- Загрузка блокировок из файла
local function LoadJobBans()
    if file.Exists("ulx/jobbans.txt", "DATA") then
        local data = file.Read("ulx/jobbans.txt", "DATA")
        if data then
            ulx.jobBans = util.JSONToTable(data) or {}
        end
    end
end

-- Сохранение блокировок в файл
function SaveJobBans()
    if not file.Exists("ulx", "DATA") then
        file.CreateDir("ulx")
    end
    file.Write("ulx/jobbans.txt", util.TableToJSON(ulx.jobBans, true))
end

-- Загружаем при старте
LoadJobBans()

-- Проверка блокировки профессии
function ulx.IsJobBanned(ply, jobName)
    local steamID = ply:SteamID()
    if ulx.jobBans[steamID] and ulx.jobBans[steamID][jobName] then
        local banData = ulx.jobBans[steamID][jobName]
        if banData.unbanTime > os.time() then
            return true, banData.unbanTime - os.time()
        else
            -- Блокировка истекла, удаляем
            ulx.jobBans[steamID][jobName] = nil
            SaveJobBans()
            return false
        end
    end
    return false
end

-- Команда для блокировки профессии
function ulx.jobban(calling_ply, target_ply, jobName, duration, reason)
    if not IsValid(target_ply) then
        ULib.tsayError(calling_ply, "Игрок не найден", true)
        return
    end
    
    -- Проверяем, существует ли профессия
    local round = CurrentRound()
    if not round or round.name ~= "roleplay" then
        ULib.tsayError(calling_ply, "Режим Roleplay не активен", true)
        return
    end
    
    if not round.Jobs or not round.Jobs[jobName] then
        ULib.tsayError(calling_ply, "Профессия '" .. jobName .. "' не существует", true)
        return
    end
    
    -- Блокируем профессию
    local steamID = target_ply:SteamID()
    ulx.jobBans[steamID] = ulx.jobBans[steamID] or {}
    ulx.jobBans[steamID][jobName] = {
        unbanTime = os.time() + (duration * 60),
        reason = reason or "Не указана",
        admin = calling_ply:Nick()
    }
    
    SaveJobBans()
    
    -- Если игрок сейчас на этой профессии - переводим на гражданского
    if target_ply.RoleplayJob == jobName then
        target_ply.RoleplayJob = "Гражданский"
        target_ply:SetNWString("RoleplayJob", "Гражданский")
        
        if target_ply:Alive() then
            target_ply:Kill()
        end
    end
    
    -- Уведомления
    local timeStr = duration >= 60 and string.format("%.1f часов", duration / 60) or duration .. " минут"
    ulx.fancyLogAdmin(calling_ply, "#A заблокировал профессию #s для #T на #s", jobName, target_ply, timeStr)
    
    -- Отправляем цветное сообщение игроку
    net.Start("ULX_JobBanned")
    net.WriteString(jobName)
    net.WriteString(timeStr)
    net.WriteString(reason or "")
    net.Send(target_ply)
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
    if not IsValid(target_ply) then
        ULib.tsayError(calling_ply, "Игрок не найден", true)
        return
    end
    
    local steamID = target_ply:SteamID()
    if ulx.jobBans[steamID] and ulx.jobBans[steamID][jobName] then
        ulx.jobBans[steamID][jobName] = nil
        SaveJobBans()
        
        ulx.fancyLogAdmin(calling_ply, "#A разблокировал профессию #s для #T", jobName, target_ply)
        
        -- Отправляем цветное сообщение игроку
        net.Start("ULX_JobUnbanned")
        net.WriteString(jobName)
        net.Send(target_ply)
    else
        ULib.tsayError(calling_ply, "У игрока нет блокировки профессии '" .. jobName .. "'", true)
    end
end

local jobunban = ulx.command(CATEGORY_NAME, "ulx jobunban", ulx.jobunban, "!jobunban")
jobunban:addParam{type=ULib.cmds.PlayerArg}
jobunban:addParam{type=ULib.cmds.StringArg, hint="профессия", completes=jobList}
jobunban:defaultAccess(ULib.ACCESS_ADMIN)
jobunban:help("Разблокирует игроку доступ к профессии")

-- Команда для просмотра блокировок игрока
function ulx.jobbanlist(calling_ply, target_ply)
    if not IsValid(target_ply) then
        ULib.tsayError(calling_ply, "Игрок не найден", true)
        return
    end
    
    local steamID = target_ply:SteamID()
    if not ulx.jobBans[steamID] or table.Count(ulx.jobBans[steamID]) == 0 then
        net.Start("ULX_JobBanList")
        net.WriteString(target_ply:Nick())
        net.WriteBool(false) -- Нет блокировок
        net.Send(calling_ply)
        return
    end
    
    -- Собираем данные о блокировках
    local bans = {}
    for jobName, banData in pairs(ulx.jobBans[steamID]) do
        local timeLeft = banData.unbanTime - os.time()
        if timeLeft > 0 then
            local hours = math.floor(timeLeft / 3600)
            local minutes = math.floor((timeLeft % 3600) / 60)
            local timeStr = hours > 0 and string.format("%dч %dм", hours, minutes) or minutes .. "м"
            table.insert(bans, {
                job = jobName,
                time = timeStr,
                reason = banData.reason
            })
        end
    end
    
    net.Start("ULX_JobBanList")
    net.WriteString(target_ply:Nick())
    net.WriteBool(true) -- Есть блокировки
    net.WriteTable(bans)
    net.Send(calling_ply)
end

local jobbanlist = ulx.command(CATEGORY_NAME, "ulx jobbanlist", ulx.jobbanlist, "!jobbanlist")
jobbanlist:addParam{type=ULib.cmds.PlayerArg}
jobbanlist:defaultAccess(ULib.ACCESS_ADMIN)
jobbanlist:help("Показывает список блокировок профессий игрока")

-- Группы, которым разрешена выдача денег (помимо superadmin/console)
local GIVEMONEY_GROUPS = {
    dsuperadmin = true,
}

local function canGiveMoney(ply)
    if not IsValid(ply) then return true end -- консоль
    if ply:IsSuperAdmin() then return true end
    if GIVEMONEY_GROUPS[ply:GetUserGroup()] then return true end
    return false
end

-- Команда выдачи денег игроку
function ulx.givemoney(calling_ply, target_ply, amount)
    if not IsValid(target_ply) then
        ULib.tsayError(calling_ply, "Игрок не найден", true)
        return
    end

    -- Доступ: Super Admin / dsuperadmin / консоль
    if not canGiveMoney(calling_ply) then
        ULib.tsayError(calling_ply, "Эта команда доступна только Super Admin и DSuperAdmin", true)
        return
    end

    local round = CurrentRound()
    if not round or round.name ~= "roleplay" then
        ULib.tsayError(calling_ply, "Режим Roleplay не активен", true)
        return
    end

    if amount <= 0 then
        ULib.tsayError(calling_ply, "Сумма должна быть больше нуля", true)
        return
    end

    round:AddMoney(target_ply, amount, "admin_give", calling_ply)

    ulx.fancyLogAdmin(calling_ply, "#A выдал #N$ игроку #T", amount, target_ply)

    -- Уведомление получателю
    net.Start("ULX_GiveMoney")
    net.WriteInt(amount, 32)
    net.WriteString(IsValid(calling_ply) and calling_ply:Nick() or "Консоль")
    net.Send(target_ply)
end

local givemoney = ulx.command(CATEGORY_NAME, "ulx givemoney", ulx.givemoney, "!givemoney")
givemoney:addParam{type=ULib.cmds.PlayerArg}
givemoney:addParam{type=ULib.cmds.NumArg, min=1, max=1000000, hint="сумма"}
givemoney:defaultAccess(ULib.ACCESS_SUPERADMIN)
givemoney:help("Выдаёт игроку указанную сумму денег в режиме Roleplay")
