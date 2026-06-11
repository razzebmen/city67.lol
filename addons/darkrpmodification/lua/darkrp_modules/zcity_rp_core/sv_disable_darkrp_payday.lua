--[[---------------------------------------------------------------------------
ZCity RP — отключение стандартного DarkRP-payday
---------------------------------------------------------------------------
У DarkRP свой payday каждые GAMEMODE.Config.paydelay секунд.
В нашем mode RoundThink тоже выплачивает зарплату каждые 300 сек.
Чтобы не было двойной выплаты — глушим DarkRP-payday через хук.
---------------------------------------------------------------------------]]
if not SERVER then return end

hook.Add("playerGetSalary", "ZCity_RP_DisableDarkRPPayday", function(ply, amount)
    return true, "", 0  -- suppress, no message, zero amount
end)

print("[ZCity RP] DarkRP standard payday disabled (используется RoundThink)")
