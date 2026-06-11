-- Discord Logger для Z-City сервера (РАБОЧАЯ ВЕРСИЯ)
-- ================= НАСТРОЙКИ =================
local CONFIG = {
    connect = { enabled = true, webhook = "УКАЖИТЕ_WEBHOOK_URL" },
    spawn   = { enabled = true, webhook = "УКАЖИТЕ_WEBHOOK_URL" },
    punish  = { enabled = true, webhook = "УКАЖИТЕ_WEBHOOK_URL" },
    cmenu   = { enabled = true, webhook = "УКАЖИТЕ_WEBHOOK_URL" },
    money   = { enabled = true, webhook = "УКАЖИТЕ_WEBHOOK_URL" },
    ranks   = { enabled = true, webhook = "УКАЖИТЕ_WEBHOOK_URL" },
    global_enabled = true,
    debug = true
}
-- ==============================================

if not SERVER then return end

local function GetWebhookURL(t)
    local c = CONFIG[t]
    return (c and c.enabled) and c.webhook or ""
end

local function IsEnabled()
    return CONFIG.global_enabled ~= false
end

-- v8.1: raw JSON через HTTP() вместо http.Post(payload_json). Через прокси
-- (Discord заблочен РКН → webhook.lewisakura.moe) form-вариант не доходит:
-- прокси/Discord отдаёт 4xx, а http.Post коды ошибок не ловит → молча «успех»
-- и в канал ничего. raw-JSON через HTTP() доставляется (как ac_webhook_test → 204).
local function SendDiscordMessage(webhookURL, title, message)
    if not webhookURL or webhookURL == "" or not IsEnabled() then return end
    local payload = util.TableToJSON({
        content = "**" .. title .. ":** " .. message,
        allowed_mentions = { parse = {} }
    })
    HTTP({
        url     = webhookURL,
        method  = "POST",
        type    = "application/json",
        body    = payload,
        success = function(code)
            if CONFIG.debug and code and (code < 200 or code >= 300) then
                print("[DISCORD ERROR] HTTP " .. tostring(code))
            end
        end,
        failed  = function(err)
            if CONFIG.debug then print("[DISCORD ERROR] " .. (err or "Unknown")) end
        end,
    })
end

-- ============================================================================
-- Кэш ник↔SteamID
-- ----------------------------------------------------------------------------
-- ULib hadduser/adduserid передают цель как $<account_id> и НЕ сохраняют ник
-- (ULib.ucl.users[sid].name = nil для свежих записей). Когда такой игрок
-- оффлайн, в Discord-логе оставался сырой "$599335769" вместо ника.
-- Поэтому ведём свой персистентный кэш SteamID → ник, обновляемый при входе.
-- ============================================================================

local NAME_CACHE_FILE = "zcity_name_cache.txt"
local _nameCache = {}        -- ["STEAM_0:x:y"] = "Ник"
local _nameCacheDirty = false

local function LoadNameCache()
    if not file.Exists(NAME_CACHE_FILE, "DATA") then return end
    local raw = file.Read(NAME_CACHE_FILE, "DATA")
    if not raw or raw == "" then return end
    local tbl = util.JSONToTable(raw)
    if type(tbl) == "table" then
        _nameCache = tbl
        if CONFIG.debug then
            local n = 0
            for _ in pairs(_nameCache) do n = n + 1 end
            print("[DISCORD LOG] Загружен кэш ников: " .. n .. " записей")
        end
    end
end

local function SaveNameCache()
    if not _nameCacheDirty then return end
    _nameCacheDirty = false
    local ok, json = pcall(util.TableToJSON, _nameCache)
    if ok and json then
        file.Write(NAME_CACHE_FILE, json)
    end
end

local function RememberName(sid, nick)
    if not sid or sid == "" or not nick or nick == "" then return end
    sid = sid:upper()
    if _nameCache[sid] == nick then return end
    _nameCache[sid] = nick
    _nameCacheDirty = true
end

LoadNameCache()
-- Дебаунс записи на диск (не чаще раза в 10 сек)
timer.Create("DL_NameCacheFlush", 10, 0, SaveNameCache)
-- На случай хотрелоада: запомним всех, кто уже на сервере
for _, p in ipairs(player.GetAll()) do
    if IsValid(p) and p.SteamID then RememberName(p:SteamID(), p:Name()) end
end

