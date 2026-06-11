-- =====================================================
-- ULX ↔ MySQL: синхронизация банов (v3 — чистый rewrite)
-- =====================================================
-- БД: money @ УКАЖИТЕ_IP_БД (консолидация кластера), таблица ulib_bans
--   steamid VARCHAR(20)  — SteamID64 (PRIMARY KEY)
--   time    BIGINT       — UNIX-метка начала бана
--   unban   BIGINT       — UNIX-метка снятия (0 = ПЕРМАНЕНТНЫЙ)
--   reason / name / admin / modified_admin / modified_time
--   updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
--
-- =====================================================
-- ПОЧЕМУ v3 (что чинит этот rewrite)
-- =====================================================
-- v2 синхронизировала ДЕЛЬТУ по `updated_at > курсор`. Это теряло строки
-- НАВСЕГДА по двум причинам:
--   1. Секундная гранулярность TIMESTAMP: бан, закоммиченный в ту же секунду
--      что и курсор, но после снапшота SELECT, отсекался строгим `>`.
--   2. Порядок коммита ≠ порядок timestamp: при 5 параллельных писателях
--      строка с меньшим updated_at могла закоммититься позже — курсор уже
--      ушёл вперёд и эту строку никто не подтягивал.
-- А `pullCheckMissing` это не лечил — он только УДАЛЯЛ локальные баны,
-- никогда не ДОБАВЛЯЛ пропущенные. Итог: бан с сервера A мог навсегда не
-- доехать до сервера B.
--
-- РЕШЕНИЕ v3 — self-healing reconcile вместо дельты:
--   • Раз в poll секунд — дешёвый probe подписи таблицы (COUNT + MAX(updated_at)
--     + контент-хэш BIT_XOR(CRC32(...))).
--   • Подпись изменилась → ОДИН полный SELECT * и идемпотентная сверка всего
--     состояния: применить все активные строки, снять локальные которых нет.
--   • Ни одна строка не теряется. Удаления и перма распространяются. Система
--     сама себя лечит при любом пропуске/сбое.
--
-- ПРИНУЖДЕНИЕ — 3 слоя (не зависит от одной цепочки хуков):
--   • CheckPassword (HOOK_HIGH) — мгновенный отказ из кэша, раньше Nova/FAdmin.
--   • PlayerAuthed + PlayerInitialSpawn — авторитетный прямой SELECT и кик,
--     НЕЗАВИСИМО от исхода цепочки CheckPassword (закрывает обрыв цепочки и
--     окно до ближайшего reconcile).
--   • Пост-reconcile проход по онлайну — кикает уже-онлайн новозабаненных.
--
-- ИНВАРИАНТЫ:
--   • central MySQL = единственный источник истины (локальный SQLite ULib
--     заглушён — refreshBans/ULibBanCheck/ULibBansDB сняты).
--   • Мы — единственный writer в ulib_bans на стороне кластера.
--   • unban=0 (перма) понижается только явным `ulx unban` (→ DELETE строки).
--     При гонке push'ей перма защищена атомарным CASE на уровне SQL.
-- =====================================================

if not SERVER then return end

if not mysqloo then
    local ok, err = pcall(require, "mysqloo")
    if not ok then
        ErrorNoHalt("[Ban Sync] require('mysqloo') упал: " .. tostring(err) .. "\n")
    end
end

-- ──────────────────────────────────────────────────────
-- Конфиг
-- ──────────────────────────────────────────────────────
local CFG = {
    hostname      = "УКАЖИТЕ_IP_БД",   -- кластерная БД money (консолидация всех синков)
    username      = "УКАЖИТЕ_ЛОГИН",
    password      = "УКАЖИТЕ_ПАРОЛЬ",
    database      = "money",
    port          = 3306,
    poll_interval = 7,    -- probe подписи каждые N сек (reconcile только при изменении)
    reconnect     = 30,
}

local PREFIX = "[Ban Sync] "

local DB           = nil
local _lastSig     = nil     -- подпись последнего reconcile: "n|maxts|xr"
local _cache       = {}      -- sid64 → { unban, reason, admin, name, time } для CheckPassword
local _pending     = { push = {}, del = {} }  -- очередь записей пока БД недоступна / push в полёте
local _recentWrite = {}      -- sid32 → { t, op } : защита свежей локальной записи от гонки reconcile
local WRITE_GRACE  = 15      -- сек: окно в которое central-снапшот мог не увидеть нашу запись
local _bootstrapped = false

