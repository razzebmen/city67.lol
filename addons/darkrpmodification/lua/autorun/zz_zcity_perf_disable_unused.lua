--[[---------------------------------------------------------------------------
ZCity RP — отключение неиспользуемых подсистем homigrad для производительности
---------------------------------------------------------------------------
У нас RP-сервер на DarkRP. Однако в garrysmod/lua/homigrad/ загружаются ВСЕ
файлы базового zcity-аддона, включая большие подсистемы для других режимов
(TDM/раунды/абнормалити/swarm-NPC/итд). Они вешают свои Think/PostThink/
RenderScreenspaceEffects хуки и таймеры — которые тикают каждый кадр/секунду
и впустую жгут CPU.

Этот файл загружается ПОСЛЕ homigrad (имя начинается на zz_, последняя буква
по алфавиту — autorun отрабатывает в алфавитном порядке) и снимает хуки
которые гарантированно не нужны для RP-режима.

Откат:
  Удалить этот файл / переименовать в .lua.disabled — все хуки восстановятся
  при следующем рестарте сервера, потому что они навешиваются заново при
  загрузке homigrad.

Безопасность:
  Снимаем только хуки чьи владельцы НЕ используются ZCity RP. Не трогаем
  organism, weapon-base, кастомизацию, медицину, движение — это всё нужно.
---------------------------------------------------------------------------]]

local function rmHook(event, name)
    if hook.GetTable() and hook.GetTable()[event] and hook.GetTable()[event][name] then
        hook.Remove(event, name)
    end
end

local function rmTimer(name)
    if timer.Exists(name) then timer.Remove(name) end
end