-- ULib передаёт цель как $<account_id>, где account_id = SteamID64 - 76561197960265728.
-- Эта функция конвертирует account_id (или полный SteamID64) в STEAM_0:z:y.
local function ULibArgToSteamID(numStr)
    local id = tonumber(numStr)
    if not id then return nil end
    local accId = id > 76561197960265728 and (id - 76561197960265728) or id
    local y = math.floor(accId / 2)
    local z = accId % 2
    return "STEAM_0:" .. z .. ":" .. y
end

-- Ищет игрока онлайн по аргументу ULib (ник, SteamID, $account_id).
-- Возвращает name, steamid (строки). Никогда не возвращает сырой "$account_id"
-- в качестве имени — если ник неизвестен, используется "Неизвестный".
local function ResolveTarget(targetArg)
    targetArg = tostring(targetArg or "")
    local tname, tsid = nil, nil
    local isULibId = targetArg:sub(1, 1) == "$"
    local fullSid64 = nil
    if isULibId then
        local accId = tonumber(targetArg:sub(2))
        if accId then
            fullSid64 = tostring(76561197960265728 + accId)
        end
    end

    -- 1) Онлайн-игрок: самый достоверный источник.
    -- ULib.getUniqueIDForPlayer() возвращает Player:UniqueID() (CRC-хэш),
    -- а НЕ account_id, поэтому отдельно сравниваем по UniqueID/UserID,
    -- иначе ULibArgToSteamID превратит UniqueID в левый STEAM_0:x:y.
    local ulibIdStr = isULibId and targetArg:sub(2) or nil
    for _, p in ipairs(player.GetAll()) do
        local matched = false
        if string.lower(p:Name()) == string.lower(targetArg) then
            matched = true
        elseif p:SteamID() == targetArg then
            matched = true
        elseif fullSid64 and p:SteamID64() == fullSid64 then
            matched = true
        elseif ulibIdStr and (
                tostring(p:UniqueID()) == ulibIdStr
             or tostring(p:UserID())   == ulibIdStr
             or p:SteamID64()          == ulibIdStr
        ) then
            matched = true
        end
        if matched then
            tname = p:Name()
            tsid  = p:SteamID()
            RememberName(tsid, tname)
            return tname, tsid
        end
    end

    -- 2) Оффлайн: определяем SteamID из аргумента
    if isULibId then
        -- Если $<id> — это UniqueID оффлайн-игрока, пробуем найти его в ULib.ucl.users
        if ULib and ULib.ucl and ULib.ucl.users then
            for sid, info in pairs(ULib.ucl.users) do
                if util and util.CRC and tostring(util.CRC(sid)) == ulibIdStr then
                    tsid = sid
                    if info.name and info.name ~= "" then tname = info.name end
                    break
                end
            end
        end
        if not tsid then
            local converted = ULibArgToSteamID(targetArg:sub(2))
            if converted then tsid = converted end
        end
    elseif targetArg:find("^STEAM_") then
        tsid = targetArg
    elseif targetArg:match("^%d+$") then
        -- Голое число (SteamID64 или account_id) без префикса $
        local converted = ULibArgToSteamID(targetArg)
        if converted then tsid = converted end
    end

    -- 3) Имя: пробуем наш персистентный кэш, потом базу ULib, потом ULib.bans
    if tsid then
        local sidUp = tsid:upper()
        if _nameCache[sidUp] then
            tname = _nameCache[sidUp]
        elseif ULib and ULib.ucl and ULib.ucl.users and ULib.ucl.users[sidUp]
               and ULib.ucl.users[sidUp].name and ULib.ucl.users[sidUp].name ~= "" then
            tname = ULib.ucl.users[sidUp].name
        elseif ULib and ULib.bans and ULib.bans[sidUp]
               and ULib.bans[sidUp].name and ULib.bans[sidUp].name ~= "" then
            tname = ULib.bans[sidUp].name
        end
    elseif not targetArg:match("^[%$%d]") then
        -- targetArg — это сам ник (никакой ID, никакой $accId).
        -- Игрок оффлайн, SteamID мы не знаем — используем ник как есть.
        tname = targetArg
    end

    if not tname or tname == "" then tname = "Неизвестный" end
    if not tsid  or tsid  == "" then tsid  = "?" end
    return tname, tsid
end

-- Форматирование игрока: "Ник (STEAM_0:x:y)"
local function FmtPlayer(name, sid)
    return tostring(name or "Неизвестный") .. " (" .. tostring(sid or "?") .. ")"
end

