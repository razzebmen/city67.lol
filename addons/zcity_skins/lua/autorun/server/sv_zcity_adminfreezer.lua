if not SERVER then return end

zcity_adminfreezer = zcity_adminfreezer or {}

util.AddNetworkString("zcity_adminfreezer_freeze")
util.AddNetworkString("zcity_adminfreezer_unfreeze")
util.AddNetworkString("zcity_adminfreezer_request") -- от клиента: "PRM по цели"

local ALLOWED_RANKS = {
    dmoderator  = true,
    moderator   = true,
    dadmin      = true,
    admin       = true,
    superadmin  = true,
    dsuperadmin = true,
}

function zcity_adminfreezer.CanFreeze(ply)
    if not IsValid(ply) then return false end
    return ALLOWED_RANKS[ply:GetUserGroup()] == true or ply:IsSuperAdmin()
end

function zcity_adminfreezer.Freeze(target, by)
    if not IsValid(target) then return false end
    if target:GetNWBool("admin_frozen", false) then return false end

    target:SetNWBool("admin_frozen", true)
    target:SetMoveType(MOVETYPE_NONE)
    target:SetLocalVelocity(Vector(0, 0, 0))

    net.Start("zcity_adminfreezer_freeze")
    net.WriteAngle(target:EyeAngles())
    net.Send(target)

    if IsValid(by) then
        by:ChatPrint("[Заморозка] Заморожен: " .. target:Nick())
    end
    target:ChatPrint("[Заморозка] Вас заморозил администратор.")
    return true
end

function zcity_adminfreezer.Unfreeze(target, by)
    if not IsValid(target) then return false end
    if not target:GetNWBool("admin_frozen", false) then return false end

    target:SetNWBool("admin_frozen", false)
    target:SetMoveType(MOVETYPE_WALK)

    net.Start("zcity_adminfreezer_unfreeze")
    net.Send(target)

    if IsValid(by) then
        by:ChatPrint("[Заморозка] Разморожен: " .. target:Nick())
    end
    target:ChatPrint("[Заморозка] Заморозка снята.")
    return true
end

-- Поддерживаем нулевую скорость каждый тик пока заморожен
hook.Add("PlayerTick", "zcity_adminfreezer_zero", function(ply, mv)
    if not ply:GetNWBool("admin_frozen", false) then return end
    mv:SetVelocity(Vector(0, 0, 0))
    mv:SetMaxClientSpeed(0)
    mv:SetMaxSpeed(0)
end)

local function cleanup(ply)
    if ply:GetNWBool("admin_frozen", false) then
        zcity_adminfreezer.Unfreeze(ply)
    end
end

hook.Add("PlayerDeath",         "zcity_adminfreezer_death",  cleanup)
hook.Add("PlayerSpawn",         "zcity_adminfreezer_spawn",  cleanup)
hook.Add("PlayerDisconnected",  "zcity_adminfreezer_dc",     cleanup)

-- Принимаем запросы от клиента (legacy) — оставлен для совместимости.
local lastRequest = {}
net.Receive("zcity_adminfreezer_request", function(_, ply)
    if not IsValid(ply) then return end
    if not zcity_adminfreezer.CanFreeze(ply) then return end

    -- Анти-спам: не чаще чем раз в 0.4с
    local now = CurTime()
    if (lastRequest[ply] or 0) + 0.4 > now then return end
    lastRequest[ply] = now

    local tr = ply:GetEyeTrace()
    if not tr or not IsValid(tr.Entity) or not tr.Entity:IsPlayer() then return end
    local target = tr.Entity
    if target == ply then return end
    if ply:GetPos():DistToSqr(target:GetPos()) > 600 * 600 then return end

    if target:GetNWBool("admin_frozen", false) then
        zcity_adminfreezer.Unfreeze(target, ply)
    else
        zcity_adminfreezer.Freeze(target, ply)
    end
end)

