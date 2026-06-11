-- =====================================================
-- ULX ↔ MySQL: синхронизация админок (групп пользователей)
-- =====================================================
-- БД: money @ УКАЖИТЕ_IP_БД (консолидация кластера)
-- Таблица: ulib_users (steamid, name, usergroup, allow, deny, updated_at)
--
-- АРХИТЕКТУРА (важно):
--   ULX — ЕДИНСТВЕННЫЙ источник правды о том, кто админ.
--   Группы реплицируются между серверами по принципу LAST-WRITER-WINS
--   с томбстоунами: и выдача, и снятие — это запись строки со свежим
--   updated_at (часы берём у самой БД, поэтому TZ серверов не важна).
--
--   • Выдача ранга  → строка usergroup=<группа>, updated_at=NOW
--   • Снятие ранга  → ТОМБСТОУН: строка usergroup='user', updated_at=NOW
--                     (НЕ DELETE — иначе «отсутствие строки» становится
--                      двусмысленным и снятие воскресает при реконнекте)
--   • При входе игрока → pull его строки, применяем как есть (выдача/снятие)
--   • Каждые 30 сек     → pull дельты (updated_at > _lastPullTs)
--   • Старые томбстоуны периодически вычищаются (ретенция).
--
-- Nova Defender group-protection ПРИНУДИТЕЛЬНО отключается ниже, чтобы он
-- не выступал вторым авторитетом и не возвращал/не снимал группы сам.
-- =====================================================

if not SERVER then return end

-- Гарантированно подгружаем mysqloo (если другой аддон ещё не сделал это)
if not mysqloo then
    local ok, err = pcall(require, "mysqloo")
    if not ok then
        ErrorNoHalt("[ULX Sync] require('mysqloo') упал: " .. tostring(err) .. "\n")
    end
end

local CFG = {
    hostname      = "УКАЖИТЕ_IP_БД",   -- кластерная БД money (консолидация всех синков)
    username      = "УКАЖИТЕ_ЛОГИН",
    password      = "УКАЖИТЕ_ПАРОЛЬ",
    database      = "money",
    port          = 3306,
    poll_interval = 30,
    push_debounce = 0.5,
    reconnect     = 30,
}

local PREFIX  = "[ULX Sync] "
local DB      = nil
local _applying = false       -- защита от петли при pull → addUser/removeUser → push
local _lastPullTs = 0         -- UNIX-секунды, последний обработанный updated_at
local _pendingPush   = {}     -- steamid → true: выдача ещё не подтверждена в БД
local _pendingRemove = {}     -- steamid → true: снятие (томбстоун) ещё не подтверждено

-- =====================================================
-- ДЕБАГ
-- =====================================================
-- Включается convar: ulx_sync_debug 1
CreateConVar("ulx_sync_debug", "0", FCVAR_ARCHIVE, "Подробный лог синхронизации админок ULX↔MySQL (0/1)")
CreateConVar("ulx_sync_tombstone_days", "14", FCVAR_ARCHIVE, "Через сколько дней вычищать томбстоуны снятых админок")

local _stats = { push = 0, pull = 0, applied = 0, removed = 0, skipped = 0, errors = 0, lastErr = "" }

local function dbg(...)
    if GetConVar("ulx_sync_debug"):GetInt() == 0 then return end
    local parts = {...}
    for i, v in ipairs(parts) do parts[i] = tostring(v) end
    print(PREFIX .. "[DEBUG] " .. table.concat(parts, " "))
end

-- Форс-лог: всегда в консоль, независимо от convar
local function log(...)
    local parts = {...}
    for i, v in ipairs(parts) do parts[i] = tostring(v) end
    print(PREFIX .. table.concat(parts, " "))
end

-- =====================================================
-- Утилиты
-- =====================================================

local function isConn()
    return DB and DB:status() == mysqloo.DATABASE_CONNECTED
end

local function esc(s)
    return DB:escape(tostring(s or ""))
end

local function logErr(label, err)
    _stats.errors = _stats.errors + 1
    _stats.lastErr = label .. ": " .. tostring(err)
    ErrorNoHalt(PREFIX .. label .. ": " .. tostring(err) .. "\n")
end

