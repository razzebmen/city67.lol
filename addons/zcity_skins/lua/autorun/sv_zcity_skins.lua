--[[---------------------------------------------------------------------------
ZCity Skins — серверная часть
---------------------------------------------------------------------------
* Раздача ресурсов (resource.AddFile) — материалы скинов и повязка ЦАХАЛ.
* Хранение применённого скина игрока в data/zcity_skins/<sid>.txt.
* Net-API: клиент шлёт `zcity_skins_apply` (weaponClass, skinId).
  - сервер проверяет VIP, валидирует, сохраняет, бродкастит всем.
* Серверный кеш ZCity_PlayerSkins[steamid] = { weapon = skinId }.
---------------------------------------------------------------------------]]
if not SERVER then return end

-- sh_config.lua уже включён через sh_zcity_skins_loader.lua (autorun/sh_*).

util.AddNetworkString("zcity_skins_apply")
util.AddNetworkString("zcity_skins_sync_one")
util.AddNetworkString("zcity_skins_sync_all")

-- ─── Контент: AddFile для всего, что лежит в materials/ ──────────────────────
do
    local files, _ = file.Find("materials/Skins/*", "GAME")
    -- Рекурсивный обход всей папки materials/Skins и Bands и models/weapons/arccw/ud_m16
    local function addAll(root)
        local fs, dirs = file.Find(root .. "/*", "GAME")
        for _, fn in ipairs(fs) do
            resource.AddFile(root .. "/" .. fn)
        end
        for _, d in ipairs(dirs) do addAll(root .. "/" .. d) end
    end
    addAll("materials/Skins")
    addAll("materials/Bands")
    addAll("materials/models/weapons/arccw/ud_m16")
    -- Bag mask: иконка + материалы + модель
    addAll("materials/vgui/zcity_icons")
    addAll("materials/mats/bag_prop")

    -- IDF-текстуры (используются как повязка ЦАХАЛ — sh_accessories.lua указывает на них напрямую)
    resource.AddFile("materials/Skins/Idf/band_idf.vmt")
    resource.AddFile("materials/Skins/Idf/band_idf.vtf")
    resource.AddFile("materials/Skins/Idf/band_idf_tail.vmt")
    resource.AddFile("materials/Skins/Idf/band_idf_tail.vtf")
end

-- ─── Хранилище ───────────────────────────────────────────────────────────────
ZCity_PlayerSkins = ZCity_PlayerSkins or {}

local DATA_DIR = "zcity_skins"
file.CreateDir(DATA_DIR)

local function dataPath(sid)
    return DATA_DIR .. "/" .. string.gsub(sid or "", "[^%w_]", "_") .. ".txt"
end

local function loadFromDisk(ply)
    if not IsValid(ply) then return {} end
    local sid = ply:SteamID()
    if not sid or sid == "" then return {} end
    local path = dataPath(sid)
    if not file.Exists(path, "DATA") then return {} end
    local raw = file.Read(path, "DATA")
    local ok, tbl = pcall(util.JSONToTable, raw or "{}")
    if not ok or not istable(tbl) then return {} end
    return tbl
end

local function saveToDisk(ply, tbl)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    if not sid or sid == "" then return end
    file.Write(dataPath(sid), util.TableToJSON(tbl or {}, true))
end

-- ─── Утилиты ─────────────────────────────────────────────────────────────────
local function findSkin(skinId)
    for _, s in ipairs(ZCITY_SKINS.List) do
        if s.id == skinId then return s end
    end
    return nil
end

local function syncOneToAll(ply, weaponClass, skinId)
    net.Start("zcity_skins_sync_one")
    net.WriteEntity(ply)
    net.WriteString(weaponClass or "")
    net.WriteString(skinId or "")
    net.Broadcast()
end

-- ─── Скин-на-сущности (NW-строка) ───────────────────────────────────────────
-- Чтобы скин «прилипал» к оружию при передаче (drop → pickup другим игроком),
-- дублируем skinId в NW-строке самого weapon-энтити. NW реплицируется движком
-- всем клиентам в PVS, новые игроки тоже получают его автоматически.
-- Клиентский рендер читает эту строку с приоритетом над PlayerSkins.

-- ─── Скин-атачменты ─────────────────────────────────────────────────────────
-- Какие homigrad-атачменты вешать на оружие, когда у него стоит определённый
-- скин. Управляются только эти атачменты — если игрок докрутил себе свой —
-- мы его не трогаем (см. логику в syncSkinAttachments).
--
-- Пример: для скина m16_ris «RIS Tactical» к M4A1 прилагается ironsight2
-- (M4A1 Iron Sights). Раньше он висел на M4A1 ВСЕГДА через SWEP.StartAtt,
-- теперь — только когда установлен этот скин.
local SKIN_ATTACHMENTS = {
    m16_ris = {
        weapon_m4a1 = {"ironsight2"},
    },
}

