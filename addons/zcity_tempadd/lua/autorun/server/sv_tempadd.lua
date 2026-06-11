-- =====================================================
-- ZCity Tempadd — временная выдача ULX-групп
-- =====================================================
-- Команды:
--   ulx tempadd   <player>  <group> <duration>   (!tempadd)
--   ulx temprm    <player>                        (!temprm)
--   ulx templist                                  (!templist)
--   ulx tempaddid <steamid> <group> <duration>   (!tempaddid)  -- работает оффлайн
--   ulx temprmid  <steamid>                        (!temprmid)   -- работает оффлайн
--
-- duration принимает ULX time-string: 5m, 1h, 1d, 30 (минуты).
-- steamid принимает STEAM_0:Y:Z или 64-битный (765...).
--
-- Сохраняется в локальный sqlite (data/sql.db), таблица ztempadd. После
-- рестарта сервера: активные записи переприменяются, истёкшие — снимаются.
-- Опрос истёкших — раз в 30 сек.
--
-- ULX группу выдаём через ULib.ucl.addUser. Так как у нас крутится
-- ulx_mysql_sync, изменение группы автоматически уйдёт в MySQL (общая БД
-- админок) и подтянется на других серверах.
-- =====================================================

if not SERVER then return end

local PREFIX = "[ZTempadd] "

-- Флаг "это наша собственная правка UCL" — чтобы хук авто-очистки (ниже)
-- не реагировал на addUser/removeUser, которые делает сам модуль.
local _internalUCL = false

-- ──────────────────────────────────────────────────────
-- Таблица
-- ──────────────────────────────────────────────────────
sql.Query([[
    CREATE TABLE IF NOT EXISTS ztempadd (
        steamid    TEXT PRIMARY KEY NOT NULL,
        old_group  TEXT,
        new_group  TEXT,
        expires_at INTEGER NOT NULL,
        added_by   TEXT,
        added_at   INTEGER
    )
]])

local function esc(s) return sql.SQLStr(tostring(s or "")) end

-- Нормализация ввода SteamID: принимает STEAM_0:Y:Z или 64-битный (17 цифр).
-- Возвращает канонический STEAM_ формат в верхнем регистре или nil.
local function normalizeSteamID(input)
    if not input then return nil end
    input = string.Trim(tostring(input))
    if input == "" then return nil end

    -- 64-битный: только цифры, длина 17 → конвертируем в STEAM_
    if input:match("^%d+$") and #input >= 17 then
        local sid = util.SteamIDFrom64(input)
        if sid and ULib.isValidSteamID(sid) then return sid:upper() end
        return nil
    end

    -- STEAM_X:Y:Z (X может быть 0 или 1 — приводим к валидной форме)
    local up = input:upper()
    if ULib.isValidSteamID(up) then return up end

    return nil
end

-- Имя группы по SteamID для оффлайн-игрока (из UCL), иначе "user".
local function uclGroupOf(steamID)
    local info = ULib.ucl.getUserInfoFromID and ULib.ucl.getUserInfoFromID(steamID)
    if info and info.group then return info.group end
    return "user"
end

-- Текущая группа: онлайн-игрок → его группа, иначе из UCL.
local function currentGroupOf(steamID)
    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID() == steamID then
            return ply:GetUserGroup() or "user"
        end
    end
    return uclGroupOf(steamID)
end

local function saveEntry(sid, oldGrp, newGrp, expires, by, at)
    sql.Query(string.format(
        "REPLACE INTO ztempadd (steamid, old_group, new_group, expires_at, added_by, added_at) VALUES (%s, %s, %s, %d, %s, %d)",
        esc(sid), esc(oldGrp), esc(newGrp), expires, esc(by), at
    ))
end

local function deleteEntry(sid)
    sql.Query("DELETE FROM ztempadd WHERE steamid = " .. esc(sid))
end

local function findEntry(sid)
    local rows = sql.Query("SELECT * FROM ztempadd WHERE steamid = " .. esc(sid))
    return rows and rows[1]
end

local function allEntries()
    return sql.Query("SELECT * FROM ztempadd") or {}
