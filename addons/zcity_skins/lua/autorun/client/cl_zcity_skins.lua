--[[---------------------------------------------------------------------------
ZCity Skins — клиентская часть
---------------------------------------------------------------------------
* Принимает sync от сервера и хранит ZCity_ClientSkins[steamid][weapon] = skinId.
* На каждый кадр для view-model и world-model оружия применяет SubMaterial,
  если у владельца установлен скин для этого класса.
---------------------------------------------------------------------------]]
if not CLIENT then return end

-- sh_config.lua уже включён через sh_zcity_skins_loader.lua (autorun/sh_*).

ZCity_ClientSkins = ZCity_ClientSkins or {}

local function setSkinFor(plySid, weaponClass, skinId)
    ZCity_ClientSkins[plySid] = ZCity_ClientSkins[plySid] or {}
    if not skinId or skinId == "" or skinId == "default" then
        ZCity_ClientSkins[plySid][weaponClass] = nil
    else
        ZCity_ClientSkins[plySid][weaponClass] = skinId
    end
end

net.Receive("zcity_skins_sync_one", function()
    local ply = net.ReadEntity()
    local w   = net.ReadString()
    local s   = net.ReadString()
    if IsValid(ply) then
        setSkinFor(ply:SteamID(), w, s)
    end
end)

net.Receive("zcity_skins_sync_all", function()
    local n = net.ReadUInt(16)
    for i = 1, n do
        local ply = net.ReadEntity()
        local w   = net.ReadString()
        local s   = net.ReadString()
        if IsValid(ply) then
            setSkinFor(ply:SteamID(), w, s)
        end
    end
end)

-- ─── Применение SubMaterial ──────────────────────────────────────────────────
local function findSkinDef(id)
    for _, s in ipairs(ZCITY_SKINS.List) do
        if s.id == id then return s end
    end
    return nil
end

-- Получить применённый skinId для оружия игрока с fallback по семье:
--   1) точное совпадение по weaponClass
--   2) любой класс из той же семьи (FamilyOf)
local function getSkinIdFor(plySid, weaponClass)
    local cache = ZCity_ClientSkins[plySid]
    if not cache then return nil end
    local id = cache[weaponClass]
    if id then return id end
    if not ZCITY_SKINS.FamilyOf then return nil end
    local _, family = ZCITY_SKINS.FamilyOf(weaponClass)
    if not family then return nil end
    for _, w in ipairs(family) do
        if cache[w] then return cache[w] end
    end
    return nil
end

-- Source поддерживает до 32 sub-материалов на модели. Раньше тут было 0..15,
-- из-за чего у моделей с большим количеством материалов (например ArcCW
-- c_ud_m16 — там приклад сидит в slot'ах 20/22/24) приклад/прицел оставались
-- в дефолтной окраске.
local MAX_SUBMATERIALS = 31

local function applySubMaterial(ent, skin)
    if not IsValid(ent) or not skin or not skin.material then return end
    local mat = skin.material
    if not skin.submat then
        for i = 0, MAX_SUBMATERIALS do ent:SetSubMaterial(i, mat) end
        return
    end
    if isnumber(skin.submat) then
        ent:SetSubMaterial(skin.submat, mat)
        return
    end
    for _, idx in ipairs(skin.submat) do
        ent:SetSubMaterial(idx, mat)
    end
end

local function clearSubs(ent)
    if not IsValid(ent) then return end
    for i = 0, MAX_SUBMATERIALS do ent:SetSubMaterial(i) end
end

-- Helper — применить состояние скина к view/world-model
local function applyStateToEnt(ent, ply, class, wepEnt)
    if not IsValid(ent) or not IsValid(ply) then return end
    local sid = ply:SteamID()

    -- 1) Авто-скин (по работе/классу/группе) имеет приоритет над выбираемым.
    --    Возвращает путь к материалу (или nil — нет авто-правила).
    local autoMat = nil
    local autoFn = ZCITY_SKINS.AutoSkins and ZCITY_SKINS.AutoSkins[class]
    if autoFn then
        local ok, res = pcall(autoFn, ply)
        if ok then autoMat = res end
    end

    if autoMat then
        local autoTag = "auto:" .. autoMat
        if ent.zcity_skin_applied == autoTag then return end
        clearSubs(ent)
        for i = 0, 15 do ent:SetSubMaterial(i, autoMat) end
        ent.zcity_skin_applied = autoTag
        return
    end

    -- 2) NW-строка на самом weapon-энтити — приоритет над PlayerSkins.
    --    Это позволяет скину «прилипать» к оружию после drop/pickup другим
    --    игроком (NW реплицируется движком всем клиентам).
    local skinId
    local nwSource = wepEnt
    if not IsValid(nwSource) and ent.GetNWString then nwSource = ent end
    if IsValid(nwSource) and nwSource.GetNWString then
        local s = nwSource:GetNWString("zcity_skin", "")
        if s and s ~= "" then skinId = s end
    end

    -- 3) Fallback: выбираемый скин из ZCity_ClientSkins (PlayerSkins).
    skinId = skinId or getSkinIdFor(sid, class)
    if skinId then
        local skin = findSkinDef(skinId)
        if skin and skin.weapon then
            local fits = false
            for _, w in ipairs(skin.weapon) do
                if w == class then fits = true break end
            end
            if not fits then skinId = nil end
        end
    end
    if not skinId then
        if ent.zcity_skin_applied then
            clearSubs(ent)
            ent.zcity_skin_applied = nil
        end
        return
    end
    if ent.zcity_skin_applied == skinId then return end
    clearSubs(ent)
    local skin = findSkinDef(skinId)
    if not skin then return end
    applySubMaterial(ent, skin)
    ent.zcity_skin_applied = skinId
end

-- View model owner = LocalPlayer; обходим vmodels раз в кадр.
-- Передаём `weapon` как источник NW-строки скина.
hook.Add("PostDrawViewModel", "zcity_skins_vm", function(vm, ply, weapon)
    if not IsValid(weapon) or not IsValid(ply) then return end
    applyStateToEnt(vm, ply, weapon:GetClass(), weapon)
end)

-- World model — пробегаем по игрокам и их активным weapon.
-- Все sub-энтити (FakeWorldModel, worldModel, model, NPCworldModel) получают
-- `wep` как источник NW-строки — иначе они смотрели бы на собственный
-- (несуществующий) NW.
local nextScan = 0
hook.Add("Think", "zcity_skins_wm", function()
    if CurTime() < nextScan then return end
    nextScan = CurTime() + 0.4
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) then continue end
        local class = wep:GetClass()
        applyStateToEnt(wep, ply, class, wep)
        if wep.GetWM and IsValid(wep:GetWM()) then
            applyStateToEnt(wep:GetWM(), ply, class, wep)
        end
        if wep.worldModel and IsValid(wep.worldModel) then
            applyStateToEnt(wep.worldModel, ply, class, wep)
        end
        if wep.worldModel2 and IsValid(wep.worldModel2) then
            applyStateToEnt(wep.worldModel2, ply, class, wep)
        end
        if wep.model and IsValid(wep.model) then
            applyStateToEnt(wep.model, ply, class, wep)
        end
        if wep.NPCworldModel and IsValid(wep.NPCworldModel) then
            applyStateToEnt(wep.NPCworldModel, ply, class, wep)
        end
    end
end)

-- Поддержка старого fix: при запросе данных с сервера в первый раз
hook.Add("InitPostEntity", "zcity_skins_request", function()
    -- сервер сам пушит sync_all, тут ничего делать не нужно
end)

