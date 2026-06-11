--[[---------------------------------------------------------------------------
ZCity RP — disabled defaults
ВСЕ стандартные DarkRP-системы отключены. Сборка работает на собственных
модулях zcity_rp_* (см. darkrp_modules/) + движок homigrad/zcity (lua/homigrad).
---------------------------------------------------------------------------]]

-- =============================================================================
-- Модули DarkRP. true = отключить.
-- =============================================================================
DarkRP.disabledDefaults["modules"] = {
    ["afk"]              = true,    -- свой AFK через ULX/zcity_antiafk
    ["chatsounds"]       = true,    -- зачем
    ["events"]           = true,    -- свой round-engine
    ["fpp"]              = false,   -- FPP оставляем (защита пропов нужна)
    ["f1menu"]           = true,    -- свой
    ["f4menu"]           = true,    -- свой
    ["hitmenu"]          = true,    -- свой
    ["hud"]              = true,    -- свой (homigrad cl_hud + наши модули)
    ["hungermod"]        = true,    -- свой (organism в homigrad)
    ["playerscale"]      = true,
    ["sleep"]            = true,
    ["fadmin"]           = true,    -- ULX вместо FAdmin
    ["animations"]       = true,    -- свои в homigrad
    ["chatindicator"]    = true,    -- свой
    ["darkrpmessages"]   = true,    -- отключаем DarkRP MOTD ("PUBLIC SERVICE ANNOUNCEMENT")
}

-- =============================================================================
-- Стандартные DarkRP-джобы — все отключены, у нас в jobs.lua свои 10
-- =============================================================================
DarkRP.disabledDefaults["jobs"] = {
    ["chief"]     = true,
    ["citizen"]   = true,
    ["cook"]      = true,
    ["cp"]        = true,
    ["gangster"]  = true,
    ["gundealer"] = true,
    ["hobo"]      = true,
    ["mayor"]     = true,
    ["medic"]     = true,
    ["mobboss"]   = true,
}

-- =============================================================================
-- Шипменты (оружие в магазине Gun Dealer'а) — все стандартные отключаем
-- =============================================================================
DarkRP.disabledDefaults["shipments"] = {
    ["AK47"]         = true,
    ["Desert eagle"] = true,
    ["Fiveseven"]    = true,
    ["Glock"]        = true,
    ["M4"]           = true,
    ["Mac 10"]       = true,
    ["MP5"]          = true,
    ["P228"]         = true,
    ["Pump shotgun"] = true,
    ["Sniper rifle"] = true,
}

-- =============================================================================
-- Стандартные DarkRP-сущности — все отключаем (свои принтеры/драг-лабы и т.п.)
-- =============================================================================
DarkRP.disabledDefaults["entities"] = {
    ["Drug lab"]      = true,
    ["Gun lab"]       = true,
    ["Money printer"] = true,
    ["Microwave"]     = true,
    ["Tip Jar"]       = true,
}

DarkRP.disabledDefaults["vehicles"] = {}

DarkRP.disabledDefaults["food"] = {
    ["Banana"]           = true,
    ["Bunch of bananas"] = true,
    ["Melon"]            = true,
    ["Glass bottle"]     = true,
    ["Pop can"]          = true,
    ["Plastic bottle"]   = true,
    ["Milk"]             = true,
    ["Bottle 1"]         = true,
    ["Bottle 2"]         = true,
    ["Bottle 3"]         = true,
    ["Orange"]           = true,
}

DarkRP.disabledDefaults["doorgroups"] = {
    ["Cops and Mayor only"] = true,
    ["Gundealer only"]      = true,
}

DarkRP.disabledDefaults["ammo"] = {
    ["Pistol ammo"]  = true,
    ["Rifle ammo"]   = true,
    ["Shotgun ammo"] = true,
}

DarkRP.disabledDefaults["agendas"] = {
    ["Gangster's agenda"] = true,
    ["Police agenda"]     = true,
}

DarkRP.disabledDefaults["groupchat"] = {
    [1] = true,
    [2] = true,
    [3] = true,
}

DarkRP.disabledDefaults["hitmen"] = {
    ["mobboss"] = true,
}

DarkRP.disabledDefaults["demotegroups"] = {
    ["Cops"]      = true,
    ["Gangsters"] = true,
}

-- =============================================================================
-- Workarounds DarkRP (фиксы багов GMod). Оставляем как есть — они полезные.
-- =============================================================================
DarkRP.disabledDefaults["workarounds"] = {
    ["os.date() Windows crash"]                      = false,
    ["SkidCheck"]                                    = false,
    ["Error on edict limit"]                         = false,
    ["Durgz witty sayings"]                          = false,
    ["ULX /me command"]                              = false,
    ["gm_save"]                                      = false,
    ["rp_downtown_v4c_v2 rooftop spawn"]             = false,
    ["White flashbang flashes"]                      = false,
    ["APAnti"]                                       = false,
    ["Wire field generator exploit fix"]             = false,
    ["Door tool class fix"]                          = false,
    ["Constraint crash exploit fix"]                 = false,
    ["Deprecated console commands"]                  = false,
    ["disable CAC"]                                  = false,
}