local _stats = { push = 0, reconciles = 0, applied = 0, removed = 0,
                 errors = 0, lastErr = "", checkpw_kicks = 0, kicks = 0 }

-- ──────────────────────────────────────────────────────
-- Лог
-- ──────────────────────────────────────────────────────
if not ConVarExists("ulx_sync_debug") then
    CreateConVar("ulx_sync_debug", "0", FCVAR_ARCHIVE, "Подробный лог синхронизации (0/1)")
end

local function dbg(...)
    if GetConVar("ulx_sync_debug"):GetInt() == 0 then return end
    local parts = {...}
    for i, v in ipairs(parts) do parts[i] = tostring(v) end
    print(PREFIX .. "[DEBUG] " .. table.concat(parts, " "))
end

local function logInfo(...)
    local parts = {...}
    for i, v in ipairs(parts) do parts[i] = tostring(v) end
    print(PREFIX .. table.concat(parts, " "))
end

local function logErr(label, err)
    _stats.errors = _stats.errors + 1
    _stats.lastErr = label .. ": " .. tostring(err)
    ErrorNoHalt(PREFIX .. label .. ": " .. tostring(err) .. "\n")
end

-- ──────────────────────────────────────────────────────
-- SteamID: валидация + конверсия (только на границах БД)
-- ──────────────────────────────────────────────────────
local function isValidSid32(s)
    if type(s) ~= "string" then return false end
    if not ULib or not ULib.isValidSteamID then
        return s:match("^STEAM_[01]:[01]:%d+$") ~= nil
    end
    return ULib.isValidSteamID(s)
end

local function isValidSid64(s)
    if type(s) ~= "string" then return false end
    if #s ~= 17 then return false end
    return s:match("^7656119%d+$") ~= nil
end

local function to64(sid32)
    if not isValidSid32(sid32) then return nil end
    local ok, sid64 = pcall(util.SteamIDTo64, sid32)
    if not ok or not isValidSid64(sid64) then return nil end
    return sid64
end

local function to32(sid64)
    if not isValidSid64(tostring(sid64)) then return nil end
    local ok, sid32 = pcall(util.SteamIDFrom64, tostring(sid64))
    if not ok or not isValidSid32(sid32) then return nil end
    return sid32
end

local function isPerma(banDataOrUnban)
    local unban = type(banDataOrUnban) == "table"
        and tonumber(banDataOrUnban.unban) or tonumber(banDataOrUnban)
    return unban == nil or unban == 0
end

-- ──────────────────────────────────────────────────────
-- Утилиты MySQL
-- ──────────────────────────────────────────────────────
local function isConn() return DB and DB:status() == mysqloo.DATABASE_CONNECTED end
local function esc(s)   return DB and DB:escape(tostring(s or "")) or "" end

-- ──────────────────────────────────────────────────────
-- Подавление чужих систем банов — ОДИН РАЗ + по событию (без поллинга)
-- ──────────────────────────────────────────────────────
-- Форк ULib (ulib-master) имеет собственную MySQL-интеграцию банов:
--   • хук Initialize "ULibLoadBans"      → refreshBans (ULib.bans = {})
--   • хук DatabaseConnected "ULibBansDB"  → mySQL_Active=true + refreshBans
--   • хук CheckPassword "ULibBanCheck"    → проверка через чужую mysql-обёртку
--   • хук NetworkIDValidated "KickIdiotFromServer"
-- Всё это перезаписывало бы наше зеркало и проверяло чужую БД. Снимаем хуки
-- (hook.Add хранит ССЫЛКУ на оригинал refreshBans, поэтому критично убрать
-- именно хук, а не только подменить функцию) и делаем refreshBans no-op.
local function suppressForeign()
    if ULib then
        if ULib.mySQL_Active then ULib.mySQL_Active = false end
        ULib.bans = ULib.bans or {}
    end
    hook.Remove("Initialize",         "ULibLoadBans")
    hook.Remove("DatabaseConnected",  "ULibBansDB")
    hook.Remove("CheckPassword",      "ULibBanCheck")
    hook.Remove("NetworkIDValidated", "KickIdiotFromServer")
