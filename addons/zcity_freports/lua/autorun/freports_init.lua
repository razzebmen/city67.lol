--[[---------------------------------------------------------------------------
ZCity RP — система жалоб (FrePorts).
Дизайн оставлен без изменений (freports/cl_init.lua), серверная логика
адаптирована под ULX-группы нашего сервера. Библиотека netvar (nw) встроена
в аддон, чтобы не зависеть от plib_v2.
---------------------------------------------------------------------------]]

freports = freports or {}

local include_sv = SERVER and include or function() end
local include_cl = SERVER and AddCSLuaFile or include
local include_sh = function(f)
	include_sv(f)
	include_cl(f)
end

-- Встроенная библиотека сетевых переменных (SetNetVar/GetNetVar/nw.Register).
-- Грузим первой и только если глобал ещё не определён другим аддоном.
if SERVER then AddCSLuaFile("freports/nw.lua") end
if not nw then include("freports/nw.lua") end

include_sh("freports/config.lua")

for _, f in SortedPairs( file.Find( "freports/sh_*.lua", "LUA" ) ) do
	include_sh("freports/" .. f)
end

for _, f in SortedPairs( file.Find( "freports/sv_*.lua", "LUA" ) ) do
	include_sv("freports/" .. f)
end

for _, f in SortedPairs( file.Find( "freports/cl_*.lua", "LUA" ) ) do
	include_cl("freports/" .. f)
end