-- Все атачменты, которые мы вообще можем выдавать ЛЮБЫМ скином —
-- собираем один раз для быстрой проверки "managed". Если такой атач сейчас
-- стоит на оружии и его не должно быть для текущего скина — снимаем.
local MANAGED_ATTS = {}
for _, byClass in pairs(SKIN_ATTACHMENTS) do
    for _, atts in pairs(byClass) do
        for _, a in ipairs(atts) do MANAGED_ATTS[a] = true end
    end
end

local function syncSkinAttachments(wep)
    if not IsValid(wep) then return end
    if not wep.attachments or not wep.availableAttachments then return end

    local class = wep:GetClass()
    local skinId = wep:GetNWString("zcity_skin", "")
    local wantedAtts = (SKIN_ATTACHMENTS[skinId] or {})[class] or {}

    local wantedSet = {}
    for _, a in ipairs(wantedAtts) do wantedSet[a] = true end

    -- Удалить managed-атачменты, которые сейчас стоят, но не нужны
    -- (то есть остались от предыдущего скина).
    local changed = false
    for placement, slot in pairs(wep.attachments) do
        local current = slot[1]
        if current and MANAGED_ATTS[current] and not wantedSet[current] then
            local empty = wep.availableAttachments[placement]
                       and wep.availableAttachments[placement]["empty"]
            wep.attachments[placement] = empty or {}
            changed = true
        end
    end

    -- Добавить нужные (если ещё не стоят)
    for _, att in ipairs(wantedAtts) do
        if hg and hg.SetAttachment then
            local before = wep.attachments.sight and wep.attachments.sight[1]
            hg.SetAttachment(wep.attachments, att, class)
            local after = wep.attachments.sight and wep.attachments.sight[1]
            if before ~= after then changed = true end
        end
    end

    if changed and wep.SetNetVar then
        wep:SetNetVar("attachments", wep.attachments)
    end
end

local function setWeaponNWSkin(wep, skinId)
    if not IsValid(wep) then return end
    if not skinId or skinId == "" or skinId == "default" then
        wep:SetNWString("zcity_skin", "")
    else
        wep:SetNWString("zcity_skin", skinId)
    end
    -- Синхронизируем homigrad-атачменты под новый скин.
    -- timer чтобы дать ClearAttachments (0.2с) отработать первым на свежеспавненном оружии.
    timer.Simple(0.3, function()
        if IsValid(wep) then syncSkinAttachments(wep) end
    end)
end

local function applyPrefToHeldWeapons(ply, weaponClass, skinId)
    if not IsValid(ply) then return end
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and wep:GetClass() == weaponClass then
            setWeaponNWSkin(wep, skinId)
        end
    end
end

-- Найти skinId, который игрок хочет иметь на оружии данного класса.
-- Сначала точное совпадение, потом любой класс из той же семьи.
local function findPrefSkinFor(ply, class)
    local sid = ply:SteamID()
    local skins = ZCity_PlayerSkins[sid]
    if not skins then return nil end
    if skins[class] then return skins[class] end
    if ZCITY_SKINS.FamilyOf then
        local _, family = ZCITY_SKINS.FamilyOf(class)
        if family then
            for _, w in ipairs(family) do
                if skins[w] then return skins[w] end
            end
        end
    end
    return nil
end

-- При подборе/выдаче оружия применяем пресет владельца, если есть.
-- Если у владельца нет пресета — НЕ трогаем NW-строку (скин предыдущего
-- владельца «остаётся» на оружии, что и нужно по требованию).
hook.Add("WeaponEquip", "zcity_skins_apply_on_equip", function(wep, ply)
    if not IsValid(wep) or not IsValid(ply) then return end
    local pref = findPrefSkinFor(ply, wep:GetClass())
    if pref then
        setWeaponNWSkin(wep, pref)
    end
end)