end

if ULib then
    ULib.bans = ULib.bans or {}
    ULib.refreshBans = function() ULib.bans = ULib.bans or {} end
end

-- Глушим немедленно (ULibLoadBans может уже висеть в очереди на Initialize),
-- затем на DatabaseConnected (reconnect форк-обёртки) и пару раз на Initialize.
suppressForeign()
hook.Add("DatabaseConnected", "BanSync_Suppress", suppressForeign)
hook.Add("Initialize", "BanSync_SuppressInit", function()
    suppressForeign()
    timer.Simple(0, suppressForeign)
    timer.Simple(2, suppressForeign)
end)

-- ──────────────────────────────────────────────────────
-- Очереди (push в полёте / БД недоступна)
-- ──────────────────────────────────────────────────────
-- _pending.push защищает только что поставленный бан от чистки reconcile'ом
-- в момент пока асинхронный INSERT ещё не подтверждён.
local function queuePush(sid32, banData)
    _pending.del[sid32]  = nil
    _pending.push[sid32] = table.Copy(banData or {})
end

local function queueDelete(sid32)
    _pending.push[sid32] = nil
    _pending.del[sid32]  = true
end

-- Грейс свежей записи: central-снапшот reconcile, начатый ДО коммита нашей
-- записи, не должен ни снять только что поставленный бан ("push"), ни вернуть
-- только что снятый ("del"). За WRITE_GRACE сек central гарантированно догоняет.
local function markWrite(sid32, op) _recentWrite[sid32] = { t = os.time(), op = op } end
local function recentWrite(sid32)
    local w = _recentWrite[sid32]
    if not w then return nil end
    if os.time() - w.t > WRITE_GRACE then _recentWrite[sid32] = nil; return nil end
    return w.op
end

-- ──────────────────────────────────────────────────────
-- Forward declarations
-- ──────────────────────────────────────────────────────
local pushBan, deleteBan, flushPending, applyActiveBan, reconcile, probe,
      kickAllBanned, checkBanOnJoin, banMessageFor

-- ──────────────────────────────────────────────────────
-- Writers: ULib → MySQL
-- ──────────────────────────────────────────────────────
pushBan = function(sid32, banData)
    if not isValidSid32(sid32) or type(banData) ~= "table" then
        logErr("pushBan", "невалидные аргументы: " .. tostring(sid32))
        return
    end
    local sid64 = to64(sid32)
    if not sid64 then
        logErr("pushBan", "не сконвертировать в SteamID64: " .. tostring(sid32))
        return
    end

    -- помечаем «в полёте» (reconcile не тронет, пока не подтвердим)
    queuePush(sid32, banData)
    markWrite(sid32, "push")
    if not isConn() then return end  -- останется в очереди, повторит flushPending

    local t       = tonumber(banData.time)  or os.time()
    local u       = tonumber(banData.unban) or 0
    local reason  = esc(banData.reason or "")
    local name    = esc(banData.name   or "")
    local admin   = esc(banData.admin  or "")
    local modAdm  = esc(banData.modified_admin or "")
    local modTime = tonumber(banData.modified_time) or 0
    if t < 0 or t > 2^40 then t = os.time() end
    if u < 0 or u > 2^40 then u = 0 end

    _stats.push = _stats.push + 1
    dbg("pushBan", sid32, "→", sid64, "unban=" .. u, isPerma(u) and "(ПЕРМА)" or "")

    -- АТОМАРНАЯ ЗАЩИТА ПЕРМА (важен порядок колонок: time раньше unban, чтобы
    -- его CASE видел СТАРОЕ значение unban из БД):
    --   time : если в БД перма (unban=0 ещё старое) → не трогаем, иначе новое
    --   unban: в БД перма → 0; новый перма → 0; иначе новое
    local sql = string.format(
        "INSERT INTO ulib_bans (steamid,time,unban,reason,name,admin,modified_admin,modified_time) " ..
        "VALUES('%s',%d,%d,'%s','%s','%s','%s',%d) " ..
        "ON DUPLICATE KEY UPDATE " ..
        "time  = CASE WHEN unban = 0 THEN time ELSE VALUES(time) END, " ..
        "unban = CASE WHEN unban = 0 THEN 0 WHEN VALUES(unban) = 0 THEN 0 ELSE VALUES(unban) END, " ..
        "reason = VALUES(reason), name = VALUES(name), admin = VALUES(admin), " ..
        "modified_admin = VALUES(modified_admin), modified_time = VALUES(modified_time)",
        esc(sid64), t, u, reason, name, admin, modAdm, modTime
    )

    local q = DB:query(sql)
    function q:onSuccess()
        _pending.push[sid32] = nil  -- подтверждено
        dbg("pushBan OK", sid32)
    end
    function q:onError(err)
        local e = tostring(err)
        local transient = e:find("gone away") or e:find("Lost connection") or e:find("Can't connect")
        if not transient then _pending.push[sid32] = nil end  -- иначе оставим на retry
        logErr("pushBan " .. sid32, err)
    end
    q:start()
