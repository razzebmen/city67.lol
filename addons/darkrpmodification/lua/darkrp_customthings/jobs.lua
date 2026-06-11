--[[---------------------------------------------------------------------------
ZCity RP — Custom Jobs (мигрировано из gamemodes/zcity/.../modes/roleplay/sv_roleplay.lua)
Все имена/цвета/оружие/модели/армор/лимиты/оклады сохранены 1:1.
---------------------------------------------------------------------------]]

-- =============================================================================
-- 1. Гражданский (стартовая профессия по умолчанию)
-- =============================================================================
TEAM_CITIZEN = DarkRP.createJob("Гражданский", {
    color               = Color(80, 180, 100, 255),
    model               = {"models/player/group01/male_02.mdl"},
    description         = [[Простой житель города.]],
    weapons             = {},
    command             = "citizen",
    max                 = 0,
    salary              = 100,
    admin               = 0,
    vote                = false,
    hasLicense          = false,
    candemote           = false,
    category            = "Civilians",
})

-- =============================================================================
-- 2. Полицейский
-- =============================================================================
TEAM_POLICE = DarkRP.createJob("Полицейский", {
    color               = Color(60, 120, 200, 255),
    model               = {
        "models/monolithservers/mpd/male_01.mdl",
        "models/monolithservers/mpd/male_03.mdl",
        "models/monolithservers/mpd/male_04_2.mdl",
        "models/monolithservers/mpd/male_05.mdl",
        "models/monolithservers/mpd/male_07_2.mdl",
        "models/monolithservers/mpd/male_08.mdl",
        "models/monolithservers/mpd/male_09_2.mdl",
    },
    description         = [[Поддерживает порядок в городе.]],
    weapons             = {
        "weapon_glock17",
        "weapon_hg_tonfa",
        "weapon_handcuffs_key",
        "weapon_handcuffs",
        "weapon_taser",
        "weapon_medkit_sh",
        "weapon_walkie_talkie",
    },
    command             = "police",
    max                 = 10,
    salary              = 250,
    admin               = 0,
    vote                = false,
    hasLicense          = true,
    category            = "Civil Protection",
    PlayerSpawn         = function(ply) ply:SetMaxHealth(100); ply:SetHealth(100) end,
})

-- =============================================================================
-- 3. Спецназ
-- =============================================================================
TEAM_SWAT = DarkRP.createJob("Спецназ", {
    color               = Color(40, 80, 140, 255),
    model               = {"models/css_seb_swat/css_swat.mdl"},
    description         = [[Тяжёлая полицейская сила. Брошен на самые сложные операции.]],
    weapons             = {
        "weapon_glock17",
        "weapon_handcuffs_key",
        "weapon_handcuffs",
        "weapon_ram",
        "weapon_melee",
        "weapon_m4a1",
        "weapon_medkit_sh",
        "weapon_walkie_talkie",
    },
    command             = "swat",
    max                 = 5,
    salary              = 350,
    admin               = 0,
    vote                = true,
    hasLicense          = true,
    category            = "Civil Protection",
    -- Армор/радиочастота применяются в zcity_rp_jobs модуле
    customCheck         = function(ply) return true end,
})

-- =============================================================================
-- 4. Мэр
-- =============================================================================
TEAM_MAYOR = DarkRP.createJob("Мэр", {
    color               = Color(200, 160, 60, 255),
    model               = {"models/player/breen.mdl"},
    description         = [[Глава города. Может вводить налоги, правила, комендантский час.]],
    weapons             = {
        "weapon_deagle",
        "weapon_medkit_sh",
        "weapon_handcuffs_key",
        "weapon_handcuffs",
        "weapon_walkie_talkie",
    },
    command             = "mayor",
    max                 = 1,
    salary              = 500,
    admin               = 0,
    vote                = true,
    hasLicense          = true,
    mayor               = true,
    category            = "Civil Protection",
})

-- =============================================================================
-- 5. Глава Полиции
-- =============================================================================
TEAM_CHIEF = DarkRP.createJob("Глава Полиции", {
    color               = Color(80, 100, 180, 255),
    model               = {"models/monolithservers/mpd/male_01.mdl"},
    description         = [[Командир полиции города.]],
    weapons             = {
        "weapon_deagle",
        "weapon_medkit_sh",
        "weapon_handcuffs_key",
        "weapon_handcuffs",
        "weapon_walkie_talkie",
    },
    command             = "chief",
    max                 = 1,
    salary              = 400,
    admin               = 0,
    vote                = true,
    hasLicense          = true,
    chief               = true,
    category            = "Civil Protection",
})

