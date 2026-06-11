--[[---------------------------------------------------------------------------
ZCity RP — авто-спектатор через 10 минут бездействия
---------------------------------------------------------------------------
Раньше тут была AFK-камера (заморозка тела + облётная камера, cl_afk.lua).
ЗАМЕНЕНО: за AFK_SECONDS (600с = 10 мин) бездействия живого игрока КИДАЕТ В
СПЕКТАТОРЫ (TEAM_SPECTATOR, free-roam) — ровно как кнопка SPECTATE в табе
(логика идентична sv_specmode.lua). Возврат в игру — кнопкой PLAYING в
scoreboard (Tab), штатный ZB_SpecMode.

Активность = любая кнопка / движение мыши / движение персонажа (StartCommand).
Не трогаем: мёртвых, зрителей, в транспорте, ботов, админ-спектатор (FSpectate).

Конфиг: ConVar rp_afk_seconds (FCVAR_ARCHIVE). 0 — выключить.
---------------------------------------------------------------------------]]
if not SERVER then return end

local CVAR_AFK = CreateConVar("rp_afk_seconds", "600",
    {FCVAR_ARCHIVE, FCVAR_NOTIFY},
    "Через сколько секунд бездействия кидать в спектаторы (0 = выкл)")

local SCAN_INTERVAL = 5  -- как часто проверять игроков на бездействие

-- =============================================================================
-- Кого можно кидать в спектаторы за неактив
-- =============================================================================
local function CanGoAFK(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if ply:IsBot() then return false end
    if not ply:Alive() then return false end
    if ply:Team() == TEAM_SPECTATOR then return false end   -- уже зритель
    if ply:InVehicle() then return false end
    if ply.FSpectating then return false end                 -- админ-спектатор
    return true
end

-- =============================================================================
-- Перевод в спектаторы (идентично кнопке SPECTATE — см. sv_specmode.lua)
-- =============================================================================
local function SendToSpectators(ply)
    if not CanGoAFK(ply) then return end
    -- уважаем тот же хук-вето, что и ручной вход в спектаторы
    if hook.Run("ZB_JoinSpectators", ply) then return end

    if ply:Alive() then ply:Kill() end
    ply:SetTeam(TEAM_SPECTATOR)
    -- free-roam дед-камера встаёт в sv_spectator.lua на PlayerDeath.

    ply:ChatPrint("[AFK] Вы переведены в спектаторы за 10 минут бездействия. " ..
        "Нажмите PLAYING в таблице игроков (Tab), чтобы вернуться в игру.")
end

-- =============================================================================
-- Детект активности (любой ввод обновляет метку времени)
-- =============================================================================
hook.Add("StartCommand", "ZCity_AFK_Activity", function(ply, cmd)
    if not IsValid(ply) then return end
    if cmd:GetButtons() ~= 0
        or cmd:GetMouseX() ~= 0 or cmd:GetMouseY() ~= 0
        or cmd:GetForwardMove() ~= 0 or cmd:GetSideMove() ~= 0
        or cmd:GetUpMove() ~= 0 then
        ply.ZCityLastActive = CurTime()
    end
end)

-- =============================================================================
-- Планировщик: проверяем бездействие
-- =============================================================================
timer.Create("ZCity_AFK_Scan", SCAN_INTERVAL, 0, function()
    local limit = CVAR_AFK:GetInt()
    if limit <= 0 then return end -- выключено

    local now = CurTime()
    for _, ply in ipairs(player.GetAll()) do
        if CanGoAFK(ply) then
            local last = ply.ZCityLastActive or now
            if (now - last) >= limit then
                SendToSpectators(ply)
            end
        end
    end
end)

-- =============================================================================
-- Сброс метки активности
-- =============================================================================
hook.Add("PlayerInitialSpawn", "ZCity_AFK_InitActivity", function(ply)
    ply.ZCityLastActive = CurTime()
end)

hook.Add("PlayerSpawn", "ZCity_AFK_ResetActivity", function(ply)
    -- после возврата из спектаторов (PLAYING) спавн обнуляет таймер —
    -- игрока не выкинет обратно мгновенно.
    ply.ZCityLastActive = CurTime()
end)

print("[ZCity RP] Авто-спектатор за бездействие загружен (rp_afk_seconds=" ..
    CVAR_AFK:GetInt() .. ")")