end

deleteBan = function(sid32)
    if not isValidSid32(sid32) then
        logErr("deleteBan", "невалидный SteamID32: " .. tostring(sid32))
        return
    end
    local sid64 = to64(sid32)
    if not sid64 then
        logErr("deleteBan", "не сконвертировать в SteamID64: " .. tostring(sid32))
        return
    end

    queueDelete(sid32)
    markWrite(sid32, "del")
    _cache[sid64] = nil
    if not isConn() then return end

    logInfo("deleteBan " .. sid32 .. " → " .. sid64)
    local q = DB:query("DELETE FROM ulib_bans WHERE steamid='" .. esc(sid64) .. "'")
    function q:onSuccess()
        _pending.del[sid32] = nil
        local aff = (self.affectedRows and self:affectedRows()) or "?"
        logInfo("deleteBan OK " .. sid32 .. " (affected=" .. tostring(aff) .. ")")
    end
    function q:onError(err) logErr("deleteBan " .. sid32, err) end
    q:start()
end

flushPending = function()
    if not isConn() then return end
    local pushes, dels = table.GetKeys(_pending.push), table.GetKeys(_pending.del)
    for _, sid32 in ipairs(pushes) do
        local data = _pending.push[sid32]
        if data then pushBan(sid32, data) end
    end
    for _, sid32 in ipairs(dels) do
        deleteBan(sid32)
    end
end

-- ──────────────────────────────────────────────────────
-- Применение строки в зеркало (ULib.bans) + кэш — идемпотентно
-- ──────────────────────────────────────────────────────
-- Пишем напрямую в ULib.bans, минуя ULib.addBan: тот перехвачен XGUI (плодит
-- таймеры разбана) и пишет в локальный SQLite. Прямая запись хук не вызывает.
applyActiveBan = function(sid32, sid64, time, unban, reason, name, admin, modAdm, modTime)
    reason, name, admin = reason or "", name or "", admin or ""
    _cache[sid64] = { unban = unban, reason = reason, admin = admin, name = name, time = time }

    local cur = ULib.bans[sid32]
    if cur and (tonumber(cur.unban) or 0) == unban
        and (cur.reason or "") == reason and (cur.admin or "") == admin then
        return  -- идентично — ничего не делаем
    end

    ULib.bans[sid32] = {
        steamID = sid32,
        time = (time and time > 0) and time or os.time(),
        unban = unban,
        reason = reason, name = name, admin = admin,
        modified_admin = modAdm or "", modified_time = modTime or 0,
    }
    _stats.applied = _stats.applied + 1
end

-- ──────────────────────────────────────────────────────
-- Кик
-- ──────────────────────────────────────────────────────
banMessageFor = function(sid32, banData)
    local msg
    if ULib.getBanMessage and sid32 and sid32 ~= "" then
        msg = ULib.getBanMessage(sid32, banData)
    end
    if not msg or msg == "" then
        msg = string.format("Вы забанены.\nПричина: %s\nАдминистратор: %s",
            (banData.reason and banData.reason ~= "" and banData.reason) or "(не указана)",
            (banData.admin  and banData.admin  ~= "" and banData.admin)  or "(не указан)")
    end
    return msg
end

