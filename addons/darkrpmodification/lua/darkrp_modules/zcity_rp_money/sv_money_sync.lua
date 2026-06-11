--[[===========================================================================
ZCity RP — единая синхронизация денег между серверами кластера
=============================================================================
БД:      money @ УКАЖИТЕ_IP_БД  (выделенная кластерная БД денег, юзер gmod)
Таблица: darkrp_wallets (steamid, name, wallet, updated_at)

АРХИТЕКТУРА (важно):
  Каноничный кошелёк живёт в MySQL — это ЕДИНСТВЕННЫЙ источник правды.
  Локальный DarkRP-кошелёк (data/darkrp_player.json) больше не авторитет:
  при входе игрока мы ПЕРЕТИРАЕМ его значением из БД (pull-on-join), а при
  каждом изменении кошелька (playerWalletChanged) ПУШИМ в БД (push-on-change).
  Игрок физически бывает только на одном сервере, поэтому одновременных
  записей в один кошелёк не бывает → LWW по updated_at безопасен.

  СИД: авто-засева НЕТ (балансы 5 серверов разошлись, есть следы дюпа).
       Канон по игроку формируется при ПЕРВОМ заходе после включения синхры:
         • строка в БД есть  → она канон, перетираем локальный кошелёк;
         • строки в БД нет    → first-seen: пушим текущий локальный как канон.
       Балансы правятся вручную командой  money_sync_set <steamid> <сумма>
       (superadmin) — она пишет прямо в канон и тут же раздаёт онлайн-игроку.

  Фолбэк при недоступности БД: локальный кошелёк НЕ трогаем и НЕ обнуляем;
  push не делаем, пока не подтянули канон (флаг _synced). Раз в 30с —
  повторная попытка pull для онлайн-игроков без канона.
=============================================================================]]

if not SERVER then return end

-- mysqloo обычно уже загружен ULX-синком; подстрахуемся.
if not mysqloo then
    local ok, err = pcall(require, "mysqloo")
    if not ok then
        ErrorNoHalt("[Money Sync] require('mysqloo') упал: " .. tostring(err) .. "\n")
    end
end

local CFG = {
    hostname      = "УКАЖИТЕ_IP_БД",   -- выделенная кластерная БД денег (см. money-db)
    username      = "УКАЖИТЕ_ЛОГИН",
    password      = "УКАЖИТЕ_ПАРОЛЬ",
    database      = "money",
    port          = 3306,
    poll_interval = 30,    -- pull дельты + ретрай несинхронизированных
    push_debounce = 1.0,   -- объединяем серию изменений кошелька в один push
    reconnect     = 30,
    spawn_pull    = 4,     -- через сколько сек после спавна тянуть канон
    pull_retries  = 6,     -- сколько раз ждать загрузки DarkRP-кошелька
}

local PREFIX  = "[Money Sync] "
local DB      = nil
local _applying   = false   -- наш собственный addMoney → не пушим обратно (петля)
local _lastPullTs = 0       -- UNIX-сек последнего обработанного updated_at
local _synced     = {}      -- sid(upper) → true: канон уже подтянут в этой сессии
local _pendingPush = {}     -- sid(upper) → true: push ещё не подтверждён БД

CreateConVar("money_sync_debug", "0", FCVAR_ARCHIVE, "Подробный лог синхронизации денег (0/1)")

local _stats = { push = 0, pull = 0, applied = 0, seeded = 0, errors = 0, lastErr = "" }

local function dbg(...)
    if GetConVar("money_sync_debug"):GetInt() == 0 then return end
    local p = {...}; for i, v in ipairs(p) do p[i] = tostring(v) end
    print(PREFIX .. "[DEBUG] " .. table.concat(p, " "))
end

local function log(...)
    local p = {...}; for i, v in ipairs(p) do p[i] = tostring(v) end
    print(PREFIX .. table.concat(p, " "))
end

-- =====================================================
-- Утилиты
-- =====================================================

local function isConn() return DB and DB:status() == mysqloo.DATABASE_CONNECTED end
local function esc(s)   return DB:escape(tostring(s or "")) end

local function logErr(label, err)
    _stats.errors  = _stats.errors + 1
    _stats.lastErr = label .. ": " .. tostring(err)
    ErrorNoHalt(PREFIX .. label .. ": " .. tostring(err) .. "\n")
end