-- ============================================================================
-- Async-резолв ника через публичный Steam XML-профиль
-- ----------------------------------------------------------------------------
-- Когда админ банит/кикает игрока, который НИКОГДА не заходил на этот сервер
-- (offline-ban по STEAM_0:x:y из XGUI), наш локальный _nameCache пуст и в
-- ULib.bans записи ещё нет. Тогда обращаемся напрямую к Steam:
--   https://steamcommunity.com/profiles/<sid64>/?xml=1
-- Берём <steamID>...</steamID> — это текущий ник в Steam. Без API-ключа.
-- ============================================================================

local _steamFetchInProgress = {}  -- sid64 → true, защита от дублирующих запросов

local function FetchSteamNameAsync(sid32, sid64, callback)
    if not sid64 or sid64 == "" or sid64 == "0" then
        callback(nil); return
    end
    if _steamFetchInProgress[sid64] then
        -- Уже летит другой запрос — ждать его смысла нет, шлём как есть
        callback(nil); return
    end
    _steamFetchInProgress[sid64] = true

    local url = "https://steamcommunity.com/profiles/" .. sid64 .. "/?xml=1"
    http.Fetch(url, function(body, _, _, code)
        _steamFetchInProgress[sid64] = nil
        if not body or code ~= 200 then callback(nil); return end
        -- <steamID><![CDATA[Ник]]></steamID>  ИЛИ  <steamID>Ник</steamID>
        local nick = body:match("<steamID>%s*<!%[CDATA%[(.-)%]%]>%s*</steamID>")
                  or body:match("<steamID>(.-)</steamID>")
        if nick and nick ~= "" then
            if sid32 and sid32 ~= "?" then RememberName(sid32, nick) end
            callback(nick)
        else
            callback(nil)
        end
    end, function()
        _steamFetchInProgress[sid64] = nil
        callback(nil)
    end)
end

-- Резолв с fallback на Steam Web. Callback(tname, tsid).
local function ResolveTargetAsync(targetArg, callback)
    local tname, tsid = ResolveTarget(targetArg)
    if tname ~= "Неизвестный" or not tsid or tsid == "?" then
        callback(tname, tsid); return
    end

    -- Имя не нашли локально — попробуем Steam Web
    local sid64 = pcall(util.SteamIDTo64, tsid) and util.SteamIDTo64(tsid) or nil
    if not sid64 or sid64 == "0" or sid64 == "" then
        callback(tname, tsid); return
    end

    -- Тайм-аут защитный: если Steam не ответит за 4 сек — шлём как есть.
    local fired = false
    local function finish(name)
        if fired then return end
        fired = true
        callback(name or "Неизвестный", tsid)
    end
    timer.Simple(4, function() finish(nil) end)
    FetchSteamNameAsync(tsid, sid64, function(name) finish(name) end)
end

-- Запоминаем ник игрока при подключении (обновим кэш для будущих логов)
hook.Add("PlayerAuthed", "DL_RememberName_Authed", function(ply, steamid, _)
    if IsValid(ply) and steamid then
        RememberName(steamid, ply:Name())
    end
end)

hook.Add("PlayerInitialSpawn", "DL_RememberName_Spawn", function(ply)
    if IsValid(ply) and ply.SteamID then
        RememberName(ply:SteamID(), ply:Name())
    end
end)

-- На случай смены ника через стим за время сессии
hook.Add("PlayerDisconnected", "DL_RememberName_Leave", function(ply)
    if IsValid(ply) and ply.SteamID then
        RememberName(ply:SteamID(), ply:Name())
        SaveNameCache()
    end
end)

-- Сохраняем кэш при выключении сервера
hook.Add("ShutDown", "DL_RememberName_Shutdown", function()
    _nameCacheDirty = true
    SaveNameCache()
end)

-- Список оружия для игнора (стандартное GMod оружие)
local ignoredWeapons = { "weapon_hands", "gmod_camera" }

-- =============== ОРУЖИЕ (ВЗЯЛ СЕБЕ ЧЕРЕЗ СПАВН-МЕНЮ) ===============
hook.Add("PlayerGiveSWEP", "DL_GiveSWEP", function(ply, weaponClass, swepTable)
    if not IsValid(ply) then return end
    for _, ignored in ipairs(ignoredWeapons) do
        if weaponClass == ignored then return end
    end
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        SendDiscordMessage(GetWebhookURL("spawn"), "Взял оружие (спавн-меню)",
            FmtPlayer(ply:Name(), ply:SteamID()) .. " взял \"" .. weaponClass .. "\"")
        if CONFIG.debug then
            print("[DISCORD LOG] 🔫 Спавн-меню: " .. ply:Name() .. " взял " .. weaponClass)
        end
    end)