-- Проход по онлайну: кикнуть всех у кого активный бан в кэше.
kickAllBanned = function()
    if not ULib or not ULib.kick then return end
    local now = os.time()
    local kicked = 0
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        local sid32 = ply:SteamID()
        if not isValidSid32(sid32) then continue end
        local sid64 = to64(sid32)
        if not sid64 then continue end

        local ban = _cache[sid64]
        if not ban then continue end
        local unban = tonumber(ban.unban) or 0
        if unban ~= 0 and unban <= now then _cache[sid64] = nil; continue end

        local banData = ULib.bans[sid32] or ban
        logInfo("KICK онлайн-забаненного: " .. sid32 .. " (" .. ply:Nick() .. ")")
        ULib.kick(ply, banMessageFor(sid32, banData))
        kicked = kicked + 1
    end
    if kicked > 0 then
        _stats.kicks = _stats.kicks + kicked
        logInfo("kickAllBanned: кикнуто " .. kicked)
    end
end

-- ──────────────────────────────────────────────────────
-- Reader: self-healing reconcile (полная сверка состояния)
-- ──────────────────────────────────────────────────────
reconcile = function(newSig)
    if not isConn() or not ULib then return end
    ULib.bans = ULib.bans or {}

    local q = DB:query("SELECT steamid,time,unban,reason,name,admin,modified_admin,modified_time FROM ulib_bans")
    function q:onSuccess(data)
        if not data then logInfo("reconcile: data=nil, пропуск"); return end
        ULib.bans = ULib.bans or {}
        _stats.reconciles = _stats.reconciles + 1
        local now = os.time()

        local desired = {}          -- sid32 → true: активные баны из БД
        local expiredToDelete = {}  -- истёкшие temp — вычистить из БД

        for _, row in ipairs(data) do
            local sid64 = tostring(row.steamid)
            if isValidSid64(sid64) then
                local sid32 = to32(sid64)
                if sid32 then
                    local unban = tonumber(row.unban) or 0
                    local time  = tonumber(row.time)  or 0
                    if unban ~= 0 and unban <= now then
                        expiredToDelete[#expiredToDelete + 1] = sid32
                    elseif recentWrite(sid32) == "del" then
                        -- мы только что разбанили; этот central-снапшот устарел.
                        -- НЕ применяем (иначе вернём бан в зеркало/кэш) — дадим снять.
                        dbg("reconcile: пропуск устаревшей строки (recent del)", sid32)
                    else
                        desired[sid32] = true
                        applyActiveBan(sid32, sid64, time, unban, row.reason, row.name,
                            row.admin, row.modified_admin, tonumber(row.modified_time) or 0)
                    end
                end
            end
        end

        -- Снять локальные баны, которых нет среди активных в БД.
        -- GUARD: если БД вернула 0 строк при многих локальных — вероятен сбой
        -- БД, чистку пропускаем (защита от массовой потери, в т.ч. перма).
        local localCount = table.Count(ULib.bans)
        if #data == 0 and localCount > 3 then
            logInfo("reconcile: БД вернула 0 строк при " .. localCount ..
                    " локальных — пропуск чистки (защита данных)")
        else
            local toRemove = {}
            for sid32 in pairs(ULib.bans) do
                -- не трогаем: активные из БД, push в полёте, и свежепоставленные
                -- (central-снапшот мог не увидеть наш только что отправленный бан)
                if not desired[sid32] and not _pending.push[sid32]
                    and recentWrite(sid32) ~= "push" then
                    toRemove[#toRemove + 1] = sid32
                end
            end
            for _, sid32 in ipairs(toRemove) do
                ULib.bans[sid32] = nil
                local s64 = to64(sid32)
                if s64 then _cache[s64] = nil end
                if timer.Exists("xgui_unban" .. sid32) then timer.Remove("xgui_unban" .. sid32) end
                _stats.removed = _stats.removed + 1
            end
            if #toRemove > 0 then logInfo("reconcile: снято локально " .. #toRemove) end
        end

        for _, sid32 in ipairs(expiredToDelete) do deleteBan(sid32) end

        kickAllBanned()  -- кикнуть уже-онлайн новозабаненных

        if newSig ~= nil then _lastSig = newSig end
        dbg("reconcile: активных=" .. table.Count(desired) .. " истёкших=" .. #expiredToDelete)
    end
    function q:onError(err) logErr("reconcile", err) end
    q:start()
end

-- probe: дешёвая подпись таблицы. Контент-хэш BIT_XOR(CRC32(steamid|time|unban))
-- меняется при ЛЮБОМ изменении содержимого: insert, delete, update unban/time,
-- и даже delete+insert РАЗНЫХ строк в одну секунду (steamid входит в хэш —
-- сумма меток могла бы дать ложное «без изменений», а XOR хэшей — нет).
-- n ловит баланс строк, maxts — вторичный быстрый сигнал по updated_at.
probe = function()
    if not isConn() then return end
    flushPending()
    local q = DB:query(
        "SELECT COUNT(*) AS n, " ..
        "COALESCE(MAX(UNIX_TIMESTAMP(updated_at)),0) AS maxts, " ..
        "COALESCE(BIT_XOR(CRC32(CONCAT_WS('|',steamid,time,unban))),0) AS xr " ..
        "FROM ulib_bans")
    function q:onSuccess(data)
        local r = data and data[1]
        if not r then return end
        local sig = tostring(r.n) .. "|" .. tostring(r.maxts) .. "|" .. tostring(r.xr)
        if sig == _lastSig then return end
        dbg("probe: подпись", tostring(_lastSig), "→", sig, "→ reconcile")
        reconcile(sig)
    end
    function q:onError(err) logErr("probe", err) end
    q:start()
end

-- ──────────────────────────────────────────────────────
-- Принуждение, слой 1: CheckPassword (HOOK_HIGH — раньше Nova/FAdmin)
-- ──────────────────────────────────────────────────────
hook.Add("CheckPassword", "BanSync_CheckPassword", function(sid64)
    sid64 = tostring(sid64)
    if not isValidSid64(sid64) then return end
    local ban = _cache[sid64]
    if not ban then return end

    local unban = tonumber(ban.unban) or 0
    if unban ~= 0 and unban <= os.time() then _cache[sid64] = nil; return end

    local sid32 = to32(sid64)
    local banData = (sid32 and ULib.bans[sid32]) or {
        time = ban.time, unban = unban, reason = ban.reason, name = ban.name, admin = ban.admin }
    _stats.checkpw_kicks = _stats.checkpw_kicks + 1
    dbg("CheckPassword: отказ", sid64, isPerma(unban) and "(ПЕРМА)" or "")
    return false, banMessageFor(sid32, banData)
end, HOOK_HIGH)

-- ──────────────────────────────────────────────────────
-- Принуждение, слой 2: авторитетная проверка на входе (PlayerAuthed +
-- PlayerInitialSpawn). Прямой запрос в БД и кик НЕЗАВИСИМО от CheckPassword.
-- ──────────────────────────────────────────────────────
checkBanOnJoin = function(ply)
    if not IsValid(ply) then return end
    local sid32 = ply:SteamID()
    if not isValidSid32(sid32) then return end
    local sid64 = to64(sid32)
    if not sid64 then return end

    -- быстрый путь: кэш
    local c = _cache[sid64]
    if c then
        local u = tonumber(c.unban) or 0
        if u == 0 or u > os.time() then
            ULib.kick(ply, banMessageFor(sid32, ULib.bans[sid32] or c))
            return
        end
    end

    if not isConn() then return end
    local q = DB:query("SELECT * FROM ulib_bans WHERE steamid='" .. esc(sid64) ..
                       "' AND (unban = 0 OR unban > UNIX_TIMESTAMP()) LIMIT 1")
    function q:onSuccess(data)
        local row = data and data[1]
        if not row or not IsValid(ply) then return end
        local sid = to32(tostring(row.steamid))
        if not sid then return end
        applyActiveBan(sid, tostring(row.steamid), tonumber(row.time) or 0,
            tonumber(row.unban) or 0, row.reason, row.name, row.admin,
            row.modified_admin, tonumber(row.modified_time) or 0)
        logInfo("AUTH-CHECK KICK: " .. sid .. " (" .. ply:Nick() .. ")")
        ULib.kick(ply, banMessageFor(sid, ULib.bans[sid]))
    end
    function q:onError(err) logErr("checkBanOnJoin " .. sid32, err) end
    q:start()
end

hook.Add("PlayerAuthed", "BanSync_AuthCheck", function(ply)
    timer.Simple(0.5, function() checkBanOnJoin(ply) end)
end)
hook.Add("PlayerInitialSpawn", "BanSync_SpawnCheck", function(ply)
    timer.Simple(0.5, function() checkBanOnJoin(ply) end)
end)

-- ──────────────────────────────────────────────────────
-- ULib хуки бана/разбана → push/delete
-- ──────────────────────────────────────────────────────
-- Хуки срабатывают только на реальные действия админа (ULib.addBan/unban). Наш
-- reconcile пишет в ULib.bans напрямую и НЕ вызывает ULib.addBan — петли нет.
hook.Add("ULibPlayerBanned", "BanSync_OnBan", function(steamid, banData)
    if not banData then return end
    if not isValidSid32(steamid) then
        logErr("ULibPlayerBanned", "невалидный SteamID32: " .. tostring(steamid))
        return
    end
    dbg("HOOK ULibPlayerBanned", steamid, isPerma(banData) and "(ПЕРМА)" or "")
    -- Сразу наполняем кэш (не ждём reconcile) — мгновенное принуждение.
    local sid64 = to64(steamid)
    if sid64 then
        _cache[sid64] = {
            unban = tonumber(banData.unban) or 0,
            reason = banData.reason or "", admin = banData.admin or "",
            name = banData.name or "", time = tonumber(banData.time) or os.time(),
        }
    end
    pushBan(steamid, banData)
end)

hook.Add("ULibPlayerUnBanned", "BanSync_OnUnban", function(steamid)
    if not isValidSid32(steamid) then
        logErr("ULibPlayerUnBanned", "невалидный SteamID32: " .. tostring(steamid))
        return
    end
    logInfo("HOOK ULibPlayerUnBanned " .. tostring(steamid))
    if timer.Exists("xgui_unban" .. steamid) then timer.Remove("xgui_unban" .. steamid) end
    deleteBan(steamid)
end)

-- ──────────────────────────────────────────────────────
-- Bootstrap + подключение
-- ──────────────────────────────────────────────────────
local function bootstrap()
    if not isConn() then return end
    logInfo("Bootstrap: полная сверка с центральной БД")
    _lastSig = nil
    probe()  -- подпись ≠ nil → выполнит первый reconcile и наполнит зеркало/кэш
    _bootstrapped = true

    timer.Create("BanSync_Poll", CFG.poll_interval, 0, probe)
    timer.Simple(20, kickAllBanned)  -- если игроки уже онлайн с момента старта
end

local function migrateTable(callback)
    local q1 = DB:query("ALTER TABLE ulib_bans ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP")
    function q1:onError(err)
        if not string.find(tostring(err), "Duplicate column name") then logErr("ALTER updated_at", err) end
    end
    q1:start()

    local q2 = DB:query("ALTER TABLE ulib_bans ADD INDEX idx_updated (updated_at)")
    function q2:onError(err)
        if not string.find(tostring(err), "Duplicate") then logErr("ADD INDEX idx_updated", err) end
    end
    q2:start()

    timer.Simple(1.5, callback)
end

local function ensureTable()
    local q = DB:query([[
        CREATE TABLE IF NOT EXISTS ulib_bans (
            steamid        VARCHAR(20)  NOT NULL,
            time           BIGINT       DEFAULT 0,
            unban          BIGINT       DEFAULT 0,
            reason         TEXT,
            name           VARCHAR(64),
            admin          VARCHAR(128),
            modified_admin VARCHAR(128),
            modified_time  BIGINT       DEFAULT 0,
            updated_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (steamid),
            INDEX idx_updated (updated_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    function q:onSuccess()
        logInfo("ulib_bans готова, проверяю миграции...")
        migrateTable(bootstrap)
    end
    function q:onError(err) logErr("CREATE TABLE", err) end
    q:start()
end

local connect
connect = function()
    logInfo("connect() запущен")
    if not mysqloo then
        ErrorNoHalt(PREFIX .. "mysqloo не загружен — положи gmsv_mysqloo_*.dll в lua/bin/\n")
        return
    end
    local ok, dbOrErr = pcall(mysqloo.connect, CFG.hostname, CFG.username,
                              CFG.password, CFG.database, CFG.port)
    if not ok then
        logErr("mysqloo.connect", dbOrErr)
        timer.Simple(CFG.reconnect, connect)
        return
    end
    DB = dbOrErr
    function DB:onConnected()
        logInfo("Подключено к " .. CFG.database .. " @ " .. CFG.hostname)
        suppressForeign()
        ensureTable()
    end
    function DB:onConnectionFailed(err)
        logErr("Подключение", err)
        timer.Simple(CFG.reconnect, connect)
    end
    DB:connect()
end

local _connect_done = false
local function safeConnect()
    if _connect_done then return end
    _connect_done = true
    connect()
end

hook.Add("Initialize",     "BanSync_Init",           function() timer.Simple(5, safeConnect) end)
hook.Add("InitPostEntity", "BanSync_InitPostEntity", function() timer.Simple(3, safeConnect) end)
timer.Simple(10, safeConnect)

-- ──────────────────────────────────────────────────────
-- Console commands (суперадмин или server console)
-- ──────────────────────────────────────────────────────
local function isAuthorized(ply) return not IsValid(ply) or ply:IsSuperAdmin() end
local function tellAll(ply, lines)
    for _, msg in ipairs(lines) do
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end
end

concommand.Add("bansync_status", function(ply)
    if not isAuthorized(ply) then return end
    local s
    if not mysqloo then s = "mysqloo НЕ ЗАГРУЖЕН"
    elseif not DB then s = "не инициализирована"
    else
        local st = DB:status()
        s = (st == mysqloo.DATABASE_CONNECTED  and "подключена")
            or (st == mysqloo.DATABASE_CONNECTING and "подключается...")
            or ("отключена (status=" .. tostring(st) .. ")")
    end
    local lc, permC, cacheC = 0, 0, 0
    for _, b in pairs(ULib.bans or {}) do
        lc = lc + 1
        if (tonumber(b and b.unban) or 0) == 0 then permC = permC + 1 end
    end
    for _ in pairs(_cache) do cacheC = cacheC + 1 end
    tellAll(ply, {
        PREFIX .. "=== Статус v3 (reconcile) ===",
        PREFIX .. "БД: " .. s .. " (" .. CFG.database .. " @ " .. CFG.hostname .. ")",
        PREFIX .. "Зеркало ULib.bans: " .. lc .. " (перм=" .. permC .. ")",
        PREFIX .. "Кэш CheckPassword: " .. cacheC,
        PREFIX .. "Подпись (_lastSig): " .. tostring(_lastSig),
        PREFIX .. "_bootstrapped: " .. tostring(_bootstrapped),
        PREFIX .. "Pending: push=" .. table.Count(_pending.push) .. " del=" .. table.Count(_pending.del),
        PREFIX .. "ULib.mySQL_Active: " .. tostring(ULib and ULib.mySQL_Active),
        PREFIX .. "Stats: push=" .. _stats.push .. " reconciles=" .. _stats.reconciles ..
                 " applied=" .. _stats.applied .. " removed=" .. _stats.removed ..
                 " kicks=" .. _stats.kicks .. " checkpw=" .. _stats.checkpw_kicks ..
                 " errors=" .. _stats.errors,
        PREFIX .. "Last err: " .. (_stats.lastErr == "" and "—" or _stats.lastErr),
    })
end)

-- Принудительная полная сверка (сброс подписи → гарантированный reconcile)
concommand.Add("bansync_reconcile", function(ply)
    if not isAuthorized(ply) then return end
    _lastSig = nil
    probe()
    tellAll(ply, { PREFIX .. "Полная сверка (reconcile) запущена" })
end)

-- Принудительный push всех локальных банов в центральную БД
concommand.Add("bansync_push_all", function(ply)
    if not isAuthorized(ply) then return end
    if not isConn() then tellAll(ply, { PREFIX .. "Нет соединения с БД" }); return end
    local n = 0
    for sid, b in pairs(ULib.bans or {}) do
        if isValidSid32(sid) then pushBan(sid, b); n = n + 1 end
    end
    tellAll(ply, { PREFIX .. "Push запущен для " .. n .. " локальных банов" })
end)

-- Прогон сафти-нета вручную: кикнуть всех онлайн-забаненных
concommand.Add("bansync_kick_now", function(ply)
    if not isAuthorized(ply) then return end
    kickAllBanned()
    tellAll(ply, { PREFIX .. "kickAllBanned выполнен" })
end)

logInfo("Модуль банов v3 загружен — poll=" .. CFG.poll_interval ..
        "s, self-healing reconcile, 3-слойное принуждение (ulx_sync_debug 1 — дебаг)")
