--[[---------------------------------------------------------------------------
ZCity RP — RP-команды через HG_PlayerSay (работает с ZChat)
---------------------------------------------------------------------------
DarkRP определяет /me /y /w /pm /ooc через PlayerSay, но ZChat перехватывает
PlayerSay раньше через return "" — DarkRP-хуки не доходят.
Здесь все команды реализованы через HG_PlayerSay (именно на него вешает ZChat).

Команды:
  /me  <текст>          — действие (видно рядом, meDistance)
  /do  <текст>          — описание действия [Имя]
  /it  <текст>          — то же что /do
  /roll [макс]          — бросок кубика
  /y   <текст>          — крик (yellDistance, большой радиус)
  /w   <ник> <текст>    — шёпот (только отправитель + цель)
  /ooc <текст>          — внеигровой (всем)
  /b   <текст>          — то же что /ooc
  /pm  <ник> <текст>    — личное сообщение

Формат пакета: net "zcity_rp_cmd" → UInt(type,4) + String(nick) + Color(team) + String(text)
---------------------------------------------------------------------------]]
if not SERVER then return end

util.AddNetworkString("zcity_rp_cmd")

local ME_DIST     = (GM and GM.Config and GM.Config.meDistance)     or 250
local YELL_DIST   = (GM and GM.Config and GM.Config.yellDistance)   or 650
local WHISP_DIST  = (GM and GM.Config and GM.Config.whisperDistance) or 100

local TYPE = { ME=1, DO=2, ROLL=3, YELL=4, WHISPER=5, OOC=6, PM=7 }

local function nearby(ply, dist)
    local sqr = dist * dist
    local pos = ply:GetPos()
    local t = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:GetPos():DistToSqr(pos) <= sqr then
            t[#t+1] = p
        end
    end
    return t
end

local function send(recipients, msgType, nick, color, text)
    net.Start("zcity_rp_cmd")
        net.WriteUInt(msgType, 4)
        net.WriteString(nick or "")
        net.WriteColor(color or color_white)
        net.WriteString(text or "")
    net.Send(recipients)
end

local function findPlayer(searcher, query)
    if not isstring(query) or query == "" then return nil end
    local q = query:lower()
    -- точное совпадение SteamID
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == query then return p end
    end
    -- частичное по нику
    for _, p in ipairs(player.GetAll()) do
        if string.find(p:Nick():lower(), q, 1, true) then return p end
    end
    return nil
end

hook.Add("HG_PlayerSay", "zcity_rp_commands", function(ply, txtTbl, text)
    if not IsValid(ply) or not isstring(text) then return end
    if string.sub(text, 1, 1) ~= "/" then return end

    local cmd, args = text:match("^(/[%S]+)%s*(.*)")
    if not cmd then return end
    cmd = cmd:lower()

    local nick  = ply:Nick()
    local col   = team.GetColor(ply:Team())

    -- /me
    if cmd == "/me" then
        if args == "" then
            ply:ChatPrint("[RP] /me <действие>")
            txtTbl[1] = ""
            return
        end
        txtTbl[1] = ""
        send(nearby(ply, ME_DIST), TYPE.ME, nick, col, args)
        return
    end

    -- /do /it
    if cmd == "/do" or cmd == "/it" then
        if args == "" then
            ply:ChatPrint("[RP] /do <описание>")
            txtTbl[1] = ""
            return
        end
        txtTbl[1] = ""
        send(nearby(ply, ME_DIST), TYPE.DO, nick, col, args)
        return
    end

    -- /roll [макс]
    if cmd == "/roll" then
        txtTbl[1] = ""
        local maxVal = tonumber(args) or 100
        maxVal = math.Clamp(math.floor(maxVal), 2, 1000000)
        local result = math.random(1, maxVal)
        send(nearby(ply, ME_DIST), TYPE.ROLL, nick, col,
            result .. (maxVal ~= 100 and ("/" .. maxVal) or ""))
        return
    end

    -- /y (крик)
    if cmd == "/y" then
        if args == "" then
            ply:ChatPrint("[RP] /y <текст>")
            txtTbl[1] = ""
            return
        end
        txtTbl[1] = ""
        send(nearby(ply, YELL_DIST), TYPE.YELL, nick, col, args)
        return
    end

    -- /w <ник> <текст>
    if cmd == "/w" then
        local targetStr, msg = args:match("^([^%s]+)%s+(.*)")
        if not targetStr or not msg or msg == "" then
            ply:ChatPrint("[RP] /w <игрок> <текст>")
            txtTbl[1] = ""
            return
        end
        local target = findPlayer(ply, targetStr)
        if not IsValid(target) then
            ply:ChatPrint("[RP] Игрок не найден: " .. targetStr)
            txtTbl[1] = ""
            return
        end
        if target == ply then
            ply:ChatPrint("[RP] Нельзя шептать себе")
            txtTbl[1] = ""
            return
        end
        txtTbl[1] = ""
        send({ply, target}, TYPE.WHISPER, nick, col, msg)
        return
    end

    -- /ooc /b
    if cmd == "/ooc" or cmd == "/b" then
        if args == "" then
            ply:ChatPrint("[RP] /ooc <текст>")
            txtTbl[1] = ""
            return
        end
        txtTbl[1] = ""
        send(player.GetAll(), TYPE.OOC, nick, col, args)
        return
    end

    -- /pm <ник> <текст>
    if cmd == "/pm" then
        local targetStr, msg = args:match("^([^%s]+)%s+(.*)")
        if not targetStr or not msg or msg == "" then
            ply:ChatPrint("[RP] /pm <игрок> <текст>")
            txtTbl[1] = ""
            return
        end
        local target = findPlayer(ply, targetStr)
        if not IsValid(target) then
            ply:ChatPrint("[RP] Игрок не найден: " .. targetStr)
            txtTbl[1] = ""
            return
        end
        txtTbl[1] = ""
        send({ply, target}, TYPE.PM, nick, col, msg)
        return
    end
end)

print("[ZCity RP] RP-команды загружены (/me /do /it /roll /y /w /ooc /b /pm)")