-- ─── Физган: ЛКМ удерживается + ПКМ нажат — freeze/unfreeze игрока ──────────
-- Работает как стандартный physgun-freeze на пропах:
--   1) Админ наводит физган на игрока.
--   2) Зажимает ЛКМ (как будто хочет утащить).
--   3) Нажимает ПКМ — цель замораживается. Повторно ПКМ — размораживает.
hook.Add("KeyPress", "zcity_adminfreezer_physgun", function(ply, key)
    if key ~= IN_ATTACK2 then return end
    if not IsValid(ply) or not ply:Alive() then return end
    if not zcity_adminfreezer.CanFreeze(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "weapon_physgun" then return end
    if not ply:KeyDown(IN_ATTACK) then return end -- ЛКМ должна удерживаться

    local now = CurTime()
    if (lastRequest[ply] or 0) + 0.25 > now then return end
    lastRequest[ply] = now

    local tr = ply:GetEyeTrace()
    if not tr or not IsValid(tr.Entity) or not tr.Entity:IsPlayer() then return end
    local target = tr.Entity
    if target == ply then return end
    if ply:GetPos():DistToSqr(target:GetPos()) > 4096 * 4096 then return end -- стандартный physgun reach

    if target:GetNWBool("admin_frozen", false) then
        zcity_adminfreezer.Unfreeze(target, ply)
    else
        zcity_adminfreezer.Freeze(target, ply)
    end
end)


-- ─── Синхронизация с c-меню (properties.Add("freeze")) ───────────────────────
-- C-меню вызывает  ent:Freeze(not ent:IsFrozen())  для player'а.
-- Стандартный Player:Freeze(b) лишь добавляет/снимает FL_FROZEN флаг и не
-- блокирует камеру. Перехватываем метод: при вызове .Freeze(true) на player
-- запускаем нашу полноценную систему (CalcView lock, MoveType, NW); при
-- .Freeze(false) — снимаем.
--
-- IsFrozen тоже подменяем: возвращает true и для нашего NWBool тоже,
-- чтобы c-меню Filter правильно показывал "Unfreeze" когда игрок заморожен
-- через physgun или /api.

local plyMeta = FindMetaTable("Player")
if plyMeta and not plyMeta._zcity_origFreeze then
    plyMeta._zcity_origFreeze   = plyMeta.Freeze
    plyMeta._zcity_origIsFrozen = plyMeta.IsFrozen

    function plyMeta:Freeze(b)
        if b then
            -- Если уже в нашем замороженном состоянии — ничего.
            if self:GetNWBool("admin_frozen", false) then
                self:_zcity_origFreeze(true)
                return
            end
            zcity_adminfreezer.Freeze(self, nil)
        else
            if self:GetNWBool("admin_frozen", false) then
                zcity_adminfreezer.Unfreeze(self, nil)
            else
                self:_zcity_origFreeze(false)
            end
        end
    end

    function plyMeta:IsFrozen()
        if self:GetNWBool("admin_frozen", false) then return true end
        return self:_zcity_origIsFrozen()
    end
end

-- Внутри нашего Freeze также ставим стандартный FL_FROZEN, чтобы любой код
-- который проверяет IsFrozen() (включая мониторинг сторонних аддонов) видел
-- консистентное состояние.
local origFreeze   = zcity_adminfreezer.Freeze
local origUnfreeze = zcity_adminfreezer.Unfreeze

function zcity_adminfreezer.Freeze(target, by)
    local ok = origFreeze(target, by)
    if ok and IsValid(target) and target._zcity_origFreeze then
        target:_zcity_origFreeze(true) -- стандартный FL_FROZEN
    end
    return ok
end

function zcity_adminfreezer.Unfreeze(target, by)
    local ok = origUnfreeze(target, by)
    if ok and IsValid(target) and target._zcity_origFreeze then
        target:_zcity_origFreeze(false)
    end
    return ok
end
