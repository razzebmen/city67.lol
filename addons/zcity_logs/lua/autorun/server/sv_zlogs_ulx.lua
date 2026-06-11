--[[
    ZCity Logs — ULX-команда `ulx logs` + чат-триггер `!logs`.

    Подход «суспендер + ремень»: открыть меню должно быть возможно через
    ЛЮБОЙ из путей, чтобы !logs работал у всех админских групп независимо
    от состояния groups.txt и порядка загрузки аддонов.

      1) ULX команда `ulx logs` (defaultAccess = ACCESS_ALL).
      2) Принудительный groupAllow «ulx logs» для всех админ-групп — на
         каждом старте сервера (а не только при первой регистрации).
      3) Чат-триггер на стандартном PlayerSay (fallback для ванильных сценариев).
      4) Чат-триггер на HG_PlayerSay — этим хуком этот гейммод реально
         обрабатывает чат (homigrad/zchat/sh_chat.lua), стандартный PlayerSay
         тоже фаерится оттуда, но HG_PlayerSay стабильнее по таймину.
      5) Концоманды `zlogs` и `zlogs_open` как клиентский фолбэк.

    Реальный гейт доступа всегда — ZLogs.CanView (см. sv_zlogs_net.lua).
]]

if not ZLogs then return end

util.AddNetworkString("zlogs_open_menu")

-- ============================================
-- Список админ-групп для принудительной выдачи "ulx logs"
-- ============================================
local ADMIN_GROUPS = {
    "admin", "superadmin",
    "moderator", "dmoderator",
    "dadmin", "dsuperadmin",
    "operator",
}

-- ============================================
-- Открытие меню (вызывается из ULX-команды и фолбэков)
-- ============================================
local function openLogsFor(ply)
    if not IsValid(ply) then return false end
    if not ZLogs.CanView(ply) then
        ply:ChatPrint("[Логи] Доступ запрещён")
        return false
    end
    net.Start("zlogs_open_menu")
    net.Send(ply)
    return true
end

-- ============================================
-- Раздать привилегию "ulx logs" всем админ-группам.
-- Запускается на каждом старте, не зависит от регистрации команды.
-- ============================================
local function grantAdminAccess()
    if not (ULib and ULib.ucl and ULib.ucl.groupAllow) then return end
    local changedAny = false
    for _, grp in ipairs(ADMIN_GROUPS) do
        if ULib.ucl.groups and ULib.ucl.groups[grp] then
            -- groupAllow возвращает true только если право реально добавилось.
            -- Иначе (право уже есть) — no-op, и UCLChanged повторно не фаерится.
            if ULib.ucl.groupAllow(grp, "ulx logs") then
                changedAny = true
            end
        end
    end
    -- Печатаем ТОЛЬКО когда что-то реально выдали. Раньше MsgN стоял
    -- безусловно и спамил на каждый UCLChanged (коннекты, sync, баны...).
    if changedAny then
        MsgN("[ZLogs] Привилегия 'ulx logs' выдана всем админским группам")
    end
end

-- ============================================
-- Регистрация ULX-команды (один раз)
-- ============================================
local function tryRegister()
    if not ulx or not ulx.command then
        timer.Simple(5, tryRegister)
        return
    end

    -- Регистрация команды только если её ещё нет.
    -- groupAllow ниже выполняется НЕЗАВИСИМО — на каждом старте.
    if not (ulx.cmdsByName and ulx.cmdsByName["logs"]) then
        function ulx.zlogsOpen(callingPly)
            if not IsValid(callingPly) then
                ULib.console(callingPly, "Команда доступна только для игроков")
                return
            end
            openLogsFor(callingPly)
        end

        -- defaultAccess = ACCESS_ALL: ULX пропускает команду для всех.
        -- Реальная проверка прав — внутри openLogsFor (ZLogs.CanView).
        local cmd = ulx.command("Логи", "ulx logs", ulx.zlogsOpen, "!logs")
        cmd:defaultAccess(ULib.ACCESS_ALL)
        cmd:help("Открыть меню логов сервера")

        MsgN("[ZLogs] ULX команда 'ulx logs' зарегистрирована")
    end

    -- Выдать "ulx logs" всем админ-группам — ВСЕГДА, не только при первой регистрации.
    -- Это покрывает случаи, когда groups.txt был отредактирован вручную / через XGUI
    -- и привилегия пропала, либо когда команда была зарегистрирована другим
    -- кодом со стрикт-доступом.
    grantAdminAccess()
end

hook.Add("Initialize", "zlogs_register_ulx", function()
    timer.Simple(3, tryRegister)
end)

-- Подстраховка: если ULib загружается асинхронно, дополнительно
-- перепроверяем привилегию когда ULib сигналит о готовности UCL.
hook.Add("UCLChanged", "zlogs_grant_on_uclchange", function()
    grantAdminAccess()
end)

-- ============================================
-- Концоманда `zlogs` — серверный фолбэк
-- ============================================
concommand.Add("zlogs", function(ply)
    if not IsValid(ply) then
        MsgN("[ZLogs] Концоманда требует игрока, используйте 'ulx logs'")
        return
    end
    openLogsFor(ply)
end)

-- Live toggle (включить/отключить трансляцию логов в чат)
concommand.Add("zlogs_live", function(ply, _, args)
    if not IsValid(ply) or not ZLogs.CanView(ply) then return end
    local enable = args[1] == "1" or args[1] == "true" or args[1] == "on"
    ply.ZLogsLive = enable
    ply:ChatPrint("[Логи] Live режим: " .. (enable and "ВКЛ" or "ВЫКЛ"))
end)

-- ============================================
-- Чат-триггер: !logs / /logs / !лог / !логи / /лог / /логи
-- ============================================
local chatTriggers = {
    ["!logs"] = true, ["/logs"] = true,
    ["/лог"]  = true, ["/логи"] = true,
    ["!лог"]  = true, ["!логи"] = true,
}

-- Проверка одного сообщения на триггер.
-- Возвращает true если это команда и она была обработана (нужно подавить чат).
local function handleChatTrigger(ply, text)
    if not IsValid(ply) then return false end
    local trimmed = string.lower(string.Trim(text or ""))
    if not chatTriggers[trimmed] then return false end
    openLogsFor(ply)  -- внутри сам сообщит об отказе, если нет прав
    return true
end

-- 1) Стандартный PlayerSay — для ванильных сценариев / других гейммодов.
hook.Add("PlayerSay", "zlogs_chatopen", function(ply, text)
    if handleChatTrigger(ply, text) then return "" end
end)

-- 2) HG_PlayerSay — основной хук чата в этом гейммоде (homigrad zchat).
--    txtTbl это таблица { text }, мы можем затереть её, чтобы скрыть
--    команду из чата.
hook.Add("HG_PlayerSay", "zlogs_chatopen_hg", function(ply, txtTbl, text)
    if not IsValid(ply) then return end
    local raw = text
    if not raw and type(txtTbl) == "table" then raw = txtTbl[1] end
    if handleChatTrigger(ply, raw) then
        -- Скрыть команду из общего чата
        if type(txtTbl) == "table" then txtTbl[1] = "" end
    end
end)
