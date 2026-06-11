--[[---------------------------------------------------------------------------
ZCity RP — шрифты ZB_Interface* (перенесены из gamemodes/zcity/.../cl_init.lua)
---------------------------------------------------------------------------
Используются нашим scoreboard, sfd/tdm-derma, homicide-меню, и т.д.
---------------------------------------------------------------------------]]
if SERVER then return end

local hg_font = ConVarExists("hg_font") and GetConVar("hg_font")
    or CreateClientConVar("hg_font", "Bahnschrift", true, false, "Change UI text font")

local function font()
    local usefont = "Bahnschrift"
    if hg_font:GetString() ~= "" then
        usefont = hg_font:GetString()
    end
    return usefont
end

surface.CreateFont("ZB_InterfaceSmall", {
    font      = font(),
    size      = ScreenScale(6),
    weight    = 400,
    antialias = true,
})

surface.CreateFont("ZB_InterfaceMedium", {
    font      = font(),
    size      = ScreenScale(10),
    weight    = 400,
    antialias = true,
})

surface.CreateFont("ZB_InterfaceMediumLarge", {
    font      = font(),
    size      = 35,
    weight    = 400,
    antialias = true,
})

surface.CreateFont("ZB_InterfaceLarge", {
    font      = font(),
    size      = ScreenScale(20),
    weight    = 400,
    antialias = true,
})

surface.CreateFont("ZB_InterfaceHumongous", {
    font      = font(),
    size      = 200,
    weight    = 400,
    antialias = true,
})