local function syncFullTo(ply)
    local data = ZCity_PlayerSkins or {}
    local lines = {}
    for _, target in ipairs(player.GetAll()) do
        local sid = target:SteamID()
        if data[sid] then
            for weaponClass, skinId in pairs(data[sid]) do
                table.insert(lines, { ply = target, w = weaponClass, s = skinId })
            end
        end
    end
    net.Start("zcity_skins_sync_all")
    net.WriteUInt(#lines, 16)
    for _, l in ipairs(lines) do
        net.WriteEntity(l.ply)
        net.WriteString(l.w)
        net.WriteString(l.s)
    end
    net.Send(ply)
end

-- Распространяет skin по всей семье оружия, если найден хотя бы один член.
-- Также чистит несовместимые комбинации (если скин не поддерживает класс — снимаем).
local function normalizeFamilies(data)
    if not istable(data) or not ZCITY_SKINS.Families then return data or {} end
    local skinSupportCache = {}
    local function supports(skinId, class)
        skinSupportCache[skinId] = skinSupportCache[skinId] or {}
        if skinSupportCache[skinId][class] ~= nil then return skinSupportCache[skinId][class] end
        local skin = findSkin(skinId)
        local ok = false
        if skin and skin.weapon then
            for _, w in ipairs(skin.weapon) do if w == class then ok = true break end end
        end
        skinSupportCache[skinId][class] = ok
        return ok
    end

    -- Для каждой семьи: если у любого члена есть skin — применим тот же ID к остальным
    -- (только тем, кто его поддерживает).
    for _, family in pairs(ZCITY_SKINS.Families) do
        local foundSkin = nil
        for _, w in ipairs(family) do
            if data[w] then foundSkin = data[w] break end
        end
        if foundSkin then
            for _, w in ipairs(family) do
                if supports(foundSkin, w) then
                    data[w] = foundSkin
                else
                    data[w] = nil
                end
            end
        end
    end
    return data
end

-- ─── Net handlers ────────────────────────────────────────────────────────────
net.Receive("zcity_skins_apply", function(_, ply)
    if not IsValid(ply) then return end
    local weaponClass = net.ReadString()
    local skinId      = net.ReadString()

    if #weaponClass > 64 or #skinId > 64 then return end
    local skin = findSkin(skinId)
    if not skin and skinId ~= "default" and not (skin and skin.isClear) then
        if ULib and ULib.tsayError then
            ULib.tsayError(ply, "Скин не найден.", true)
        else
            ply:ChatPrint("[Скины] Скин не найден.")
        end
        return
    end

    -- Семья оружия: применяем скин ко всем братьям/сёстрам разом
    local _, family = ZCITY_SKINS.FamilyOf(weaponClass)

    -- Default — снять скин (доступно всем)
    if skinId == "default" or (skin and skin.isClear) then
        local sid = ply:SteamID()
        ZCity_PlayerSkins[sid] = ZCity_PlayerSkins[sid] or {}
        for _, w in ipairs(family) do
            ZCity_PlayerSkins[sid][w] = nil
            syncOneToAll(ply, w, "default")
            applyPrefToHeldWeapons(ply, w, "default") -- сбрасываем NW-строку на оружии
        end
        saveToDisk(ply, ZCity_PlayerSkins[sid])
        ply:ChatPrint("[Скины] Скин снят со всего семейства " .. weaponClass)
        return
    end

    -- Не-default — VIP-only
    if not ZCITY_SKINS.IsVip(ply) then
        ply:ChatPrint("[Скины] Применять кастомные скины могут только VIP. /donate")
        return
    end

    -- Проверим что скин подходит хотя бы к одному оружию из семейства
    local fits = false
    for _, w in ipairs(skin.weapon or {}) do
        for _, fw in ipairs(family) do
            if w == fw then fits = true break end
        end
        if fits then break end
    end
    if not fits then
        ply:ChatPrint("[Скины] Этот скин не подходит к выбранному оружию.")
        return
    end

    local sid = ply:SteamID()
    ZCity_PlayerSkins[sid] = ZCity_PlayerSkins[sid] or {}
    -- Применяем skin ко всему семейству (только к тем классам, которые поддерживает скин)
    local skinSupports = {}
    for _, w in ipairs(skin.weapon or {}) do skinSupports[w] = true end
    local applied = 0
    for _, w in ipairs(family) do
        if skinSupports[w] then
            ZCity_PlayerSkins[sid][w] = skinId
            syncOneToAll(ply, w, skinId)
            applyPrefToHeldWeapons(ply, w, skinId) -- NW-строка на текущие весящие у игрока пушки
            applied = applied + 1
        end
    end
    saveToDisk(ply, ZCity_PlayerSkins[sid])
    ply:ChatPrint(string.format("[Скины] Применён «%s» (на %d оруж.)", skin.name or skinId, applied))
end)

-- При спавне игрока — догружаем с диска и отдаём всем клиентам
hook.Add("PlayerInitialSpawn", "zcity_skins_load", function(ply)
    if not IsValid(ply) then return end
    timer.Simple(2, function()
        if not IsValid(ply) then return end
        local data = loadFromDisk(ply)
        data = normalizeFamilies(data) -- расшариваем skin по семьям + чистим несовместимое
        ZCity_PlayerSkins[ply:SteamID()] = data
        saveToDisk(ply, data) -- сохраняем уже нормализованный вариант
        for weaponClass, skinId in pairs(data) do
            syncOneToAll(ply, weaponClass, skinId)
            applyPrefToHeldWeapons(ply, weaponClass, skinId) -- NW на уже выданные пушки
        end
        -- И отдаём текущий полный кеш — конкретному игроку
        syncFullTo(ply)
    end)
end)

hook.Add("PlayerDisconnected", "zcity_skins_save", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    saveToDisk(ply, ZCity_PlayerSkins[sid] or {})
end)

