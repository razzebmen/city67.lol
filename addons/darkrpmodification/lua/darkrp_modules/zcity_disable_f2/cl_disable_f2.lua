--[[---------------------------------------------------------------------------
ZCity RP — отключение DarkRP F2 меню дверей
---------------------------------------------------------------------------]]
if not CLIENT then return end

-- Блокируем привязку F2 к меню дверей
hook.Add("Initialize", "ZCity_DisableF2DoorMenu", function()
    timer.Simple(0.1, function()
        GAMEMODE.ShowTeam = function() end
    end)
end)

print("[ZCity RP] F2 door menu disabled")
