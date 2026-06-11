--[[
    ZCity Logs — серверное ядро.
    - SQLite таблица `zlogs` с индексами
    - API ZLogs.Add(cat, ply, data, text)
    - Ротация старых логов
    - Хук ZLogs.OnAdd (можно подписаться извне — например, Discord)
]]

if not ZLogs then
    AddCSLuaFile("autorun/sh_zlogs.lua")
    include("autorun/sh_zlogs.lua")
end

-- ============================================
-- ИНИЦИАЛИЗАЦИЯ БД
-- ============================================

local function safe(str)
    return sql.SQLStr(tostring(str or ""))
end

local function exec(q)
    local ok = sql.Query(q)
    if ok == false then
        ErrorNoHalt("[ZLogs] SQL error: " .. tostring(sql.LastError()) .. "\nQuery: " .. q .. "\n")
        return false
    end
    return true
end

local function InitDatabase()
    exec([[
        CREATE TABLE IF NOT EXISTS zlogs (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            ts           INTEGER NOT NULL,
            cat          TEXT    NOT NULL,
            sid          TEXT,
            sid_target   TEXT,
            nick         TEXT,
            nick_target  TEXT,
            txt          TEXT    NOT NULL,
            data         TEXT
        );
    ]])
    exec("CREATE INDEX IF NOT EXISTS idx_zlogs_ts         ON zlogs(ts);")
    exec("CREATE INDEX IF NOT EXISTS idx_zlogs_cat        ON zlogs(cat);")
    exec("CREATE INDEX IF NOT EXISTS idx_zlogs_sid        ON zlogs(sid);")
    exec("CREATE INDEX IF NOT EXISTS idx_zlogs_sid_target ON zlogs(sid_target);")
end

InitDatabase()

-- Очищаем логи при каждом старте сервера
exec("DELETE FROM zlogs;")
MsgN("[ZLogs] Логи очищены при старте сервера")

-- ============================================
-- РОТАЦИЯ СТАРЫХ ЛОГОВ
-- ============================================

local function RotateOldLogs()
    local cutoff = os.time() - (ZLogs.RETENTION_DAYS * 86400)
    local before = sql.QueryValue("SELECT COUNT(*) FROM zlogs;") or "0"
    exec("DELETE FROM zlogs WHERE ts < " .. cutoff .. ";")
    local after  = sql.QueryValue("SELECT COUNT(*) FROM zlogs;") or "0"
    local removed = tonumber(before) - tonumber(after)
    if removed > 0 then
        MsgN("[ZLogs] Ротация: удалено " .. removed .. " логов старше " .. ZLogs.RETENTION_DAYS .. " дней")
    end
end

-- Ротация при старте и каждые 12 часов
timer.Simple(30, RotateOldLogs)
timer.Create("ZLogs_Rotate", 43200, 0, RotateOldLogs)

-- ============================================
-- API: ZLogs.Add
-- ============================================
--
-- cat      — категория из ZLogs.Categories
-- ply      — игрок-инициатор (entity или SteamID; nil = система/консоль)
-- text     — сформированный текст лога (на русском, готовый для показа)
-- data     — таблица доп. данных (опционально):
--              { target = ply/sid, amount = N, weapon = "...", pos = Vector, ... }
--
function ZLogs.Add(cat, ply, text, data)
    if not cat or not ZLogs.Categories[cat] then
        cat = "system"
    end
    text = ZLogs.Truncate(text or "")
    if text == "" then return end

    data = data or {}

    local sid, nick
    if type(ply) == "string" then
        sid  = ply
        nick = data.nick or ""
    elseif IsValid(ply) and ply.SteamID then
        sid  = ply:SteamID() or ""
        nick = ply:Nick() or ""
    else
        sid  = ""
        nick = "Консоль"
    end

    local target     = data.target
    local sid_target = ""
    local nick_target = ""
    if type(target) == "string" then
        sid_target = target
    elseif IsValid(target) and target.SteamID then
        sid_target  = target:SteamID() or ""
        nick_target = target:Nick() or ""
    end
    if data.nick_target then nick_target = data.nick_target end

    -- Сериализуем data в JSON (без объекта target — это entity, не сериализуется)
    local jsonData = nil
    do
        local copy = {}
        for k, v in pairs(data) do
            if k ~= "target" and type(v) ~= "userdata" and type(v) ~= "function" then
                if type(v) == "Vector" or (type(v) == "table" and v.x and v.y and v.z) then
                    copy[k] = { x = v.x, y = v.y, z = v.z }
                else
                    copy[k] = v
                end
            end
        end
        if next(copy) then
            jsonData = util.TableToJSON(copy)
        end
    end

    local ts = os.time()
    local q = string.format(
        "INSERT INTO zlogs (ts, cat, sid, sid_target, nick, nick_target, txt, data) VALUES (%d, %s, %s, %s, %s, %s, %s, %s);",
        ts,
        safe(cat),
        safe(sid),
        safe(sid_target),
        safe(nick),
        safe(nick_target),
        safe(text),
        jsonData and safe(jsonData) or "NULL"
    )

    exec(q)

    -- Внешние подписчики (например, Discord, live-режим) могут хукаться сюда
    hook.Run("ZLogs.OnAdd", cat, sid, nick, text, data, ts)

    return true