local function isTransientErr(err)
    local s = tostring(err)
    return s:find("Server has gone away")
        or s:find("Can't connect")
        or s:find("Lost connection")
        or s:find("MySQL server has gone away")
end

-- Нормализует id из хуков ULib (может быть SteamID, UniqueID или IP) к SteamID.
local function resolveSteamID(id)
    local s = tostring(id or "")
    if string.match(s, "^STEAM_%d:%d:%d+$") then
        return s
    end
    if ULib and ULib.getPlyByID then
        local ply = ULib.getPlyByID(s)
        if IsValid(ply) and ply.SteamID then
            return ply:SteamID()
        end
    end
    return nil
end

-- =====================================================
-- ОТКЛЮЧЕНИЕ Nova Defender group-protection
-- =====================================================
-- ULX — единственный авторитет. Nova group-protection раньше был вторым
-- авторитетом: каждые 5 сек возвращал группу из своего protected-листа
-- (ulx adduserid) и при удалении из листа делал ulx removeuserid. Из-за
-- этого снятие админки откатывалось / зацикливалось. Отключаем его настройку
-- (она живёт в БД Nova и разъедется на все серверы через её собственный синк).
local function disableNovaGroupProtection()
    if not (Nova and Nova.getSetting and Nova.setSetting) then return false end
    local enabled = Nova.getSetting("security_privileges_group_protection_enabled", nil)
    if enabled == nil then return false end          -- конфиг ещё не загружен
    if enabled then
        Nova.setSetting("security_privileges_group_protection_enabled", false)
        log("Nova group-protection ОТКЛЮЧЁН (ULX — единственный авторитет админок)")
    end
    return true
end

hook.Add("nova_mysql_config_loaded", "ULXSync_DisableNovaGroupProtect", function()
    timer.Simple(0, disableNovaGroupProtection)
end)
timer.Simple(20, disableNovaGroupProtection)   -- fallback, если хук уже отработал

-- ПОСТОЯННОЕ ПРИНУЖДЕНИЕ (важно!):
-- Nova-конфиг синхронизируется между серверами кластера через СВОЮ БД, поэтому
-- group-protection мог включиться заново (на другом сервере / из панели Nova).
-- Если он ВКЛ — Nova каждые 5с снимает ULX-выданные ранги у игроков, которых нет
-- в её whitelist (privilege_escalation → ulx removeuserid → томбстоун в MySQL →
-- ранг слетает на реконнекте). Это и был баг с «выдал суперадмина в консоли,
-- перезашёл — слетело». Держим protection ВЫКЛ жёстко:
--   1) переспрашиваем каждые 60с и выключаем, если включился;
--   2) ловим событие смены настройки и мгновенно выключаем обратно.
local function enforceNovaOff()
    if not (Nova and Nova.getSetting and Nova.setSetting) then return end
    if Nova.getSetting("security_privileges_group_protection_enabled", false) then
        Nova.setSetting("security_privileges_group_protection_enabled", false)
        log("Nova group-protection был ВКЛ — принудительно ВЫКЛючен (ULX = единственный авторитет)")
    end
end
-- Опрос Nova — каждые 5 сек (как и её собственный poll group-protection), чтобы
-- окно, в котором она могла бы снять ранг, было минимальным на серверах, где
-- код-фикс в nova privileges.lua ещё не раскатан.
timer.Create("ULXSync_EnforceNovaOff", 5, 0, enforceNovaOff)

hook.Add("nova_config_setting_changed", "ULXSync_ReDisableNovaGroupProtect", function(key, value)
    if key ~= "security_privileges_group_protection_enabled" then return end
    if value then
        log("Nova group-protection кто-то ВКЛючил — выключаю обратно")
        timer.Simple(0, enforceNovaOff)
    end
end)

-- =====================================================
-- MySQL → ULib
-- =====================================================