local function isTransientErr(err)
    local s = tostring(err)
    return s:find("Server has gone away") or s:find("Can't connect")
        or s:find("Lost connection") or s:find("MySQL server has gone away")
end

-- Текущий кошелёк игрока (число) или nil, если DarkRP ещё не загрузил.
local function getWallet(ply)
    if not (IsValid(ply) and ply.getDarkRPVar) then return nil end
    local m = ply:getDarkRPVar("money")
    if type(m) ~= "number" then return nil end
    return math.floor(m)
end

-- Жёстко выставляет локальный кошелёк = target (через DarkRP addMoney с diff),
-- не вызывая обратного push (под _applying).
local function setWalletLocal(ply, target)
    if not (IsValid(ply) and ply.addMoney) then return false end
    local cur = getWallet(ply)
    if not cur then return false end
    local diff = math.floor(target) - cur
    if diff == 0 then return true end
    _applying = true
    ply:addMoney(diff)
    _applying = false
    return true
end

-- =====================================================
-- MySQL → DarkRP
-- =====================================================

-- Пуш текущего кошелька игрока в БД (INSERT ... ON DUPLICATE KEY UPDATE).
local function pushWallet(ply)
    if not isConn() then dbg("pushWallet: нет соединения"); return end
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    local sidU = sid:upper()
    local wallet = getWallet(ply)
    if not wallet then dbg("pushWallet: кошелёк ещё не загружен →", sid); return end

    local name = esc(ply:Nick())
    local w    = math.floor(wallet)
    _stats.push = _stats.push + 1
    _pendingPush[sidU] = true
    dbg("pushWallet: →", sid, "wallet=" .. w)

    local q = DB:query(
        "INSERT INTO darkrp_wallets (steamid,name,wallet) VALUES('"
        .. esc(sid) .. "','" .. name .. "'," .. w ..
        ") ON DUPLICATE KEY UPDATE name='" .. name .. "',wallet=" .. w .. ",updated_at=NOW()")
    function q:onSuccess() _pendingPush[sidU] = nil end
    function q:onError(err)
        if not isTransientErr(err) then _pendingPush[sidU] = nil end
        logErr("pushWallet " .. sid, err)
    end
    q:start()
end

-- Подтягивает канон для игрока. Есть строка → перетираем локальный кошелёк;
-- нет строки → first-seen, пушим текущий локальный как канон.
local function pullWallet(ply, attempt)
    if not (IsValid(ply) and isConn()) then return end
    attempt = attempt or 1
    local sid = ply:SteamID()
    local sidU = sid:upper()

    -- Ждём пока DarkRP загрузит кошелёк (иначе не с чем сравнивать / нечего сидить).
    if not getWallet(ply) then
        if attempt <= CFG.pull_retries then
            timer.Simple(1, function() pullWallet(ply, attempt + 1) end)
        else
            dbg("pullWallet: кошелёк так и не загрузился →", sid)
        end
        return
    end

    local q = DB:query("SELECT wallet FROM darkrp_wallets WHERE steamid='" .. esc(sid) .. "' LIMIT 1")
    function q:onSuccess(data)
        if not IsValid(ply) then return end
        if data and data[1] then
            local canon = math.floor(tonumber(data[1].wallet) or 0)
            local cur = getWallet(ply) or 0
            if canon ~= cur then
                log("pullWallet: канон ≠ локальный →", sid, cur .. " → " .. canon)
                setWalletLocal(ply, canon)
                _stats.applied = _stats.applied + 1
            else
                dbg("pullWallet: канон == локальный →", sid, "(" .. canon .. ")")
            end
            _synced[sidU] = true
        else
            -- first-seen: строки в БД нет → текущий локальный становится каноном.
            log("pullWallet: first-seen → пушу локальный как канон →", sid, "(" .. (getWallet(ply) or 0) .. ")")
            _synced[sidU] = true
            _stats.seeded = _stats.seeded + 1
            pushWallet(ply)
        end
    end
    function q:onError(err) logErr("pullWallet " .. sid, err) end
    q:start()
end