end

-- ──────────────────────────────────────────────────────
-- Применение / отмена через ULib
-- ──────────────────────────────────────────────────────
local function applyGroup(steamID, group)
    if not ULib or not ULib.ucl or not ULib.ucl.addUser then return false end
    -- ULib.ucl.addUser(steamID, allows, denies, group)
    _internalUCL = true
    pcall(ULib.ucl.addUser, steamID, nil, nil, group)
    _internalUCL = false
    -- Применяем к онлайн-игроку сразу
    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID() == steamID then
            ply:SetUserGroup(group)
            break
        end
    end
    return true
end

local function removeFromUCL(steamID)
    if not ULib or not ULib.ucl or not ULib.ucl.removeUser then return end
    _internalUCL = true
    pcall(ULib.ucl.removeUser, steamID)
    _internalUCL = false
end

-- Имя таймера индивидуального истечения. Не использую raw steamid в имени,
-- т.к. в нём двоеточия — берём чистый идентификатор через SteamIDTo64.
local function expireTimerName(sid)
    local sid64 = util.SteamIDTo64(sid) or sid
    return "ZTempadd_Expire_" .. sid64
end

local function clearExpireTimer(sid)
    local name = expireTimerName(sid)
    if timer.Exists(name) then timer.Remove(name) end
end

-- Снять tempadd → вернуть в старую группу
local function expireEntry(entry)
    local sid    = entry.steamid
    local oldGrp = entry.old_group or "user"

    clearExpireTimer(sid)

    if oldGrp == "user" or oldGrp == "" then
        -- Старая группа была user → просто удаляем из UCL, ULib вернёт в default
        removeFromUCL(sid)
        for _, ply in ipairs(player.GetAll()) do
            if ply:SteamID() == sid then ply:SetUserGroup("user") break end
        end
    else
        applyGroup(sid, oldGrp)
    end

    deleteEntry(sid)
    print(PREFIX .. "Истёк tempadd для " .. sid .. " (" .. (entry.new_group or "?") ..
          " → " .. oldGrp .. ")")
end

-- Точный таймер на конкретное истечение (sec до expires_at). Это даёт снятие
-- ровно в момент истечения, а не «когда дойдёт фоновый poll».
local function scheduleExpireTimer(sid, expiresAt)
    clearExpireTimer(sid)
    local secs = math.max(1, tonumber(expiresAt) - os.time())
    timer.Create(expireTimerName(sid), secs, 1, function()
        local entry = findEntry(sid)
        if not entry then return end
        if tonumber(entry.expires_at) > os.time() then
            -- Запись была продлена пока таймер ждал — перепланируем
            scheduleExpireTimer(sid, entry.expires_at)
            return
        end
        expireEntry(entry)
    end)
end

-- Фоновая страховка: если индивидуальный таймер потерялся (например, sql
-- упал, или timer был удалён где-то ещё) — раз в 10 сек сверяем все записи.
local function expireCheck()
    local now = os.time()
    local rows = sql.Query("SELECT * FROM ztempadd WHERE expires_at <= " .. now)
    if not rows then return end
    for _, r in ipairs(rows) do expireEntry(r) end
end

