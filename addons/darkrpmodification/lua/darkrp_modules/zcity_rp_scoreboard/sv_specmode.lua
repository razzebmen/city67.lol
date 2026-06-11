--[[---------------------------------------------------------------------------
ZCity RP — обработчик ZB_SpecMode (кнопка спектатор/игрок в табе)
---------------------------------------------------------------------------
В табе scoreboard есть кнопки SPECTATE / PLAYING. Они шлют ZB_SpecMode
с bool: true = в спектаторы, false = вернуться в игру.

В DarkRP "обычный игрок" — это TEAM_CITIZEN (наш дефолтный TEAM_CITIZEN).
Спектатор — TEAM_SPECTATOR (стандартный гмодовский).
---------------------------------------------------------------------------]]
if not SERVER then return end

util.AddNetworkString("ZB_SpecMode")

net.Receive("ZB_SpecMode", function(len, ply)
    if not IsValid(ply) then return end

    local toSpec = net.ReadBool()

    -- Хук для совместимости со старым кодом (не блокирует, но даёт другим аддонам шанс)
    local enable = not hook.Run("ZB_JoinSpectators", ply)

    if enable and toSpec and ply:Team() ~= TEAM_SPECTATOR then
        if ply:Alive() then ply:Kill() end
        ply:SetTeam(TEAM_SPECTATOR)
        PrintMessage(HUD_PRINTTALK, ply:Name() .. " joined the spectators.")
        -- Спектатор сразу попадает в свободный полёт (free-roam дед-камера
        -- встаёт в sv_spectator.lua на PlayerDeath). Меню выбора цели убрано.
    elseif not toSpec and ply:Team() == TEAM_SPECTATOR then
        -- Возвращаем в игру через DarkRP changeTeam → дефолтный TEAM_CITIZEN
        local defaultTeam = (GAMEMODE and GAMEMODE.DefaultTeam) or 1
        if ply.changeTeam then
            ply:changeTeam(defaultTeam, true)
        else
            ply:SetTeam(defaultTeam)
        end
        ply:Spawn()
        PrintMessage(HUD_PRINTTALK, ply:Name() .. " joined the players.")
    end
end)

print("[ZCity RP] ZB_SpecMode handler registered")