-- Применяет строку из MySQL к локальному ULib.
--   usergroup == 'user'  → ТОМБСТОУН: снять ранг локально (если он есть)
--   usergroup == <группа> → выдать/обновить ранг
local function applyRow(row)
    if not row or not row.steamid then
        log("applyRow: ПУСТАЯ СТРОКА / нет steamid")
        return
    end
    local sid   = tostring(row.steamid):upper()
    local group = row.usergroup or "user"

    -- Если по этому игроку у нас есть НЕПОДТВЕРЖДЁННОЕ локальное изменение —
    -- строка из БД может быть устаревшей. Не даём ей перезатереть наше свежее.
    if _pendingPush[sid] or _pendingRemove[sid] then
        dbg("applyRow: ПРОПУСК — ожидается локальный push/remove для", sid)
        _stats.skipped = _stats.skipped + 1
        return
    end

    -- ── ТОМБСТОУН: снятие ранга ──────────────────────────────────────────
    if group == "user" then
        local existing = ULib.ucl.users and ULib.ucl.users[sid]
        if existing and existing.group and existing.group ~= "user" then
            log("applyRow: ТОМБСТОУН → снимаю ранг локально →", sid, "(был", existing.group .. ")")
            _applying = true
            -- from_CAMI=true: НЕ рассылаем CAMI-сигнал (как и addUser ниже),
            -- иначе другие админ-моды (Nova и т.п.) увидят снятие и продублируют
            -- его своим путём — лишний шум «Console -> Снятие ранга» в логах.
            local ok, err = pcall(ULib.ucl.removeUser, sid, true)
            _applying = false
            if not ok then
                logErr("applyRow removeUser " .. sid, err)
            else
                _stats.removed = _stats.removed + 1
            end
        else
            dbg("applyRow: томбстоун, но локально и так не админ →", sid)
            _stats.skipped = _stats.skipped + 1
        end
        return
    end

    -- ── ВЫДАЧА / ОБНОВЛЕНИЕ ранга ─────────────────────────────────────────
    if not (ULib.ucl.groups and ULib.ucl.groups[group]) then
        log("applyRow: ПРОПУСК — группа '" .. group .. "' не существует в ULib →", sid)
        _stats.skipped = _stats.skipped + 1
        return
    end

    local existing = ULib.ucl.users and ULib.ucl.users[sid]
    local allow = util.JSONToTable(row.allow or "[]") or {}
    local deny  = util.JSONToTable(row.deny  or "[]") or {}

    if existing and existing.group == group
        and table.concat(existing.allow or {}, ",") == table.concat(allow, ",")
        and table.concat(existing.deny  or {}, ",") == table.concat(deny,  ",")
    then
        dbg("applyRow: данные идентичны, пропуск →", sid)
        _stats.skipped = _stats.skipped + 1
        return
    end

    log("applyRow: ДОБАВЛЯЮ в ULib →", sid, "group=" .. group)
    _applying = true
    -- ВАЖНО: передаём true (from_CAMI) чтобы НЕ вызывать CAMI-сигнал.
    local ok, err = pcall(ULib.ucl.addUser, sid, allow, deny, group, true)
    _applying = false
    if not ok then
        logErr("applyRow addUser " .. sid, err)
    else
        log("applyRow: addUser OK →", sid, "group=" .. group)
        _stats.applied = _stats.applied + 1
    end
end

