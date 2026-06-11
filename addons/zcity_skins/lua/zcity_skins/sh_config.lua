--[[---------------------------------------------------------------------------
ZCity Skins — конфиг скинов
---------------------------------------------------------------------------
Каждая запись — кастомный материал, который можно применить к weapon.
Формат:
    id          — уникальный id скина
    name        — отображаемое имя
    weapon      — список SWEP-классов, на которые скин ложится (всё семейство модели)
    model       — модель оружия для превью в DModelPanel
    submat      — индекс sub-материала (опционально). Если не задан — красим все 0..15
                  можно массивом, если нужно перекрасить несколько слотов
    material    — путь к VMT (без префикса "materials/")
    rarity      — "common"/"rare"/"legendary" (для рамки в UI)

Семьи моделей (одна модель → много SWEP-классов, бодигруппы отличаются):
  Glock  : weapon_glock17 / weapon_glock18c / weapon_glock26
           модель models/weapons/arccw/c_ud_glock.mdl
  Deagle : weapon_deagle
           модель models/weapons/arccw/c_ud_deagle.mdl
  M16/AR : weapon_m16a2 / weapon_ar15 / weapon_m4a1 / weapon_colt9mm / weapon_ar_pistol
           модель models/weapons/arccw/c_ud_m16.mdl
  Knife  : weapon_melee
           модель models/weapons/combatknife/tactical_knife_iw7_wm.mdl
  SOG    : weapon_sogknife
           модель models/zcity/weapons/w_sog_knife.mdl
---------------------------------------------------------------------------]]
ZCITY_SKINS = ZCITY_SKINS or {}
ZCITY_SKINS.List = {}

-- Семьи оружия (используются в server-apply: один клик — применить ко всему семейству)
ZCITY_SKINS.Families = {
    glock  = {"weapon_glock17", "weapon_glock18c", "weapon_glock26"},
    deagle = {"weapon_deagle"},
    m16    = {"weapon_m16a2", "weapon_ar15", "weapon_m4a1", "weapon_colt9mm", "weapon_ar_pistol"},
    knife  = {"weapon_melee"},
    sog    = {"weapon_sogknife"},
}

function ZCITY_SKINS.FamilyOf(weaponClass)
    for fam, list in pairs(ZCITY_SKINS.Families) do
        for _, w in ipairs(list) do
            if w == weaponClass then return fam, list end
        end
    end
    return nil, { weaponClass }
end

-- Стандартный «без скина»
table.insert(ZCITY_SKINS.List, {
    id       = "default",
    name     = "Стандартный",
    desc     = "Без изменений — обычная заводская окраска.",
    weapon   = {
        "weapon_glock17","weapon_glock18c","weapon_glock26",
        "weapon_deagle",
        "weapon_m16a2","weapon_ar15","weapon_m4a1","weapon_colt9mm","weapon_ar_pistol",
        "weapon_melee",
        "weapon_sogknife",
    },
    model    = "models/weapons/arccw/c_ud_glock.mdl",
    rarity   = "common",
    isClear  = true,
})

-- ─── Glock skins (на всё семейство Glock) ────────────────────────────────────
table.insert(ZCITY_SKINS.List, {
    id       = "glock_neon",
    name     = "Glock «Neon»",
    desc     = "Зеркальный неон с эффектом фонга. Применяется к Glock 17/18c/26.",
    weapon   = {"weapon_glock17","weapon_glock18c","weapon_glock26"},
    model    = "models/weapons/arccw/c_ud_glock.mdl",
    material = "Skins/Glock/glock",
    rarity   = "rare",
})

-- ─── Deagle skins ────────────────────────────────────────────────────────────
table.insert(ZCITY_SKINS.List, {
    id       = "deagle_sex",
    name     = "Deagle «Crimson»",
    desc     = "Гладкий металл, золотистая поволока, фрезерованная гравировка.",
    weapon   = {"weapon_deagle"},
    model    = "models/weapons/arccw/c_ud_deagle.mdl",
    material = "Skins/Deagle/sex",
    rarity   = "legendary",
})

-- ─── M16/AR skins (на всё семейство ArcCW M16) ───────────────────────────────
table.insert(ZCITY_SKINS.List, {
    id       = "m16_stalol",
    name     = "M16/AR «Сталол»",
    desc     = "Промышленный камуфляж. Подходит для M16, M4A1, AR15, Colt9mm, AR Pistol.",
    weapon   = {"weapon_m16a2","weapon_ar15","weapon_m4a1","weapon_colt9mm","weapon_ar_pistol"},
    model    = "models/weapons/arccw/c_ud_m16.mdl",
    material = "Skins/M16/m16_new",
    rarity   = "rare",
})

table.insert(ZCITY_SKINS.List, {
    id       = "m16_ris",
    name     = "M16/AR «RIS Tactical»",
    desc     = "Чёрный тактический обвес. Подходит для M16, M4A1, AR15, Colt9mm, AR Pistol.",
    weapon   = {"weapon_m16a2","weapon_ar15","weapon_m4a1","weapon_colt9mm","weapon_ar_pistol"},
    model    = "models/weapons/arccw/c_ud_m16.mdl",
    material = "Skins/M16/m16_ris_handguard_short",
    rarity   = "common",
})