-- Применяем отключение чуть позже InitPostEntity чтобы все хуки уже встали.
local function ApplyDisable()
    -- =======================================================================
    -- 1. ABNORMALTY DETECTION — ивент-система телепортов/невидимости/swarm.
    --    Не используется в RP. Убираем всё вместе с её Think-таймерами.
    -- =======================================================================
    local ABNORMAL_HOOKS = {
        Think = {
            "Abnormalties_Invisibility",
            "Abnormalties_Ressurection",
            "Abnormalties_Heal",
            "Abnormalties_ConjureTA",
            "Abnormalties_SQLSave",
            "Abnormalties",
            "temp_Abnormalties",
        },
        PlayerPostThink = {
            "Abnormalties_Invisibility",
            "Abnormalties_Consequences",
        },
        PlayerInitialSpawn = { "AbnormaltiesSQL" },
        PlayerDisconnected = { "Abnormalties_SQLSave" },
        PlayerDeath = { "Abnormalties_Invisibility" },
        ["Player Spawn"] = { "Abnormalties_Invisibility" },
        DatabaseConnected = { "AbnormaltiesSQL" },
        PostCleanupMap = {
            "Abnormalties_Invisibility",
            "Abnormalties_Ressurection",
            "Abnormalties_Heal",
            "Abnormalties_ConjureTA",
            "Abnormalties",
        },
        PreHomigradDamage          = { "Abnormalties_SpecialEquipment" },
        PreTraceOrganBulletDamage  = { "Abnormalties_SpecialEquipment" },
        PreHomigradDamageBulletBleedAdd = { "Abnormalties_SpecialEquipment" },
        HG_PlayerSay               = { "Abnormalties" },
        HomigradDamage             = { "Abnormalties_Equalizers" },
        HG_BloodParticleStartedDropping = { "Abnormalties" },
        Abnormalties_HotZoneAbnormaltyAdded = {
            "Abnormalties_Invisibility",
            "Abnormalties_Ressurection",
            "Abnormalties_Heal",
            "Abnormalties_ConjureTA",
            "Abnormalties_Broadcast",
            "Abnormalties_Equalizer",
            "Abnormalties_Bleeding_Musket",
            "Abnormalties",
        },
        EntityTakeDamage = { "Abnormalties_Weapon" },
        Fake             = { "Abnormalties_Invisibility" },
        CanListenOthers  = { "Abnormalties_Broadcast" },
    }
    for event, names in pairs(ABNORMAL_HOOKS) do
        for _, n in ipairs(names) do rmHook(event, n) end
    end

    -- =======================================================================
    -- 2. SWARM (NPC-система ивента) — собственные Think + спавн NPC.
    --    Не используется в RP.
    -- =======================================================================
    local SWARM_HOOKS = {
        Think           = { "Swarm", "Swarm2", "SWARM_Misc", "SWARM" },
        PlayerDeath     = { "Swarm" },
        ["Player Spawn"] = { "Swarm" },
        CanPlayerSuicide = { "Swarm" },
        PostCleanupMap  = { "Swarm" },
        CalcMainActivity = { "Swarm" },
        StartCommand    = { "Swarm" },
        CreateMove      = { "Swarm" },
        PostDrawHUD     = { "Swarm" },
    }
    for event, names in pairs(SWARM_HOOKS) do
        for _, n in ipairs(names) do rmHook(event, n) end
    end

    -- =======================================================================
    -- 3. DYNAMIC MUSIC (обе версии) — клиентская музыка для боёвых режимов.
    --    Не нужна для RP, тратит Think.
    -- =======================================================================
    rmHook("Think", "DynamicMusicV2")
    rmHook("Think", "DMusic.Think")
    rmHook("HomigradDamage", "Panic") -- из dynmusic/sh_packs.lua

    -- =======================================================================
    -- 4. ACHIEVEMENTS — система достижений homigrad. Хук на InitialSpawn
    --    шлёт MySQL-запрос за каждого подключившегося. Нам в RP не нужно
    --    (свой DarkRP), запросы попусту жгут БД и сетевой ввод-вывод.
    -- =======================================================================
    rmHook("PlayerInitialSpawn", "hg_Exp_OnInitSpawn")
    rmHook("PlayerDisconnected", "savevalues")

    -- =======================================================================
    -- 5. PLAYER CLASSES, которые НЕ используются в RP.
    --    В RP используются: police, swat, terrorist, isis, medic_rp, Refugee,
    --    Metrocop. Остальные классы создают свои хуки, но никогда не
    --    активируются — игроки не имеют этих PlayerClassName. Снимаем хуки.
    -- =======================================================================

    -- furry
    rmHook("Org Think",                "regenerationfurry")
    rmHook("PlayerDeath",              "FurDeathSound")
    rmHook("HomigradDamage",           "FurCrackHit")
    rmHook("HG_ReplacePhrase",         "UwUPhrases")
    rmHook("HG_ReplaceBurnPhrase",     "UwUBurnPhrases")
    rmHook("Org Think",                "ItHurtsfrfr")
    rmHook("RenderScreenspaceEffects", "proot_HUD")
    rmHook("PostDrawTranslucentRenderables", "FindPrey")
    rmHook("HUDPaint",                 "FindPrey")
    rmHook("radialOptions",            "scanprey")
    rmHook("RenderScreenspaceEffects", "PNV_ColorCorrectionFur")
    rmHook("PreDrawHalos",             "PNV_LightFur")
    rmHook("SetupMove",                "PNV_ThinkFur")

    -- gordon (HEV-suit)
    rmHook("PostCleanupMap",   "huyhuygordonspasjizn")
    rmHook("Player Think",     "health_armor_gordonthings")
    rmHook("WeaponEquip",      "pickuplom")
    rmHook("HG_CanThoughts",   "GordonCantDumat")
    rmHook("PlayerCanPickupItem", "hevsuit")
    rmHook("HomigradDamage",   "takesomearmor")
    rmHook("RenderScreenspaceEffects", "HEV_helmet")
    rmHook("CanListenOthers",  "GordonWeDontHearYou")
    rmHook("HG_PlayerSay",     "GordonWeDontSeeYouChat")
    rmHook("Think",            "HEV_Notify")
    rmHook("Org Think",        "gordon_healing")
    rmHook("HomigradDamage",   "HEV_Medical")

    -- slugcat
    rmHook("HG_ReplacePhrase", "ScugPhrases")

    -- nationalguard / commanderforces / rebels — footsteps хуки бесполезны
    -- (без класса не сработают, но в hook-таблице висят). Снимаем для чистоты.
    rmHook("HG_PlayerFootstep", "nationalguard_footsteps")
    rmHook("HG_PlayerFootstep", "commanderforces_footsteps")
    rmHook("HomigradDamage",    "Rebels_painsounds")
    rmHook("HGReloading",       "Rebels_reloadalert")

    print("[ZCity RP Perf] Disabled unused homigrad subsystems (abnormalty, swarm, dynmusic, achievements, unused classes)")
end

-- Запускаем в InitPostEntity + ещё раз через 5 сек на случай если какие-то
-- хуки навешиваются с задержкой (например в DatabaseConnected callback).
hook.Add("InitPostEntity", "ZCity_RP_PerfDisableUnused", function()
    timer.Simple(2, ApplyDisable)
    timer.Simple(10, ApplyDisable) -- повторно, чтобы поймать поздно навешенные
end)

-- Также сразу при загрузке (на случай autorefresh / lua_reloadents — без
-- рестарта). InitPostEntity не сработает, но homigrad уже загружен.
timer.Simple(0, ApplyDisable)
timer.Simple(5, ApplyDisable)
