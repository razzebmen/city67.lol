--[[---------------------------------------------------------------------------
ZCity RP — отключение всех стандартных DarkRP HUD-элементов
---------------------------------------------------------------------------
Свой HUD рисует homigrad (lua/homigrad/cl_hud.lua) + cl_roleplay (наш модуль).
Поэтому ВСЕ дарковские HUD-куски скрываем.
---------------------------------------------------------------------------]]
if SERVER then return end

local hideHUDElements = {
    ["DarkRP_HUD"]            = true,  -- весь DarkRP HUD
    ["DarkRP_EntityDisplay"]  = true,  -- ник над игроком (homigrad сам рисует)
    ["DarkRP_LocalPlayerHUD"] = true,  -- бар жизни/деньги/job (homigrad сам)
    ["DarkRP_Hungermod"]      = true,  -- голод (homigrad organism сам)
    ["DarkRP_Agenda"]         = true,  -- свой будет
    ["DarkRP_LockdownHUD"]    = true,
    ["DarkRP_ArrestedHUD"]    = true,
    ["DarkRP_ChatReceivers"]  = true,  -- свой чат homigrad
}

hook.Add("HUDShouldDraw", "ZCity_HideDarkRPHUD", function(name)
    if hideHUDElements[name] then return false end
end)

print("[ZCity RP] DarkRP HUD elements hidden (homigrad+cl_roleplay рисует свой)")