end, HOOK_HIGH)

-- =============== МАШИНЫ ===============
hook.Add("PlayerSpawnedVehicle", "DL_Vehicle", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    SendDiscordMessage(GetWebhookURL("spawn"), "Заспавнил машину",
        FmtPlayer(ply:Name(), ply:SteamID()) .. " заспавнил машину: " .. ent:GetClass())
    if CONFIG.debug then
        print("[DISCORD LOG] 🚗 Машина: " .. ply:Name() .. " заспавнил " .. ent:GetClass())
    end
end)

-- =============== NPC ===============
hook.Add("PlayerSpawnedNPC", "DL_NPC", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    SendDiscordMessage(GetWebhookURL("spawn"), "Заспавнил NPC",
        FmtPlayer(ply:Name(), ply:SteamID()) .. " заспавнил NPC: " .. ent:GetClass())
    if CONFIG.debug then
        print("[DISCORD LOG] 👾 NPC: " .. ply:Name() .. " заспавнил " .. ent:GetClass())
    end
end)

-- =============== SENT ===============
hook.Add("PlayerSpawnedSENT", "DL_SENT", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    SendDiscordMessage(GetWebhookURL("spawn"), "Заспавнил SENT",
        FmtPlayer(ply:Name(), ply:SteamID()) .. " заспавнил SENT: " .. ent:GetClass())
    if CONFIG.debug then
        print("[DISCORD LOG] 🤖 SENT: " .. ply:Name() .. " заспавнил " .. ent:GetClass())
    end
end)

-- =============== ЭФФЕКТЫ ===============
hook.Add("PlayerSpawnedEffect", "DL_Effect", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    SendDiscordMessage(GetWebhookURL("spawn"), "Заспавнил эффект",
        FmtPlayer(ply:Name(), ply:SteamID()) .. " заспавнил эффект: " .. ent:GetClass())
    if CONFIG.debug then
        print("[DISCORD LOG] ✨ Эффект: " .. ply:Name() .. " заспавнил " .. ent:GetClass())
    end
end)

-- =============== RAGDOLL ===============
hook.Add("PlayerSpawnedRagdoll", "DL_Ragdoll", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    SendDiscordMessage(GetWebhookURL("spawn"), "Заспавнил Ragdoll",
        FmtPlayer(ply:Name(), ply:SteamID()) .. " заспавнил ragdoll: " .. ent:GetClass())
    if CONFIG.debug then
        print("[DISCORD LOG] 💀 Ragdoll: " .. ply:Name() .. " заспавнил " .. ent:GetClass())
    end
end)

-- =============== ПОДКЛЮЧЕНИЯ ===============
hook.Add("PlayerInitialSpawn", "DL_Connect", function(ply)
    if not IsValid(ply) then return end
    SendDiscordMessage(GetWebhookURL("connect"), "Вход",
        FmtPlayer(ply:Name(), ply:SteamID()) .. " подключился")
    if CONFIG.debug then print("[DISCORD LOG] ✅ Игрок подключился: " .. ply:Name()) end
end)

hook.Add("PlayerDisconnected", "DL_Disconnect", function(ply)
    if not IsValid(ply) then return end
    SendDiscordMessage(GetWebhookURL("connect"), "Выход",
        FmtPlayer(ply:Name(), ply:SteamID()) .. " отключился")
    if CONFIG.debug then print("[DISCORD LOG] ❌ Игрок отключился: " .. ply:Name()) end
end)

-- =============== НАКАЗАНИЯ ULX ===============
local punishCommands = {
    ["ulx kick"]     = { "Кик",          "👢" },
    ["ulx ban"]      = { "Бан",          "🔨" },
    ["ulx banid"]    = { "Бан (ID)",     "🔨" },
    ["ulx unban"]    = { "Разбан",       "♻"  },
    ["ulx mute"]     = { "Мут",          "🔇" },
    ["ulx unmute"]   = { "Размут",       "🔊" },
    ["ulx gag"]      = { "Гаг",          "🤐" },
    ["ulx ungag"]    = { "Разгаг",       "🗣"  },
    ["ulx jail"]     = { "Тюрьма",       "🔒" },
    ["ulx unjail"]   = { "Освобождение", "🔓" },
    ["ulx freeze"]   = { "Заморозка",    "🧊" },
    ["ulx unfreeze"] = { "Разморозка",   "🔥" },
    ["ulx slay"]     = { "Слэй",         "💀" },
    ["ulx kickid"]   = { "Кик (ID)",     "👢" },
}