-- Дельта: применяем чужие изменения канона к ОНЛАЙН-игрокам этого сервера
-- (например, админ поправил баланс в БД, или это эхо нашего же push — тогда no-op).
local function pullDelta()
    if not isConn() then return end
    local sql = _lastPullTs > 0
        and ("SELECT steamid, wallet, UNIX_TIMESTAMP(updated_at) AS _ts FROM darkrp_wallets WHERE updated_at > FROM_UNIXTIME(" .. _lastPullTs .. ")")
        or  ("SELECT steamid, wallet, UNIX_TIMESTAMP(updated_at) AS _ts FROM darkrp_wallets WHERE 0")
    _stats.pull = _stats.pull + 1

    local q = DB:query(sql)
    function q:onSuccess(data)
        local maxTs = _lastPullTs
        for _, row in ipairs(data or {}) do
            local ts = tonumber(row._ts) or 0
            if ts > maxTs then maxTs = ts end
            local sid = tostring(row.steamid)
            local ply = player.GetBySteamID(sid)
            if IsValid(ply) and _synced[sid:upper()] then
                local canon = math.floor(tonumber(row.wallet) or 0)
                if getWallet(ply) and canon ~= getWallet(ply) then
                    dbg("pullDelta: канон обновлён извне →", sid, "→ " .. canon)
                    setWalletLocal(ply, canon)
                    _stats.applied = _stats.applied + 1
                end
            end
        end
        if maxTs > _lastPullTs then _lastPullTs = maxTs end
    end
    function q:onError(err) logErr("pullDelta", err) end
    q:start()
end

-- Ретрай: онлайн-игроки без подтянутого канона (БД была недоступна на входе)
-- + повтор зависших push.
local function retrySync()
    if not isConn() then return end
    for _, ply in ipairs(player.GetHumans()) do
        local sidU = ply:SteamID():upper()
        if not _synced[sidU] then pullWallet(ply) end
    end
    for sidU in pairs(_pendingPush) do
        local ply = player.GetBySteamID(sidU)
        if IsValid(ply) then pushWallet(ply) end
    end
end

-- =====================================================
-- Хуки
-- =====================================================

-- Любое изменение кошелька → push (если канон уже подтянут).
hook.Add("playerWalletChanged", "MoneySync_OnWalletChanged", function(ply, diff, oldAmount)
    if _applying then return end                 -- наше собственное выставление
    if not IsValid(ply) then return end
    local sidU = ply:SteamID():upper()
    if not _synced[sidU] then return end         -- ещё не подтянули канон — не перетираем его
    timer.Create("MoneySync_Push_" .. sidU, CFG.push_debounce, 1, function()
        if IsValid(ply) then pushWallet(ply) end
    end)
end)

hook.Add("PlayerInitialSpawn", "MoneySync_OnSpawn", function(ply)
    if not IsValid(ply) or ply:IsBot() then return end
    timer.Simple(CFG.spawn_pull, function()
        if IsValid(ply) then pullWallet(ply) end
    end)
end)

-- Финальный push при выходе: фиксируем последний баланс как канон до того,
-- как игрок зайдёт на другой сервер кластера.
hook.Add("PlayerDisconnected", "MoneySync_OnLeave", function(ply)
    if not IsValid(ply) then return end
    local sidU = ply:SteamID():upper()
    if _synced[sidU] and getWallet(ply) then pushWallet(ply) end
    _synced[sidU] = nil
end)

-- =====================================================
-- Таблица / bootstrap / подключение
-- =====================================================

local function bootstrap()
    if not isConn() then return end
    -- Без авто-засева: ставим курсор на текущее время БД, тянем только будущие дельты.
    local q = DB:query("SELECT UNIX_TIMESTAMP(NOW()) AS now_ts")
    function q:onSuccess(data)
        _lastPullTs = (data and data[1] and tonumber(data[1].now_ts)) or os.time()
        log("Bootstrap: курсор дельты = " .. _lastPullTs .. " (авто-засев выключен)")
        -- Подтянуть канон для уже находящихся на сервере игроков.
        for _, ply in ipairs(player.GetHumans()) do pullWallet(ply) end
        timer.Create("MoneySync_Poll", CFG.poll_interval, 0, function()
            pullDelta(); retrySync()
        end)
    end
    function q:onError(err)
        logErr("bootstrap NOW", err)
        timer.Create("MoneySync_Poll", CFG.poll_interval, 0, function() pullDelta(); retrySync() end)
    end
    q:start()
end