end

-- Удобный шортхэнд: ZLogs.Sys("Сервер запущен") — категория system
function ZLogs.Sys(text, data)
    return ZLogs.Add("system", nil, text, data)
end

-- ============================================
-- API: ZLogs.Query — выборка с фильтрами
-- ============================================
--
-- filters = {
--     cat       = "kill" | nil,            -- фильтр по категории
--     sid       = "STEAM_..." | nil,       -- фильтр по SteamID (любая сторона)
--     search    = "текст поиска" | nil,    -- LIKE по тексту лога
--     from_ts   = unix | nil,              -- логи начиная с
--     to_ts     = unix | nil,              -- логи до
--     page      = 1,                       -- страница (с 1)
--     page_size = 100,
-- }
--
-- Возвращает: { rows = {...}, total = N }
--
function ZLogs.Query(filters)
    filters = filters or {}
    local where = {}

    if filters.cat and ZLogs.Categories[filters.cat] then
        table.insert(where, "cat = " .. safe(filters.cat))
    end

    if filters.sid and filters.sid ~= "" then
        table.insert(where, "(sid = " .. safe(filters.sid) .. " OR sid_target = " .. safe(filters.sid) .. ")")
    end

    if filters.search and filters.search ~= "" then
        local q = filters.search:gsub("'", "''"):gsub("%%", "")
        table.insert(where, "(txt LIKE '%" .. q .. "%' OR nick LIKE '%" .. q .. "%' OR nick_target LIKE '%" .. q .. "%' OR sid LIKE '%" .. q .. "%')")
    end

    if filters.from_ts then
        table.insert(where, "ts >= " .. math.floor(filters.from_ts))
    end
    if filters.to_ts then
        table.insert(where, "ts <= " .. math.floor(filters.to_ts))
    end

    local whereSQL = #where > 0 and (" WHERE " .. table.concat(where, " AND ")) or ""

    local total = tonumber(sql.QueryValue("SELECT COUNT(*) FROM zlogs" .. whereSQL .. ";") or "0") or 0

    local pageSize = math.Clamp(filters.page_size or ZLogs.PAGE_SIZE, 10, 500)
    local page     = math.max(1, filters.page or 1)
    local offset   = (page - 1) * pageSize

    local rows = sql.Query(
        "SELECT id, ts, cat, sid, sid_target, nick, nick_target, txt, data FROM zlogs" ..
        whereSQL ..
        " ORDER BY ts DESC, id DESC LIMIT " .. pageSize .. " OFFSET " .. offset .. ";"
    ) or {}

    return { rows = rows, total = total, page = page, page_size = pageSize }
end

-- ============================================
-- API: ZLogs.Clear — очистка (для админских действий)
-- ============================================
function ZLogs.Clear(cat)
    if cat and ZLogs.Categories[cat] then
        exec("DELETE FROM zlogs WHERE cat = " .. safe(cat) .. ";")
        ZLogs.Sys("Логи категории '" .. ZLogs.Categories[cat].name .. "' очищены")
    else
        exec("DELETE FROM zlogs;")
        ZLogs.Sys("Все логи очищены")
    end
end

MsgN("[ZLogs] Ядро загружено (v" .. ZLogs.VERSION .. ")")

-- Стартовый системный лог
timer.Simple(1, function()
    ZLogs.Sys("Сервер запущен | карта: " .. game.GetMap())
end)