local function pullPlayer(steamid)
    if not isConn() then
        log("pullPlayer: нет соединения с БД, пропуск →", steamid)
        return
    end
    local sidU = tostring(steamid):upper()
    log("pullPlayer: запрос MySQL для →", steamid)
    local q = DB:query("SELECT * FROM ulib_users WHERE steamid='" .. esc(steamid) .. "' LIMIT 1")
    function q:onSuccess(data)
        local row   = data and data[1]
        local group = row and (row.usergroup or "user") or nil
        -- Локальная запись игрока в этом ULib (статик из users.txt или ранее
        -- синхронизированная). Считается «свежим писателем», если в ней есть ранг.
        local localInfo    = ULib.ucl.users and ULib.ucl.users[sidU]
        local localIsAdmin = localInfo and localInfo.group and localInfo.group ~= "user"

        if row and group ~= "user" then
            -- В MySQL есть реальный ранг → применяем как есть (выдача/обновление).
            log("pullPlayer: найдено →", steamid, "group=" .. tostring(group))
            applyRow(row)

        elseif localIsAdmin then
            -- Сюда попадаем, если:
            --   • строки в MySQL вообще нет (никогда не синхронизировался,
            --     напр. статик-админ из users.txt), ИЛИ
            --   • в MySQL ТОМБСТОУН (usergroup='user'), но локально игрок ВСЁ ЕЩЁ
            --     админ — значит ранг прописан локально и НЕ снимался на этом
            --     сервере. Реальные снятия чистят локальный UCL ещё ДО реконнекта
            --     (живой дельтой у онлайн-серверов, bootstrap-пуллом при старте),
            --     поэтому «локально админ + томбстоун» = устаревший томбстоун.
            -- По LWW локальная запись считается свежее: НЕ снимаем ранг «просто
            -- так» при входе, а перезаписываем строку актуальной группой (push).
            local why = row and ("томбстоун в MySQL, но локально '" .. localInfo.group .. "'")
                            or  ("строки в MySQL нет, локальный ранг '" .. localInfo.group .. "'")
            log("pullPlayer: " .. why .. " → НЕ снимаю, push →", steamid)
            _pendingRemove[sidU] = nil
            _pendingPush[sidU] = true
            pushUser(steamid)

        elseif row then
            -- Томбстоун в MySQL и локально не админ → нечего снимать, всё ок.
            dbg("pullPlayer: томбстоун в MySQL и локально не админ →", steamid)
        else
            dbg("pullPlayer: строки в MySQL нет и локально не админ →", steamid)
        end
    end
    function q:onError(err) logErr("pullPlayer " .. steamid, err) end
    q:start()
end