-- ─── Combat knife skins ──────────────────────────────────────────────────────
table.insert(ZCITY_SKINS.List, {
    id       = "knife_combat",
    name     = "Нож «IW7 Combat»",
    desc     = "Карбоновое лезвие с гравировкой и G10-рукоять.",
    weapon   = {"weapon_melee"},
    model    = "models/weapons/combatknife/tactical_knife_iw7_wm.mdl",
    material = "Skins/Combat/tactical_knife_iw7",
    rarity   = "rare",
})

-- ─── SOG knife skin ──────────────────────────────────────────────────────────
table.insert(ZCITY_SKINS.List, {
    id       = "knife_sog_black",
    name     = "Нож «SOG Black»",
    desc     = "Матовая чёрная сталь, антибликовое покрытие.",
    weapon   = {"weapon_sogknife"},
    model    = "models/zcity/weapons/w_sog_knife.mdl",
    material = "Skins/Sog/sog",
    rarity   = "common",
})

-- ─── Карта: weapon class -> список скинов, доступных для этого оружия ───────
function ZCITY_SKINS.SkinsForWeapon(class)
    local out = {}
    for _, s in ipairs(ZCITY_SKINS.List) do
        for _, w in ipairs(s.weapon) do
            if w == class then table.insert(out, s) break end
        end
    end
    return out
end

-- Вкладки в UI: один пункт на семейство (любой класс из семейства подойдёт)
ZCITY_SKINS.WeaponTabs = {
    { class = "weapon_glock17", title = "Glock (17/18c/26)", model = "models/weapons/arccw/c_ud_glock.mdl" },
    { class = "weapon_deagle",  title = "Desert Eagle",      model = "models/weapons/arccw/c_ud_deagle.mdl" },
    { class = "weapon_m16a2",   title = "M16 / AR / M4A1",   model = "models/weapons/arccw/c_ud_m16.mdl" },
    { class = "weapon_sogknife",title = "SOG SEAL 2000",     model = "models/zcity/weapons/w_sog_knife.mdl" },
    { class = "weapon_melee",   title = "Combat Knife",      model = "models/weapons/combatknife/tactical_knife_iw7_wm.mdl" },
}

-- ─── Пресеты камеры превью (центр + радиус + yaw для каждой модели) ─────────
-- Откалибровано через `zcity_skins_editor` (VGUI редактор): открыть, подвигать
-- ползунки/мышь, нажать «СОХРАНИТЬ ВСЕ» → блок копируется в буфер и пишется
-- в data/zcity_skins/camera_presets.lua. Сюда переносится как финальное
-- значение.
--
-- Без пресета используется авто-AABB (mesh AABB или fallback на BoundingRadius).
-- Для viewmodel-ов ArcCW (`c_ud_*.mdl`) AABB бесполезен — у них в меше есть
-- руки игрока, которые перекашивают центр. Поэтому для них пресет ОБЯЗАТЕЛЕН.
ZCITY_SKINS.CameraPresets = {
    ["models/weapons/arccw/c_ud_deagle.mdl"]              = { center = Vector(16.7436, 7.27882, -4.31664),    radius = 28.0374, yaw = 93.6555 },
    ["models/weapons/arccw/c_ud_glock.mdl"]               = { center = Vector(15.2934, 0.0496778, -5.21926),  radius = 19.0332, yaw = 88.8164 },
    ["models/weapons/arccw/c_ud_m16.mdl"]                 = { center = Vector(17.9803, -13.9598, -3.27083),   radius = 53.4451, yaw = 84.7491 },
    ["models/weapons/combatknife/tactical_knife_iw7_wm.mdl"] = { center = Vector(4.26514, -3.86355, -1.29496), radius = 30.1139, yaw = 266.958 },
    ["models/zcity/weapons/w_sog_knife.mdl"]              = { center = Vector(-0.017866, -0.04006, 1.06388),  radius = 17.817,  yaw = 179.4 },
}

-- VIP-группы: явно купленный VIP + старший стафф (dadmin и выше).
-- Модераторские (moderator/dmoderator) и operator — НЕ авто-VIP.
ZCITY_SKINS.VipGroups = {
    vip         = true,
    dadmin      = true,
    admin       = true,
    superadmin  = true,
    dsuperadmin = true,
}

function ZCITY_SKINS.IsVip(ply)
    if not IsValid(ply) then return false end
    return ZCITY_SKINS.VipGroups[ply:GetUserGroup()] == true
end

-- ─── Авто-скины (по работе/классу/иной логике) ───────────────────────────────
-- Это не выбираемые в меню скины, а серверная логика "если игрок X — наложить
-- материал Y на оружие Z". Применяется поверх обычной системы выбираемых скинов.
--
-- Текущие правила:
--   * weapon_handcuffs у Солдата/Главы ЦАХАЛ → IDF-текстура наручников.
--     Полиция/SWAT использует ту же weapon_handcuffs — у них остаётся
--     стандартная окраска.

ZCITY_SKINS.AutoSkins = ZCITY_SKINS.AutoSkins or {}

ZCITY_SKINS.AutoSkins.weapon_handcuffs = function(ply)
    if not IsValid(ply) then return nil end
    local jobName = ply:GetNWString("RoleplayJob", "")
    if jobName == "Солдат ЦАХАЛ" or jobName == "Глава ЦАХАЛ" then
        return "Skins/Idf/handcuffs_idf"
    end
    return nil
end