hook.Add("ULibCommandCalled", "DL_ULXPunish", function(ply, command, argv)
    local info = punishCommands[string.lower(command or "")]
    if not info then return end

    local label, emoji = info[1], info[2]
    -- Снимок данных АДМИНА и аргументов СРАЗУ, пока ply ещё валиден и команда
    -- ещё не выполнилась (этот хук вызывается до cmdTable.__fn в ULib).
    local aname = IsValid(ply) and ply:Name() or "Console"
    local asid  = IsValid(ply) and ply:SteamID() or "CONSOLE"

    local targetArg = argv and argv[1] or "?"

    local rest = ""
    if argv then
        local parts = {}
        for i = 2, #argv do parts[#parts + 1] = tostring(argv[i]) end
        rest = table.concat(parts, " ")
    end

    -- Async-резолв: пробуем локальные источники, при провале — Steam XML.
    -- SendDiscordMessage уезжает в callback, чтобы лог уже содержал ник.
    ResolveTargetAsync(targetArg, function(tname, tsid)
        local msg = FmtPlayer(aname, asid) .. " -> " .. label .. " -> " ..
                    FmtPlayer(tname, tsid) ..
                    (rest ~= "" and (" | " .. rest) or "")

        SendDiscordMessage(GetWebhookURL("punish"), label, msg)

        if CONFIG.debug then
            print("[DISCORD LOG] " .. emoji .. " " .. label .. ": " .. aname .. " -> " .. tname)
            print("[DISCORD LOG] argv: " .. (argv and table.concat(argv, ", ") or "nil"))
        end
    end)
end, HOOK_HIGH)

print("[DISCORD LOG] ULX хуки наказаний загружены")

-- =============== РАНГИ ULX ===============
local rankCommands = {
    ["ulx adduser"]      = { "Выдача ранга",      "🎖", "give"   },
    ["ulx adduserid"]    = { "Выдача ранга (ID)", "🎖", "give"   },
    ["ulx removeuser"]   = { "Снятие ранга",      "🚫", "remove" },
    ["ulx removeuserid"] = { "Снятие ранга (ID)", "🚫", "remove" },
}

hook.Add("ULibCommandCalled", "DL_ULXRanks", function(ply, command, argv)
    local info = rankCommands[string.lower(command or "")]
    if not info then return end

    local label, emoji, mode = info[1], info[2], info[3]
    local aname = IsValid(ply) and ply:Name() or "Console"
    local asid  = IsValid(ply) and ply:SteamID() or "CONSOLE"

    local targetArg = argv and argv[1] or "?"
    local groupArg = (mode == "give") and (argv and argv[2] or "?") or nil
    local groupStr = groupArg and (" | Ранг: " .. groupArg) or ""

    ResolveTargetAsync(targetArg, function(tname, tsid)
        local msg = FmtPlayer(aname, asid) .. " -> " .. label .. " -> " ..
                    FmtPlayer(tname, tsid) .. groupStr

        SendDiscordMessage(GetWebhookURL("ranks"), label, msg)

        if CONFIG.debug then
            print("[DISCORD LOG] " .. emoji .. " " .. label .. ": " .. aname .. " -> " .. tname .. groupStr)
        end
    end)
end, HOOK_HIGH)

print("[DISCORD LOG] ULX ранги загружены")

