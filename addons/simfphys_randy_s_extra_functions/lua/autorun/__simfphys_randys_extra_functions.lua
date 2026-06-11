--oops i seperated this into multiple files. clumsy me

--little disclaimer: I'm not good at LUA coding by any means, I think-
--I have no idea what the do's and dont's are and all the naming conventions and such, so all of this is just guessing lol
--it works but its probably bad. you should look at someone elses code if you want to learn lua

AddCSLuaFile("simfphysextra/init.lua")
AddCSLuaFile("simfphysextra/cl_init.lua")

include("simfphysextra/init.lua")

if CLIENT then
	include("simfphysextra/cl_init.lua")
end