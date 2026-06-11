--[[---------------------------------------------------------------------------
ZCity Skins — общий загрузчик конфига (shared autorun).
---------------------------------------------------------------------------
* На сервере: AddCSLuaFile отдаёт sh_config.lua клиенту + include на сервере.
* На клиенте: include только.
* Запускается ДО sv_zcity_skins.lua / cl_zcity_skins*.lua, потому что
  файлы lua/autorun/*.lua подключаются в алфавитном порядке (`sh_*` < `sv_*`/`cl_*`).
---------------------------------------------------------------------------]]
if SERVER then
    AddCSLuaFile("zcity_skins/sh_config.lua")
end

include("zcity_skins/sh_config.lua")
