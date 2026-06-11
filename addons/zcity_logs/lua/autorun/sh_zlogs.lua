--[[
    ZCity Logs — единая система логирования RP-сервера.
    Shared-часть: namespace, категории, цвета, общие утилиты.
]]

ZLogs = ZLogs or {}
ZLogs.VERSION = "1.0.0"

-- Цвета категорий (используются и в чате, и в UI)
ZLogs.Categories = {
    ["chat"]    = { name = "Чат",           color = Color(140, 180, 220) },
    ["kill"]    = { name = "Убийства",      color = Color(220,  80,  80) },
    ["damage"]  = { name = "Урон",          color = Color(200, 140,  80) },
    ["money"]   = { name = "Экономика",     color = Color(100, 220, 140) },
    ["job"]     = { name = "Работы",        color = Color(150, 150, 255) },
    ["city"]    = { name = "Мэрия",         color = Color(255, 200,  80) },
    ["war"]     = { name = "Война / КЧ",    color = Color(255,  90,  90) },
    ["rob"]     = { name = "Ограбления",    color = Color(200,  80, 200) },
    ["door"]    = { name = "Двери",         color = Color(180, 140, 100) },
    ["weapon"]  = { name = "Оружие",        color = Color(220, 100, 100) },
    ["admin"]   = { name = "Админ",         color = Color(255, 255, 255) },
    ["connect"] = { name = "Подключения",   color = Color(120, 200, 200) },
    ["system"]  = { name = "Система",       color = Color(180, 180, 180) },
}

-- Порядок отображения в UI (слева направо / сверху вниз)
ZLogs.CategoryOrder = {
    "kill", "damage", "money", "rob", "war", "city",
    "job", "door", "weapon", "chat", "admin", "connect", "system"
}

-- Общая палитра темы — тёмная / жёсткая
ZLogs.Theme = {
    BgDeep      = Color(9,  9,  12, 255),      -- почти чёрный фон
    BgPanel     = Color(15, 15, 20, 255),      -- тёмная панель
    BgRow       = Color(19, 19, 26, 210),      -- строка таблицы
    BgRowAlt    = Color(14, 14, 20, 210),      -- альт-строка
    BgRowHover  = Color(45, 22, 18, 230),      -- ховер — тёплый тёмно-красный
    Header      = Color(14, 12, 12, 255),      -- почти чёрный заголовок
    HeaderText  = Color(220, 215, 210),        -- приглушённый белый
    Accent      = Color(170, 55, 55),          -- жёсткий красный акцент
    AccentSoft  = Color(80,  30, 30),          -- тихий красный
    Border      = Color(48,  48, 58, 210),     -- нейтральная серая рамка
    Text        = Color(215, 215, 222),        -- основной текст
    TextDim     = Color(115, 115, 135),        -- приглушённый
    TextTime    = Color(95,  100, 120),        -- метка времени
    Success     = Color(75,  170, 100),        -- зелёный
    Error       = Color(190, 65,  55),         -- красный ошибка
    Warn        = Color(200, 155, 45),         -- жёлтый предупреждение
}

-- Лимиты
ZLogs.MAX_TEXT_LEN     = 512    -- макс. длина текста лога
ZLogs.PAGE_SIZE        = 100    -- логов на страницу
ZLogs.RETENTION_DAYS   = 30     -- ротация: удалять старше N дней
ZLogs.DAMAGE_FLUSH_SEC = 5      -- группировка damage логов (защита от спама)

-- Утилита: формирование красивой временной метки
function ZLogs.FormatTime(ts)
    return os.date("%H:%M:%S %d.%m.%Y", ts or os.time())
end

-- Утилита: безопасное укорачивание строки
function ZLogs.Truncate(str, maxLen)
    if not str then return "" end
    str = tostring(str)
    maxLen = maxLen or ZLogs.MAX_TEXT_LEN
    if #str > maxLen then
        return string.sub(str, 1, maxLen - 3) .. "..."
    end
    return str
end

-- Утилита: безопасный SteamID
function ZLogs.SafeSID(ply)
    if type(ply) == "string" then return ply end
    if not IsValid(ply) or not ply.SteamID then return "" end
    return ply:SteamID() or ""
end

-- Утилита: SteamID64 из обычного SteamID (для ссылок на профиль)
function ZLogs.SID64(sid)
    if not sid or sid == "" then return "" end
    if util and util.SteamIDTo64 then
        local ok, sid64 = pcall(util.SteamIDTo64, sid)
        if ok and sid64 then return sid64 end
    end
    return ""
end

-- Утилита: безопасный ник
function ZLogs.SafeNick(ply)
    if type(ply) == "string" then return ply end
    if not IsValid(ply) or not ply.Nick then return "Консоль" end
    return ply:Nick() or "?"
end
