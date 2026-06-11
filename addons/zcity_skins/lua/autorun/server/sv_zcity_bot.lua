--[[---------------------------------------------------------------------------
city67: тестовый бот при пустом сервере
---------------------------------------------------------------------------
Бот используется только для одиночных тестов. Логика:
* Сервер пустой (нет ни одного человека) → автоматически спаунится 1 бот.
* Заходит реальный игрок → все боты кикаются.
* Уходит последний реальный игрок → снова спаунится 1 бот.

Раньше PlayerInitialSpawn ДОспаунивал ботов независимо от реальных игроков —
из-за этого бот оставался в слотах даже когда заходили живые. Поправлено.
---------------------------------------------------------------------------]]
if not SERVER then return end

local SPAWN_DELAY = 5
local BOTS_WHEN_EMPTY = 1

local function getCounts()
    local humans, bots = 0, 0
    for _, ply in ipairs(player.GetAll()) do
        if ply:IsBot() then
            bots = bots + 1
        else
            humans = humans + 1
        end
    end
    return humans, bots
end

local function kickAllBots(reason)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsBot() then
            ply:Kick(reason or "[zcity_bot] real players online")
        end
    end
end

local function spawnBotsIfEmpty()
    local humans, bots = getCounts()
    if humans > 0 then
        -- Реальные игроки есть → ботов быть не должно.
        if bots > 0 then kickAllBots("[zcity_bot] real players online") end
        return
    end
    local need = BOTS_WHEN_EMPTY - bots
    for _ = 1, need do RunConsoleCommand("bot") end
    if need > 0 then
        print(string.format("[zcity_bot] auto-spawned %d bot(s) (server empty)", need))
    end
end

-- Стартовый автоспавн: только если на сервере нет живых игроков.
hook.Add("Initialize", "zcity_bot_autospawn", function()
    timer.Simple(SPAWN_DELAY, spawnBotsIfEmpty)
end)

-- Зашёл реальный игрок → выгоняем всех ботов.
hook.Add("PlayerInitialSpawn", "zcity_bot_kick_on_join", function(ply)
    if not IsValid(ply) or ply:IsBot() then return end
    -- Небольшая задержка чтобы initial spawn успел отработать у самого игрока
    -- и Kick не мешал зашедшему пройти через PlayerAuth/прочие хуки.
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        kickAllBots("[zcity_bot] real player joined")
    end)
end)

-- Ушёл реальный игрок → если он был последним, возвращаем бота для тестов.
hook.Add("PlayerDisconnected", "zcity_bot_respawn_when_empty", function(ply)
    if not IsValid(ply) or ply:IsBot() then return end
    -- На момент хука ply ещё считается в player.GetAll(), поэтому считаем
    -- через timer.Simple(1, ...) — к этому моменту его уже не будет в списке.
    timer.Simple(1, spawnBotsIfEmpty)
end)