-- ──────────────────────────────────────────────────────
-- Bootstrap: при старте переприменяем активные tempadd
-- ──────────────────────────────────────────────────────
local function reapplyAll()
    local now = os.time()
    local rows = sql.Query("SELECT * FROM ztempadd WHERE expires_at > " .. now)
    rows = rows or {}

    for _, r in ipairs(rows) do
        if ULib.ucl.groups and ULib.ucl.groups[r.new_group] then
            applyGroup(r.steamid, r.new_group)
            scheduleExpireTimer(r.steamid, r.expires_at)
        else
            print(PREFIX .. "WARN: группа '" .. tostring(r.new_group) ..
                  "' не существует, удаляю запись " .. r.steamid)
            deleteEntry(r.steamid)
        end
    end

    -- И тут же снимаем истёкшие, которые накопились пока сервер лежал
    expireCheck()

    print(PREFIX .. "Bootstrap: восстановлено " .. #rows .. " активных tempadd-записей")
end

hook.Add("Initialize", "ZTempadd_Reapply", function()
    timer.Simple(5, reapplyAll)
end)

-- Игрок зашёл → если у него висит tempadd, применить (мог попасть до Reapply)
hook.Add("PlayerAuthed", "ZTempadd_OnAuth", function(ply)
    timer.Simple(2, function()
        if not IsValid(ply) then return end
        local sid = ply:SteamID()
        local entry = findEntry(sid)
        if not entry then return end
        if tonumber(entry.expires_at) <= os.time() then
            expireEntry(entry)
            return
        end
        if ply:GetUserGroup() ~= entry.new_group then
            ply:SetUserGroup(entry.new_group)
        end
        -- Обеспечим что точный таймер существует (мог сбросится на reload).
        if not timer.Exists(expireTimerName(sid)) then
            scheduleExpireTimer(sid, entry.expires_at)
        end
    end)
end)

-- Фоновая страховка (поверх индивидуальных таймеров): раз в 10 сек.
timer.Create("ZTempadd_Tick", 10, 0, expireCheck)

-- ──────────────────────────────────────────────────────
-- Авто-очистка при ручном вмешательстве в UCL
-- ──────────────────────────────────────────────────────
-- Если админ снимает/меняет группу штатными командами ULX
--   • ulx removeuser / removeuserid  → ULibUserRemoved
--   • ulx user <name> <group>        → ULibUserGroupChange
-- то наша tempadd-запись должна быть аннулирована, иначе она «воскреснет»
-- на следующем PlayerAuthed или перетрёт ручную группу при истечении.
--
-- ВАЖНО: это НЕ откатывает группу (её уже выставил ULX/sync). Мы лишь
-- удаляем запись из ztempadd и снимаем таймер — то есть «забываем» о
-- временной выдаче, отдавая контроль администратору.
--
-- Не зацикливается с ulx_mysql_sync: хук трогает только локальный sqlite и
-- таймеры, не вызывая addUser/removeUser/SetUserGroup.

-- Снять tempadd-«учёт» не трогая UCL (группу уже сменил кто-то другой).
local function forgetEntry(steamID, reason)
    local entry = findEntry(steamID)
    if not entry then return end
    clearExpireTimer(steamID)
    deleteEntry(steamID)
    print(PREFIX .. "tempadd аннулирован (" .. (reason or "manual") .. ") для " ..
          steamID .. " — запись удалена, группа под контролем админа")
end

-- Нормализует id из хуков ULib (SteamID / UniqueID / IP) к SteamID.
local function hookIDToSteamID(id)
    local s = tostring(id or "")
    if s:match("^STEAM_%d:%d:%d+$") then return s:upper() end
    if ULib and ULib.getPlyByID then
        local ply = ULib.getPlyByID(s)
        if IsValid(ply) then return ply:SteamID() end
    end
    return nil
end

hook.Add("ULibUserRemoved", "ZTempadd_UCLRemoved", function(id)
    if _internalUCL then return end -- наша собственная правка — игнор
    local sid = hookIDToSteamID(id)
    if not sid then return end
    forgetEntry(sid, "ulx removeuser")
end)

hook.Add("ULibUserGroupChange", "ZTempadd_UCLGroupChange", function(id, _allows, _denies, group)
    if _internalUCL then return end -- наша собственная правка — игнор
    local sid = hookIDToSteamID(id)
    if not sid then return end

    local entry = findEntry(sid)
    if not entry then return end
    -- Если кто-то выставил ровно ту же временную группу — это, скорее всего,
    -- эхо синхронизации (ulx_mysql_sync применил наш же ранг). Не трогаем.
    if group and group == entry.new_group then return end

    forgetEntry(sid, "ulx user → " .. tostring(group))
end)

-- ──────────────────────────────────────────────────────
-- ULX команды (ждём пока ULX подгрузится)
-- ──────────────────────────────────────────────────────
local function registerCommands()
    if not ulx or not ulx.command or not ULib or not ULib.cmds then
        timer.Simple(2, registerCommands)
        return
    end
    if ulx.tempadd then return end -- уже зарегистрирован (autorefresh)

    local CATEGORY = "ZCity"

    -- ─── Ядро выдачи по SteamID (online или offline) ──
    -- Возвращает true,humanTime,verb при успехе или false,errMsg при ошибке.
    local function doTempadd(steamID, group, minutes, byName, knownOldGroup)
        if not ULib.ucl.groups[group] then
            return false, "Группа '" .. tostring(group) .. "' не существует"
        end
        if not minutes or minutes <= 0 then
            return false, "Длительность должна быть положительной"
        end

        local now = os.time()
        local expires = now + math.floor(minutes * 60)
        local oldGroup = knownOldGroup or currentGroupOf(steamID)

        -- Если уже есть активная tempadd-запись — сохраняем оригинальную old_group
        -- (иначе при повторной выдаче old_group будет "временная_группа_до_этого")
        local existing = findEntry(steamID)
        if existing then
            oldGroup = existing.old_group or oldGroup
        end

        saveEntry(steamID, oldGroup, group, expires, byName, now)
        applyGroup(steamID, group)
        scheduleExpireTimer(steamID, expires)

        local human = ULib.secondsToStringTime(math.floor(minutes * 60))
        return true, human, existing and "продлил" or "выдал"
    end

    -- ─── Ядро снятия по SteamID ───────────────────────
    local function doTemprm(steamID)
        local entry = findEntry(steamID)
        if not entry then return false end
        expireEntry(entry)
        return true
    end

    -- ─── ulx tempadd ──────────────────────────────────
    function ulx.tempadd(calling_ply, target, group, minutes)
        local steamID = target:SteamID()
        local byName = IsValid(calling_ply)
            and (calling_ply:Nick() .. "(" .. calling_ply:SteamID() .. ")")
            or "(Console)"

        local ok, a, verb = doTempadd(steamID, group, minutes, byName, target:GetUserGroup() or "user")
        if not ok then
            ULib.tsayError(calling_ply, a)
            return
        end

        ulx.fancyLogAdmin(calling_ply,
            "#A " .. verb .. " #T временную группу '" .. group .. "' на " .. a,
            target)
    end

    local cmd = ulx.command(CATEGORY, "ulx tempadd", ulx.tempadd, "!tempadd")
    cmd:addParam{ type = ULib.cmds.PlayerArg }
    cmd:addParam{ type = ULib.cmds.StringArg, hint = "group" }
    cmd:addParam{ type = ULib.cmds.NumArg, hint = "minutes (5m/1h/1d/...)",
                  ULib.cmds.allowTimeString, min = 1 }
    cmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    cmd:help("Выдать игроку временную группу")

    -- ─── ulx temprm ───────────────────────────────────
    function ulx.temprm(calling_ply, target)
        local steamID = target:SteamID()
        if not doTemprm(steamID) then
            ULib.tsayError(calling_ply, "У " .. target:Nick() .. " нет активного tempadd")
            return
        end
        ulx.fancyLogAdmin(calling_ply, "#A снял временную группу с #T", target)
    end

    local cmd2 = ulx.command(CATEGORY, "ulx temprm", ulx.temprm, "!temprm")
    cmd2:addParam{ type = ULib.cmds.PlayerArg }
    cmd2:defaultAccess(ULib.ACCESS_SUPERADMIN)
    cmd2:help("Снять временную группу (вернуть прежнюю)")

    -- ─── ulx tempaddid ────────────────────────────────
    -- Выдача по SteamID — работает даже если игрок оффлайн.
    function ulx.tempaddid(calling_ply, steamInput, group, minutes)
        local steamID = normalizeSteamID(steamInput)
        if not steamID then
            ULib.tsayError(calling_ply, "Некорректный SteamID: '" .. tostring(steamInput) ..
                "' (ожидается STEAM_0:Y:Z или 64-битный)")
            return
        end

        local byName = IsValid(calling_ply)
            and (calling_ply:Nick() .. "(" .. calling_ply:SteamID() .. ")")
            or "(Console)"

        local ok, a, verb = doTempadd(steamID, group, minutes, byName)
        if not ok then
            ULib.tsayError(calling_ply, a)
            return
        end

        -- Имя для лога: онлайн-ник, либо сохранённое в UCL, либо сам SteamID
        local name = steamID
        for _, ply in ipairs(player.GetAll()) do
            if ply:SteamID() == steamID then name = ply:Nick() break end
        end
        local info = ULib.ucl.getUserInfoFromID(steamID)
        if name == steamID and info and info.name then name = info.name end

        ulx.fancyLogAdmin(calling_ply, "#A " .. verb .. " временную группу '" .. group ..
            "' (" .. name .. " / " .. steamID .. ") на " .. a)
    end

    local cmd_aid = ulx.command(CATEGORY, "ulx tempaddid", ulx.tempaddid, "!tempaddid")
    cmd_aid:addParam{ type = ULib.cmds.StringArg, hint = "steamid (STEAM_0:.. или 64-bit)" }
    cmd_aid:addParam{ type = ULib.cmds.StringArg, hint = "group" }
    cmd_aid:addParam{ type = ULib.cmds.NumArg, hint = "minutes (5m/1h/1d/...)",
                  ULib.cmds.allowTimeString, min = 1 }
    cmd_aid:defaultAccess(ULib.ACCESS_SUPERADMIN)
    cmd_aid:help("Выдать временную группу по SteamID (можно оффлайн)")

    -- ─── ulx temprmid ─────────────────────────────────
    -- Снятие по SteamID — работает даже если игрок оффлайн.
    function ulx.temprmid(calling_ply, steamInput)
        local steamID = normalizeSteamID(steamInput)
        if not steamID then
            ULib.tsayError(calling_ply, "Некорректный SteamID: '" .. tostring(steamInput) .. "'")
            return
        end
        if not doTemprm(steamID) then
            ULib.tsayError(calling_ply, "Нет активного tempadd для " .. steamID)
            return
        end
        ulx.fancyLogAdmin(calling_ply, "#A снял временную группу с " .. steamID)
    end

    local cmd_rid = ulx.command(CATEGORY, "ulx temprmid", ulx.temprmid, "!temprmid")
    cmd_rid:addParam{ type = ULib.cmds.StringArg, hint = "steamid (STEAM_0:.. или 64-bit)" }
    cmd_rid:defaultAccess(ULib.ACCESS_SUPERADMIN)
    cmd_rid:help("Снять временную группу по SteamID (можно оффлайн)")

    -- ─── ulx templist ─────────────────────────────────
    function ulx.templist(calling_ply)
        local rows = allEntries()
        if #rows == 0 then
            ULib.tsay(calling_ply, "Активных tempadd нет")
            return
        end
        local now = os.time()
        ULib.tsay(calling_ply, "=== Активные tempadd (" .. #rows .. ") ===")
        for _, r in ipairs(rows) do
            local left = tonumber(r.expires_at) - now
            local leftStr = left > 0 and ULib.secondsToStringTime(left) or "истёк"
            local name = r.steamid
            for _, ply in ipairs(player.GetAll()) do
                if ply:SteamID() == r.steamid then name = ply:Nick() .. " (" .. r.steamid .. ")" break end
            end
            ULib.tsay(calling_ply, string.format("  %s: %s → %s, %s, by %s",
                name, r.old_group or "?", r.new_group or "?", leftStr, r.added_by or "?"))
        end
    end

    local cmd3 = ulx.command(CATEGORY, "ulx templist", ulx.templist, "!templist")
    cmd3:defaultAccess(ULib.ACCESS_SUPERADMIN)
    cmd3:help("Список активных временных групп")

    print(PREFIX .. "Команды зарегистрированы: tempadd / temprm / templist / tempaddid / temprmid")
end

hook.Add("Initialize",     "ZTempadd_RegCmds_Init", function() timer.Simple(3, registerCommands) end)
hook.Add("InitPostEntity", "ZTempadd_RegCmds_IPE",  function() timer.Simple(2, registerCommands) end)
timer.Simple(5, registerCommands)

print(PREFIX .. "Модуль временных рангов загружен")
