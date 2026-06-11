--[[---------------------------------------------------------------------------
ZCity RP — клиентская отрисовка RP-команд
---------------------------------------------------------------------------]]
if not CLIENT then return end

local TYPE = { ME=1, DO=2, ROLL=3, YELL=4, WHISPER=5, OOC=6, PM=7 }

local C_STAR   = Color(255, 220, 100)  -- звёздочка /me
local C_DO     = Color(180, 220, 255)  -- /do текст
local C_ROLL   = Color(100, 255, 160)  -- /roll
local C_YELL   = Color(255, 100,  80)  -- /y
local C_WHSP   = Color(140, 240, 140)  -- /w
local C_OOC    = Color(180, 180, 180)  -- /ooc
local C_PM     = Color(140, 210, 255)  -- /pm
local C_GRAY   = Color(160, 160, 160)
local C_WHITE  = color_white

net.Receive("zcity_rp_cmd", function()
    local msgType = net.ReadUInt(4)
    local nick    = net.ReadString()
    local col     = net.ReadColor()
    local text    = net.ReadString()

    if msgType == TYPE.ME then
        -- ★ Имя действие
        chat.AddText(C_STAR, "★ ", col, nick, C_WHITE, " " .. text)

    elseif msgType == TYPE.DO then
        -- ✦ текст [Имя]
        chat.AddText(C_DO, "✦ ", C_WHITE, text, C_GRAY, " [" .. nick .. "]")

    elseif msgType == TYPE.ROLL then
        -- 🎲 Имя бросает кубик: X/100
        chat.AddText(C_ROLL, "🎲 ", col, nick, C_WHITE, " бросает кубик: ", C_ROLL, text)

    elseif msgType == TYPE.YELL then
        -- Имя кричит: "текст"
        chat.AddText(C_YELL, nick, C_WHITE, " кричит: \"", C_YELL, text, C_WHITE, "\"")

    elseif msgType == TYPE.WHISPER then
        -- [Шёпот] Имя: текст
        chat.AddText(C_WHSP, "[Шёпот] ", col, nick, C_WHITE, ": " .. text)

    elseif msgType == TYPE.OOC then
        -- [ООС] Имя: текст
        chat.AddText(C_OOC, "[ООС] ", col, nick, C_OOC, ": " .. text)

    elseif msgType == TYPE.PM then
        -- [ЛС от Имя] текст
        chat.AddText(C_PM, "[ЛС от ", col, nick, C_PM, "] ", C_WHITE, text)
    end
end)