-- =============== C-MENU (Context Menu) LOGGING ===============
local cmenuActions = {
    ["notify"]               = { label = "Уведомление",         emoji = "📢" },
    ["givegun"]              = { label = "Выдать оружие",       emoji = "🔫" },
    ["strip"]                = { label = "Забрать оружие",      emoji = "🗑" },
    ["fullstrip"]            = { label = "Полный стрип",         emoji = "🗑🗑" },
    ["reset_org"]            = { label = "Сброс организма",     emoji = "❤️" },
    ["freeze"]               = { label = "Заморозка",            emoji = "🧊" },
    ["snatch"]               = { label = "Схватить",             emoji = "👻" },
    ["ragdollize"]           = { label = "Оглушить/Поднять",    emoji = "💫" },
    ["vomit"]                = { label = "Вызвать рвоту",        emoji = "🤮" },
    ["lobotomize"]           = { label = "Лоботомия",            emoji = "🧠" },
    ["killsilent"]           = { label = "Убить (тихо)",         emoji = "💀" },
    ["removeply"]            = { label = "Удалить игрока",       emoji = "❌" },
    ["setplayerclass"]       = { label = "Сменить класс",        emoji = "👤" },
    ["break_limb"]           = { label = "Сломать конечность",   emoji = "🦴" },
    ["amputate_limb"]        = { label = "Ампутировать",         emoji = "🔪" },
    ["door_toggle"]          = { label = "Переключить дверь",   emoji = "🚪" },
    ["door_lock"]            = { label = "Заблокировать дверь", emoji = "🔒" },
    ["door_unlock"]          = { label = "Разблокировать дверь", emoji = "🔓" },
    ["respawn_ply_in_rag"]   = { label = "Респавн игрока",       emoji = "🔄" },
    ["respawn_lply_in_rag"]  = { label = "Вселиться в тело",     emoji = "👻" },
    ["respawn_ragply_in_rag"] = { label = "Респавн владельца",   emoji = "🔄" },
    ["ignite"]               = { label = "Поджечь",              emoji = "🔥" },
    ["extinguish"]           = { label = "Потушить",             emoji = "💧" },
    ["gravity_on"]           = { label = "Гравитация ВКЛ",       emoji = "⬇️" },
    ["gravity_off"]          = { label = "Гравитация ВЫКЛ",      emoji = "⬆️" },
}

local breakLimbNames    = { "Шея", "Левая рука", "Правая рука", "Левая нога", "Правая нога", "Спина 1", "Спина 2", "Спина 3" }
local amputateLimbNames = { "Голова", "Левая рука", "Правая рука", "Левая нога", "Правая нога" }

hook.Add("HG_CMenuAction", "DL_CMenuLogger", function(ply, actionName, ent, extra)
    local info = cmenuActions[actionName]
    if not info then return end

    local aname = IsValid(ply) and ply:Name() or "Console"
    local asid  = IsValid(ply) and ply:SteamID() or "CONSOLE"

    local tname, tsid = "Unknown", "?"
    if IsValid(ent) then
        if ent:IsPlayer() then
            tname = ent:Name()
            tsid  = ent:SteamID()
        else
            tname = ent:GetClass()
            tsid  = ent:GetClass()
        end
    end

    local extraStr = ""
    if extra and extra ~= "" then
        if actionName == "givegun" or actionName == "notify" then
            extraStr = " | " .. extra
        elseif actionName == "setplayerclass" then
            extraStr = " | Класс: " .. extra
        elseif actionName == "break_limb" then
            local limbId = tonumber(extra)
            if limbId then extraStr = " | " .. (breakLimbNames[limbId + 1] or "Неизвестно") end
        elseif actionName == "amputate_limb" then
            local limbId = tonumber(extra)
            if limbId then extraStr = " | " .. (amputateLimbNames[limbId + 1] or "Неизвестно") end
        else
            extraStr = " | " .. extra
        end
    end

    local msg = FmtPlayer(aname, asid) .. " -> " .. info.label .. " -> " ..
                FmtPlayer(tname, tsid) .. extraStr

    SendDiscordMessage(GetWebhookURL("cmenu"), info.label, msg)

    if CONFIG.debug then
        print("[DISCORD LOG] " .. info.emoji .. " C-Menu " .. info.label .. ": " .. aname .. " -> " .. tname .. extraStr)
    end
end)

print("[DISCORD LOG] C-Menu логирование загружено")
print("[DISCORD LOG] Загружен!")

-- =============== ДЕНЬГИ (sv_roleplay) ===============
hook.Add("RoleplayMoneyChange", "DL_MoneyLogger", function(ply, amount, reason, targetPly)
    if not IsValid(ply) then return end
    if reason ~= "admin_give" then return end

    local pname = ply:Name()
    local psid  = ply:SteamID()
    local amountStr = string.format("$%s", string.Comma(amount))
    local aname = IsValid(targetPly) and targetPly:Name() or "Console"
    local asid  = IsValid(targetPly) and targetPly:SteamID() or "CONSOLE"

    local title = "Выдача денег (Админ)"
    local msg = FmtPlayer(aname, asid) .. " выдал " .. amountStr .. " игроку " .. FmtPlayer(pname, psid)

    SendDiscordMessage(GetWebhookURL("money"), title, msg)

    if CONFIG.debug then
        print("[DISCORD LOG] 💰 " .. title .. ": " .. msg)
    end
end)

print("[DISCORD LOG] Логирование денег загружено")