local function ensureTable()
    local q = DB:query([[
        CREATE TABLE IF NOT EXISTS darkrp_wallets (
            steamid    VARCHAR(32) NOT NULL,
            name       VARCHAR(64),
            wallet     BIGINT      NOT NULL DEFAULT 0,
            updated_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (steamid),
            INDEX idx_updated (updated_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    function q:onSuccess()
        log("Таблица darkrp_wallets готова")
        bootstrap()
    end
    function q:onError(err) logErr("CREATE TABLE", err) end
    q:start()
end

local function connect()
    if not mysqloo then
        ErrorNoHalt(PREFIX .. "mysqloo не установлен (нет gmsv_mysqloo_*.dll в lua/bin)\n")
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
        log("Подключено к " .. CFG.database .. " @ " .. CFG.hostname)
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
hook.Add("InitPostEntity", "MoneySync_Init", function() timer.Simple(4, safeConnect) end)
timer.Simple(12, safeConnect)   -- фолбэк

-- =====================================================
-- Команды (superadmin)
-- =====================================================

local function tell(ply, lines)
    for _, m in ipairs(lines) do
        if IsValid(ply) then ply:ChatPrint(m) else print(m) end
    end
end

concommand.Add("money_sync_status", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local s = not mysqloo and "❌ mysqloo НЕ ЗАГРУЖЕН"
        or not DB and "не инициализирована"
        or (isConn() and "подключена" or ("отключена (status=" .. tostring(DB:status()) .. ")"))
    local nSync = 0; for _ in pairs(_synced) do nSync = nSync + 1 end
    tell(ply, {
        PREFIX .. "=== Статус денежной синхры ===",
        PREFIX .. "БД: " .. s .. " (" .. CFG.database .. " @ " .. CFG.hostname .. ")",
        PREFIX .. "Онлайн с подтянутым каноном: " .. nSync,
        PREFIX .. "lastPullTs: " .. _lastPullTs,
        PREFIX .. "Stats: push=" .. _stats.push .. " pull=" .. _stats.pull ..
                 " applied=" .. _stats.applied .. " seeded=" .. _stats.seeded ..
                 " errors=" .. _stats.errors,
        PREFIX .. "Last err: " .. (_stats.lastErr == "" and "—" or _stats.lastErr),
    })
end)

-- Принудительно задать канон-баланс и выдать онлайн-игроку (ручная правка дюпов).
concommand.Add("money_sync_set", function(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local sid = tostring(args[1] or ""):upper()
    local amount = math.floor(tonumber(args[2] or "") or (0/0))
    if not string.match(sid, "^STEAM_%d:%d:%d+$") or amount ~= amount then
        tell(ply, { PREFIX .. "Использование: money_sync_set STEAM_0:0:123 1000000" })
        return
    end
    if not isConn() then tell(ply, { PREFIX .. "Нет соединения с БД" }); return end

    local target = player.GetBySteamID(sid)
    local name = IsValid(target) and target:Nick() or ""
    local q = DB:query(
        "INSERT INTO darkrp_wallets (steamid,name,wallet) VALUES('"
        .. esc(sid) .. "','" .. esc(name) .. "'," .. amount ..
        ") ON DUPLICATE KEY UPDATE wallet=" .. amount .. ",updated_at=NOW()")
    function q:onSuccess()
        tell(ply, { PREFIX .. "Канон установлен: " .. sid .. " = " .. amount })
        if IsValid(target) and _synced[sid] then setWalletLocal(target, amount) end
    end
    function q:onError(err) logErr("money_sync_set", err); tell(ply, { PREFIX .. "Ошибка: " .. tostring(err) }) end
    q:start()
end)

-- Глянуть канон по конкретному игроку.
concommand.Add("money_sync_get", function(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local sid = tostring(args[1] or ""):upper()
    if not isConn() then tell(ply, { PREFIX .. "Нет соединения с БД" }); return end
    local q = DB:query("SELECT wallet, UNIX_TIMESTAMP(updated_at) AS ts FROM darkrp_wallets WHERE steamid='" .. esc(sid) .. "' LIMIT 1")
    function q:onSuccess(data)
        if data and data[1] then
            tell(ply, { PREFIX .. sid .. " канон=" .. tostring(data[1].wallet) .. " ts=" .. tostring(data[1].ts) })
        else
            tell(ply, { PREFIX .. sid .. " — строки в БД нет (канон не задан)" })
        end
    end
    function q:onError(err) logErr("money_sync_get", err) end
    q:start()
end)

log("Модуль денежной синхры загружен (канон в MySQL; дебаг: money_sync_debug 1)")