-- =============================================================================
-- 6. Бандит
-- =============================================================================
TEAM_BANDIT = DarkRP.createJob("Бандит", {
    color               = Color(180, 60, 60, 255),
    model               = {"models/player/group03m/male_01.mdl"},
    description         = [[Городской преступник.]],
    -- Базовый бандит без оружия. VIP-бандит получает sogknife + mp-80 как перк
    -- (см. darkrp_modules/zcity_rp_jobs/sv_loadout.lua → VIP_BANDIT_WEAPONS).
    weapons             = {},
    command             = "bandit",
    max                 = 15,
    salary              = 150,
    admin               = 0,
    vote                = false,
    hasLicense          = false,
    category            = "Criminals",
})

-- =============================================================================
-- 7. Продавец Оружия
-- =============================================================================
TEAM_GUNDEALER = DarkRP.createJob("Продавец Оружия", {
    color               = Color(140, 100, 60, 255),
    model               = {
        "models/player/Group01/male_03.mdl",
        "models/player/Group01/male_08.mdl",
        "models/player/Group01/male_09.mdl",
    },
    description         = [[Может ставить магазин оружия (zb_gun_shop) и торговать.]],
    weapons             = {},
    command             = "gundealer",
    max                 = 2,
    salary              = 300,
    admin               = 0,
    vote                = false,
    hasLicense          = true,
    category            = "Civilians",
})

-- =============================================================================
-- 8. Солдат ЦАХАЛ
-- =============================================================================
TEAM_ISIS = DarkRP.createJob("Солдат ЦАХАЛ", {
    color               = Color(120, 40, 40, 255),
    model               = {"models/player/group03m/male_02.mdl"},
    description         = [[Член группировки ЦАХАЛ.]],
    weapons             = {
        "weapon_makarov",
        "weapon_akm",
        "weapon_bandage_sh",
        "weapon_painkillers",
        "weapon_walkie_talkie",
        "weapon_sogknife",
        "st_rope_cuffs",
        "weapon_bagmask",
    },
    command             = "isis",
    max                 = 10,
    salary              = 200,
    admin               = 0,
    vote                = false,
    hasLicense          = false,
    category            = "Criminals",
})

-- =============================================================================
-- 9. Глава ЦАХАЛ
-- =============================================================================
TEAM_ISIS_LEADER = DarkRP.createJob("Глава ЦАХАЛ", {
    color               = Color(100, 20, 20, 255),
    model               = {"models/player/group03m/male_03.mdl"},
    description         = [[Командир ЦАХАЛ. Может ограбить казну и объявить войну городу.]],
    weapons             = {
        "weapon_deagle",
        "weapon_akm",
        "weapon_hg_type59_tpik",
        "weapon_bigbandage_sh",
        "weapon_painkillers",
        "weapon_walkie_talkie",
        "st_rope_cuffs",
        "weapon_bagmask",
    },
    command             = "isisleader",
    max                 = 1,
    salary              = 400,
    admin               = 0,
    vote                = true,
    hasLicense          = false,
    category            = "Criminals",
})

-- =============================================================================
-- 10. Медик
-- =============================================================================
TEAM_MEDIC = DarkRP.createJob("Медик", {
    color               = Color(60, 180, 100, 255),
    model               = {"models/player/kleiner.mdl"},
    description         = [[Спасает раненых.]],
    weapons             = {
        "weapon_bigbandage_sh",
        "weapon_bandage_sh",
        "weapon_medkit_sh",
        "weapon_painkillers",
        "weapon_naloxone",
        "weapon_adrenaline",
        "weapon_morphine",
    },
    command             = "medic",
    max                 = 5,
    salary              = 200,
    admin               = 0,
    vote                = false,
    hasLicense          = false,
    medic               = true,
    category            = "Civilians",
})


--[[---------------------------------------------------------------------------
Default team joining: Гражданский
---------------------------------------------------------------------------]]
GAMEMODE.DefaultTeam = TEAM_CITIZEN

--[[---------------------------------------------------------------------------
Civil protection: полиция, спецназ, глава полиции, мэр
---------------------------------------------------------------------------]]
GAMEMODE.CivilProtection = {
    [TEAM_POLICE] = true,
    [TEAM_SWAT]   = true,
    [TEAM_CHIEF]  = true,
    [TEAM_MAYOR]  = true,
}

--[[---------------------------------------------------------------------------
Hitman team (если будет hitman джоб — добавить тут)
---------------------------------------------------------------------------]]
-- DarkRP.addHitmanTeam(TEAM_MOB)