local function pullDelta()
    if not isConn() then
        dbg("pullDelta: нет соединения, пропуск")
        return
    end
    -- Сравниваем по UNIX timestamp серверной БД — нет зависимости от TZ.
    -- Дельта несёт И выдачи, И снятия (томбстоуны) — этого достаточно,
    -- отдельная сверка «локальные vs MySQL» больше не нужна.
    local sql = _lastPullTs > 0
        and ("SELECT *, UNIX_TIMESTAMP(updated_at) AS _ts FROM ulib_users WHERE updated_at > FROM_UNIXTIME(" .. _lastPullTs .. ")")
        or  "SELECT *, UNIX_TIMESTAMP(updated_at) AS _ts FROM ulib_users"

    _stats.pull = _stats.pull + 1
    dbg("pullDelta: lastPullTs=" .. _lastPullTs)

    local q = DB:query(sql)
    function q:onSuccess(data)
        if not data then
            dbg("pullDelta: data=nil")
            return
        end
        dbg("pullDelta: получено " .. #data .. " строк из MySQL")
        local maxTs = _lastPullTs
        for _, row in ipairs(data) do
            applyRow(row)
            local ts = tonumber(row._ts) or 0
            if ts > maxTs then maxTs = ts end
        end
        if maxTs > _lastPullTs then _lastPullTs = maxTs end
        if #data > 0 then
            print(PREFIX .. "Pull: применено " .. #data .. " записей (lastPullTs=" .. _lastPullTs .. ")")
        end
    end
    function q:onError(err) logErr("pullDelta", err) end
    q:start()
end

-- =====================================================
-- ULib → MySQL
-- =====================================================

-- Выдача / обновление ранга
function pushUser(steamid)
    if not isConn() then
        log("pushUser: нет соединения, пропуск →", steamid)
        return
    end
    local sidU = tostring(steamid):upper()
    local info = ULib.ucl.users and (ULib.ucl.users[steamid] or ULib.ucl.users[sidU])
    if not info then
        log("pushUser: нет локальной записи ULib для →", steamid)
        return
    end
    if not info.group or info.group == "user" then
        log("pushUser: group=user/nil → это снятие, пушем томбстоуном, не здесь →", steamid)
        return
    end

    local sid   = esc(steamid)
    local name  = esc(info.name or "")
    local group = esc(info.group)
    local allow = esc(util.TableToJSON(info.allow or {}))
    local deny  = esc(util.TableToJSON(info.deny  or {}))

    _stats.push = _stats.push + 1
    log("pushUser: ПИШУ в MySQL →", steamid, "group=" .. info.group)

    local q = DB:query(
        "INSERT INTO ulib_users (steamid,name,usergroup,allow,deny) VALUES('"
        .. sid .. "','" .. name .. "','" .. group .. "','" .. allow .. "','" .. deny ..
        "') ON DUPLICATE KEY UPDATE name='" .. name .. "',usergroup='" .. group ..
        "',allow='" .. allow .. "',deny='" .. deny .. "',updated_at=NOW()"
    )
    function q:onSuccess()
        _pendingPush[steamid] = nil
        _pendingPush[sidU] = nil
        log("pushUser: OK →", steamid)
    end
    function q:onError(err)
        -- На транзиентные сетевые ошибки НЕ сбрасываем pending — retry-таймер повторит.
        if not isTransientErr(err) then
            _pendingPush[steamid] = nil
            _pendingPush[sidU] = nil
        end
        logErr("pushUser " .. steamid, err)
    end
    q:start()
end

-- Снятие ранга = ТОМБСТОУН (usergroup='user', свежий updated_at).
-- Строку НЕ удаляем, чтобы снятие доехало дельтой до остальных серверов
-- и чтобы реконнект не воскресил ранг (нет двусмысленного «отсутствия строки»).
function pushTombstone(steamid)
    if not isConn() then
        log("pushTombstone: нет соединения, пропуск →", steamid)
        return
    end
    local sidU = tostring(steamid):upper()
    local sid  = esc(steamid)

    -- Имя для лога/строки: из ULib (если ещё есть) или из онлайн-игрока.
    local name = ""
    local info = ULib.ucl.users and (ULib.ucl.users[steamid] or ULib.ucl.users[sidU])
    if info and info.name then name = info.name end
    if name == "" and ULib and ULib.getPlyByID then
        local p = ULib.getPlyByID(steamid)
        if IsValid(p) then name = p:Nick() end
    end
    name = esc(name)

    log("pushTombstone: СНИМАЮ в MySQL (томбстоун) →", steamid)
    local q = DB:query(
        "INSERT INTO ulib_users (steamid,name,usergroup,allow,deny) VALUES('"
        .. sid .. "','" .. name .. "','user','[]','[]')"
        .. " ON DUPLICATE KEY UPDATE name='" .. name .. "',usergroup='user',allow='[]',deny='[]',updated_at=NOW()"
    )
    function q:onSuccess()
        _pendingRemove[steamid] = nil
        _pendingRemove[sidU] = nil
        log("pushTombstone: OK →", steamid)
    end
    function q:onError(err)
        if not isTransientErr(err) then
            _pendingRemove[steamid] = nil
            _pendingRemove[sidU] = nil
        end
        logErr("pushTombstone " .. steamid, err)
    end
    q:start()
end

-- Ретраер зависших операций: раз в 15 сек повторяет неподтверждённые push/remove
-- (например, если MySQL ушла в "gone away" во время выдачи/снятия).
local function flushPending()
    if not isConn() then return end
    local nP, nR = 0, 0
    for _ in pairs(_pendingPush)   do nP = nP + 1 end
    for _ in pairs(_pendingRemove) do nR = nR + 1 end
    if nP == 0 and nR == 0 then return end
    log("flushPending: повторяю push=" .. nP .. " remove=" .. nR)
    for sid in pairs(_pendingPush)   do pushUser(sid) end
    for sid in pairs(_pendingRemove) do pushTombstone(sid) end
end
timer.Create("ULXSync_FlushPending", 15, 0, flushPending)

-- Чистка старых томбстоунов, чтобы таблица не пухла.
local function purgeTombstones()
    if not isConn() then return end
    local days = math.max(1, tonumber(GetConVar("ulx_sync_tombstone_days"):GetString()) or 14)
    local q = DB:query("DELETE FROM ulib_users WHERE usergroup='user' AND updated_at < (NOW() - INTERVAL " .. days .. " DAY)")
    function q:onSuccess()
        local aff = (q.affectedRows and q:affectedRows()) or 0
        if aff > 0 then log("purgeTombstones: удалено старых томбстоунов →", aff) end
    end
    function q:onError(err) logErr("purgeTombstones", err) end
    q:start()
end

-- =====================================================
-- Bootstrap: первый старт
-- =====================================================

local function bootstrap()
    if not isConn() then return end
    local q = DB:query("SELECT COUNT(*) AS n, UNIX_TIMESTAMP(NOW()) AS now_ts FROM ulib_users")
    function q:onSuccess(data)
        local n = data and data[1] and tonumber(data[1].n) or 0
        local now = data and data[1] and tonumber(data[1].now_ts) or os.time()
        _lastPullTs = now

        if n == 0 then
            local users = (ULib.ucl and ULib.ucl.users) or {}
            local pushed = 0
            for steamid, info in pairs(users) do
                if info.group and info.group ~= "user" then
                    pushUser(steamid)
                    pushed = pushed + 1
                end
            end
            print(PREFIX .. "Bootstrap: MySQL пустая → push " .. pushed .. " локальных админок")
        else
            print(PREFIX .. "Bootstrap: в MySQL " .. n .. " записей → pull в ULX")
            _lastPullTs = 0
            pullDelta()
        end

        timer.Create("ULXUsers_Poll", CFG.poll_interval, 0, pullDelta)
        purgeTombstones()
        timer.Create("ULXSync_PurgeTombstones", 6 * 60 * 60, 0, purgeTombstones)  -- раз в 6 часов
    end
    function q:onError(err)
        logErr("bootstrap COUNT", err)
        timer.Create("ULXUsers_Poll", CFG.poll_interval, 0, pullDelta)
    end
    q:start()
end

local function migrateTable(callback)
    local q1 = DB:query("ALTER TABLE ulib_users ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP")
    function q1:onSuccess() print(PREFIX .. "MIGRATION: добавлена колонка updated_at") end
    function q1:onError(err)
        if string.find(tostring(err), "Duplicate column name") then
            print(PREFIX .. "MIGRATION: updated_at уже есть, OK")
        else
            logErr("ALTER ADD updated_at", err)
        end
    end
    q1:start()

    local q2 = DB:query("ALTER TABLE ulib_users ADD INDEX idx_updated (updated_at)")
    function q2:onSuccess() print(PREFIX .. "MIGRATION: добавлен индекс idx_updated") end
    function q2:onError(err)
        if string.find(tostring(err), "Duplicate") then
            print(PREFIX .. "MIGRATION: индекс idx_updated уже есть, OK")
        else
            logErr("ALTER ADD INDEX idx_updated", err)
        end
    end
    q2:start()

    timer.Simple(1.5, callback)
end

local function ensureTable()
    local q = DB:query([[
        CREATE TABLE IF NOT EXISTS ulib_users (
            steamid    VARCHAR(32)  NOT NULL,
            name       VARCHAR(64),
            usergroup  VARCHAR(64)  NOT NULL DEFAULT 'user',
            allow      TEXT,
            deny       TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (steamid),
            INDEX idx_updated (updated_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    function q:onSuccess()
        print(PREFIX .. "Таблица ulib_users готова, проверяю миграции...")
        migrateTable(bootstrap)
    end
    function q:onError(err) logErr("CREATE TABLE", err) end
    q:start()
end

-- =====================================================
-- Подключение
-- =====================================================

local function connect()
    print(PREFIX .. "connect() вызван")
    if not mysqloo then
        ErrorNoHalt(PREFIX .. "mysqloo не установлен! Положи gmsv_mysqloo_*.dll в garrysmod/lua/bin/\n")
        return
    end

    local ok, dbOrErr = pcall(mysqloo.connect, CFG.hostname, CFG.username, CFG.password, CFG.database, CFG.port)
    if not ok then
        logErr("mysqloo.connect", dbOrErr)
        timer.Simple(CFG.reconnect, connect)
        return
    end
    DB = dbOrErr

    function DB:onConnected()
        print(PREFIX .. "Подключено к " .. CFG.database)
        ensureTable()
        timer.Simple(2, flushPending)
    end

    function DB:onConnectionFailed(err)
        logErr("Подключение", err)
        timer.Simple(CFG.reconnect, connect)
    end

    DB:connect()
end

-- =====================================================
-- Хуки ULib
-- =====================================================

hook.Add("PlayerAuthed", "ULXUsers_PlayerAuthed", function(ply)
    log("HOOK PlayerAuthed →", ply:SteamID(), ply:Name(), "group=" .. ply:GetUserGroup())
    timer.Simple(1, function()
        if IsValid(ply) then
            log("PlayerAuthed: запускаю pullPlayer для →", ply:SteamID())
            pullPlayer(ply:SteamID())
        end
    end)
end)

hook.Add("ULibUserGroupChange", "ULXUsers_GroupChange", function(id, allows, denies, group)
    log("HOOK ULibUserGroupChange →", id, "group=" .. tostring(group), "applying=" .. tostring(_applying))
    if _applying then
        dbg("  └ пропуск (applying=true)")
        return
    end

    local sid = resolveSteamID(id) or tostring(id):upper()
    if sid ~= tostring(id) then log("  └ резолв", id, "→", sid) end

    if group and group ~= "user" then
        log("  └ планирую pushUser →", sid, "group=" .. group)
        _pendingRemove[sid] = nil
        _pendingPush[sid] = true
        timer.Create("ULXUsers_Push_" .. sid, CFG.push_debounce, 1, function()
            pushUser(sid)
        end)
    elseif group == "user" then
        log("  └ даунгрейд до user → томбстоун →", sid)
        _pendingPush[sid] = nil
        _pendingRemove[sid] = true
        timer.Create("ULXUsers_Push_" .. sid, CFG.push_debounce, 1, function()
            pushTombstone(sid)
        end)
    else
        dbg("  └ group=nil, игнорируем (ULib-очистка при дисконнекте)")
    end
end)

hook.Add("ULibUserRemoved", "ULXUsers_UserRemoved", function(id, userInfo)
    log("HOOK ULibUserRemoved →", id, "applying=" .. tostring(_applying))
    if _applying then
        dbg("  └ пропуск (applying=true)")
        return
    end

    -- ULib может передать SteamID, UniqueID или IP. В MySQL храним по SteamID.
    local sid = resolveSteamID(id)
    if sid then
        if sid ~= tostring(id) then log("  └ резолв", id, "→", sid) end
        _pendingPush[sid] = nil
        _pendingRemove[sid] = true
        pushTombstone(sid)
    else
        -- Игрок оффлайн и id не SteamID — пробуем томбстоун как есть (legacy).
        log("  └ не удалось резолвить в SteamID, томбстоун по исходному id →", id)
        pushTombstone(id)
    end
end)

-- Подключение к MySQL с тремя точками входа (что первое сработает).
local _connect_done = false
local function safeConnect()
    if _connect_done then return end
    _connect_done = true
    log("safeConnect: запускаю connect()")
    connect()
end

hook.Add("Initialize", "ULXUsers_Init", function()
    timer.Simple(5, safeConnect)
end)
hook.Add("InitPostEntity", "ULXUsers_InitPostEntity", function()
    timer.Simple(3, safeConnect)
end)
timer.Simple(10, function()
    if not _connect_done then
        log("FALLBACK timer(10): Initialize/InitPostEntity не отработали — connect напрямую")
    end
    safeConnect()
end)

-- =====================================================
-- Команды для отладки
-- =====================================================

local function tellAll(ply, lines)
    for _, msg in ipairs(lines) do
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end
end

concommand.Add("ulx_sync_status", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local s
    if not mysqloo then
        s = "❌ mysqloo НЕ ЗАГРУЖЕН (нет gmsv_mysqloo_*.dll в lua/bin)"
    elseif not DB then
        s = "не инициализирована (connect() ещё не вызван или упал)"
    else
        local st = DB:status()
        s = st == mysqloo.DATABASE_CONNECTED  and "подключена"
         or st == mysqloo.DATABASE_CONNECTING and "подключается..."
         or "отключена (status=" .. tostring(st) .. ")"
    end
    local local_count = 0
    for _ in pairs(ULib.ucl.users or {}) do local_count = local_count + 1 end
    local novaState = "—"
    if Nova and Nova.getSetting then
        local e = Nova.getSetting("security_privileges_group_protection_enabled", nil)
        novaState = (e == nil) and "конфиг не загружен" or (e and "ВКЛ (⚠ должен быть ВЫКЛ!)" or "ВЫКЛ ✓")
    end
    tellAll(ply, {
        PREFIX .. "=== Статус синхронизации админок ===",
        PREFIX .. "БД: " .. s .. " (" .. CFG.database .. " @ " .. CFG.hostname .. ")",
        PREFIX .. "Локальных админок: " .. local_count,
        PREFIX .. "Last pull ts: " .. tostring(_lastPullTs),
        PREFIX .. "Nova group-protection: " .. novaState,
        PREFIX .. "Дебаг: " .. (GetConVar("ulx_sync_debug"):GetInt() == 1 and "ВКЛ" or "ВЫКЛ"),
        PREFIX .. "Stats: push=" .. _stats.push .. " pull=" .. _stats.pull ..
                 " applied=" .. _stats.applied .. " removed=" .. _stats.removed ..
                 " skipped=" .. _stats.skipped .. " errors=" .. _stats.errors,
        PREFIX .. "Last err: " .. (_stats.lastErr == "" and "—" or _stats.lastErr),
    })
end)

concommand.Add("ulx_sync_pull", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    pullDelta()
    tellAll(ply, { PREFIX .. "Ручной pull запущен" })
end)

concommand.Add("ulx_sync_pull_all", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    _lastPullTs = 0
    pullDelta()
    tellAll(ply, { PREFIX .. "Сброс курсора → полный pull запущен" })
end)

concommand.Add("ulx_sync_push_all", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    if not isConn() then
        tellAll(ply, { PREFIX .. "Нет соединения с БД" })
        return
    end
    local n = 0
    for sid, info in pairs(ULib.ucl.users or {}) do
        if info.group and info.group ~= "user" then
            pushUser(sid)
            n = n + 1
        end
    end
    tellAll(ply, { PREFIX .. "Push запущен для " .. n .. " локальных админок" })
end)

concommand.Add("ulx_sync_dump", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local lines = { PREFIX .. "=== Локальные админы ULib ===" }
    local n = 0
    for sid, info in pairs(ULib.ucl.users or {}) do
        n = n + 1
        table.insert(lines, PREFIX .. "  " .. sid .. " | " ..
                     (info.group or "?") .. " | " .. (info.name or ""))
    end
    if n == 0 then table.insert(lines, PREFIX .. "  (пусто)") end
    tellAll(ply, lines)

    if not isConn() then
        tellAll(ply, { PREFIX .. "БД не подключена — пропуск дампа MySQL" })
        return
    end
    local q = DB:query("SELECT steamid, name, usergroup, UNIX_TIMESTAMP(updated_at) AS ts FROM ulib_users ORDER BY usergroup")
    function q:onSuccess(data)
        local out = { PREFIX .. "=== Записи MySQL ulib_users (tomb=снятые) ===" }
        if not data or #data == 0 then
            table.insert(out, PREFIX .. "  (пусто)")
        else
            for _, r in ipairs(data) do
                local mark = (tostring(r.usergroup) == "user") and " [tomb]" or ""
                table.insert(out, PREFIX .. "  " .. tostring(r.steamid) .. " | " ..
                             tostring(r.usergroup) .. mark .. " | " .. tostring(r.name or "") ..
                             " | ts=" .. tostring(r.ts))
            end
        end
        tellAll(ply, out)
    end
    function q:onError(err) logErr("dump query", err) end
    q:start()
end)

concommand.Add("ulx_sync_reset_stats", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    _stats = { push = 0, pull = 0, applied = 0, removed = 0, skipped = 0, errors = 0, lastErr = "" }
    tellAll(ply, { PREFIX .. "Статистика сброшена" })
end)

-- Немедленно вырубить Nova group-protection (чинит «ранг слетает» вживую,
-- без рестарта). Это та подсистема, что снимала ULX-выданные ранги.
concommand.Add("ulx_sync_nova_off", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    if not (Nova and Nova.getSetting and Nova.setSetting) then
        tellAll(ply, { PREFIX .. "Nova API недоступен (не загружен?)" })
        return
    end
    local was = Nova.getSetting("security_privileges_group_protection_enabled", nil)
    Nova.setSetting("security_privileges_group_protection_enabled", false)
    tellAll(ply, {
        PREFIX .. "Nova group-protection: было=" .. tostring(was) .. " → ВЫКЛ.",
        PREFIX .. "Теперь выдавай ранг заново — слетать не должен.",
    })
    log("Nova group-protection вырублен вручную через ulx_sync_nova_off")
end)

print(PREFIX .. "Модуль админок загружен (LWW+томбстоуны; дебаг: ulx_sync_debug 1)")
