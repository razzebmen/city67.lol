--[[---------------------------------------------------------------------------
ZCity RP — фиктивный DarkRP-job для TEAM_SPECTATOR
---------------------------------------------------------------------------
Проблема:
В zcity_rp_scoreboard/sv_specmode.lua игрок переводится в TEAM_SPECTATOR
через ply:SetTeam(TEAM_SPECTATOR). DarkRP в RPExtraTeams не имеет записи
для этого team-id, поэтому plyMeta.getJobTable() возвращает nil, а
plyMeta.isMayor() / isChief() / isCP() падают с runtime error через fn.Compose.

Это происходит каждый раз когда игрок-спектатор отключается (DarkRP вызывает
ply:isMayor() в GM:PlayerDisconnected) и в нескольких других местах.

Решение:
Регистрируем заглушку как fake DarkRP-job чтобы getJobTable() возвращала
валидную таблицу с mayor=false, chief=false, cp=false и т.д. В F4-меню её
не видно (customCheck возвращает false), DarkRP с ней никогда не выдаёт
оружие/модель.
---------------------------------------------------------------------------]]

local function RegisterSpectatorStub()
    if not RPExtraTeams or not TEAM_SPECTATOR then return false end
    if RPExtraTeams[TEAM_SPECTATOR] then return true end

    RPExtraTeams[TEAM_SPECTATOR] = {
        name        = "Spectator",
        color       = Color(120, 120, 120, 255),
        model       = "models/player/kleiner.mdl",
        description = "Наблюдатель (спектатор).",
        weapons     = {},
        command     = "",
        max         = 0,
        salary      = 0,
        admin       = 1,
        vote        = false,
        hasLicense  = false,
        candemote   = false,
        category    = "Citizens",
        mayor       = false,
        chief       = false,
        cp          = false,
        medic       = false,
        cook        = false,
        hobo        = false,
        -- В F4-меню пункт не появится.
        customCheck = function() return false end,
        -- DarkRP не пытается выдавать оружие/модель спектатору.
        PlayerSpawn    = function() return true end,
        PlayerLoadout  = function() return true end,
        PlayerSetModel = function() return true end,
    }

    if SERVER then
        print("[ZCity RP] Spectator job stub registered (TEAM_SPECTATOR=" .. tostring(TEAM_SPECTATOR) .. ")")
    end
    return true
end

-- Несколько попыток на разных стадиях загрузки — DarkRP создаёт RPExtraTeams
-- асинхронно, мы не знаем точный момент когда таблица готова.
hook.Add("loadCustomDarkRPItems", "ZCity_RP_SpectatorJobStub", RegisterSpectatorStub)

hook.Add("InitPostEntity", "ZCity_RP_SpectatorJobStubLate", function()
    timer.Simple(1, RegisterSpectatorStub)
    timer.Simple(5, RegisterSpectatorStub)
end)

-- Сразу попытка на случай если этот файл загружается уже после готовности.
timer.Simple(0, RegisterSpectatorStub)
