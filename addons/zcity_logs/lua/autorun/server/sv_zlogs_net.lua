--[[
    ZCity Logs — net-протокол клиент↔сервер.

    Каналы:
      zlogs_query  (C→S) → клиент запрашивает страницу логов с фильтрами
      zlogs_page   (S→C) → сервер отправляет сжатый ответ
      zlogs_live   (S→C) → live-broadcast при добавлении нового лога (только тем у кого открыто меню)
      zlogs_clear  (C→S) → админ просит очистить категорию/всё
]]

if not ZLogs then return end

util.AddNetworkString("zlogs_query")
util.AddNetworkString("zlogs_page")
util.AddNetworkString("zlogs_live")
util.AddNetworkString("zlogs_clear")
util.AddNetworkString("zlogs_open_request")

-- ============================================
-- ПРОВЕРКА ПРАВ
-- ============================================

-- Группы которым разрешён просмотр логов
local LOGS_ACCESS_GROUPS = {
    superadmin  = true,
    admin       = true,
    moderator   = true,
    dsuperadmin = true,
    dadmin      = true,
    dmoderator  = true,
    operator    = true,
}

function ZLogs.CanView(ply)
    if not IsValid(ply) then return false end
    -- IsAdmin() покрывает admin/superadmin и всё что от них наследуется
    if ply:IsAdmin() then return true end
    -- Явная проверка групп (IsAdmin() возвращает false для moderator/dmoderator/operator)
    if LOGS_ACCESS_GROUPS[ply:GetUserGroup()] then return true end
    -- ULX доступ через привилегию "ulx logs"
    if ULib and ULib.ucl and ULib.ucl.query then
        if ULib.ucl.query(ply, "ulx logs") then return true end
    end
    return false
end

-- ============================================
-- RATE LIMIT
-- ============================================

local lastQuery = {}

local function isRateLimited(ply)
    local sid = ply:SteamID()
    local now = SysTime()
    if lastQuery[sid] and (now - lastQuery[sid]) < 0.3 then
        return true
    end
    lastQuery[sid] = now
    return false
end

-- ============================================
-- ОТПРАВКА ОТВЕТА
-- ============================================

local function sendPage(ply, result, reqId)
    local payload = util.TableToJSON({
        rows      = result.rows,
        total     = result.total,
        page      = result.page,
        page_size = result.page_size,
        reqId     = reqId,
    })
    local compressed = util.Compress(payload)
    local len = #compressed

    -- Net max size 65kb на сообщение
    if len > 60000 then
        -- Сократим страницу и попробуем снова
        result.rows = {} -- защитный fallback
        payload = util.TableToJSON({ rows = {}, total = result.total, page = result.page, page_size = result.page_size, reqId = reqId, error = "too_big" })
        compressed = util.Compress(payload)
        len = #compressed
    end

    net.Start("zlogs_page")
    net.WriteUInt(len, 24)
    net.WriteData(compressed, len)
    net.Send(ply)
end

-- ============================================
-- CLIENT → SERVER: запрос страницы
-- ============================================

net.Receive("zlogs_query", function(len, ply)
    if not IsValid(ply) then return end
    if not ZLogs.CanView(ply) then
        return
    end
    if isRateLimited(ply) then return end

    local dataLen = net.ReadUInt(24)
    local data = net.ReadData(dataLen)
    local decompressed = util.Decompress(data)
    if not decompressed then return end

    local filters = util.JSONToTable(decompressed)
    if type(filters) ~= "table" then return end

    -- Sanitize
    local clean = {
        cat       = type(filters.cat) == "string" and filters.cat or nil,
        sid       = type(filters.sid) == "string" and filters.sid or nil,
        search    = type(filters.search) == "string" and string.sub(filters.search, 1, 64) or nil,
        from_ts   = tonumber(filters.from_ts),
        to_ts     = tonumber(filters.to_ts),
        page      = tonumber(filters.page) or 1,
        page_size = tonumber(filters.page_size) or ZLogs.PAGE_SIZE,
    }
    local reqId = tonumber(filters.reqId) or 0

    local result = ZLogs.Query(clean)
    sendPage(ply, result, reqId)
end)

-- ============================================
-- CLIENT → SERVER: запрос открыть меню
-- ============================================

net.Receive("zlogs_open_request", function(len, ply)
    if not IsValid(ply) then return end
    if not ZLogs.CanView(ply) then
        ply:ChatPrint("[Логи] Доступ запрещён")
        return
    end
    net.Start("zlogs_open_request")
    net.Send(ply)
end)

-- ============================================
-- CLIENT → SERVER: очистка логов (super-admin only)
-- ============================================

net.Receive("zlogs_clear", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local cat = net.ReadString()
    if cat == "" then cat = nil end
    ZLogs.Clear(cat)
    ply:ChatPrint("[Логи] Очищено: " .. (cat or "всё"))
end)

-- ============================================
-- LIVE BROADCAST (опционально)
-- ============================================
-- Кто хочет live — выставляет ply.ZLogsLive = true (через концоман или меню)

hook.Add("ZLogs.OnAdd", "zlogs_live_broadcast", function(cat, sid, nick, text, data, ts)
    local listeners = {}
    for _, p in ipairs(player.GetAll()) do
        if p.ZLogsLive and ZLogs.CanView(p) then
            table.insert(listeners, p)
        end
    end
    if #listeners == 0 then return end

    -- Маленький payload — только текст + метка времени + категория
    local payload = util.TableToJSON({
        cat  = cat,
        sid  = sid,
        nick = nick,
        text = text,
        ts   = ts,
    })
    local compressed = util.Compress(payload)
    local len = #compressed
    if len > 30000 then return end

    net.Start("zlogs_live")
    net.WriteUInt(len, 24)
    net.WriteData(compressed, len)
    net.Send(listeners)
end)

MsgN("[ZLogs] Net-протокол готов")
