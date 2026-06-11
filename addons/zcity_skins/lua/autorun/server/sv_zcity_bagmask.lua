--[[---------------------------------------------------------------------------
city67 — Тканевый мешок (sv)
---------------------------------------------------------------------------
API:
    zcity_bagmask.Apply(target, by)    — надеть мешок на target
    zcity_bagmask.Remove(target, by)   — снять мешок; by получит weapon_bagmask обратно

Рендер — клиентский (PostPlayerDraw в cl_zcity_bagmask.lua).

Калибровка позиции мешка:
    bagmask_self      — надеть/снять на себя (дебаг)
    bagmask_calibrate — спаунит физган-проп bag_prop на голове цели
    bagmask_save      — сохраняет смещение проппа относительно кости головы
---------------------------------------------------------------------------]]
if not SERVER then return end

zcity_bagmask = zcity_bagmask or {}

print("[zcity_bagmask] sv loaded")

util.AddNetworkString("zcity_bagmask_clear")       -- клиенту: снять затемнение
util.AddNetworkString("zcity_bagmask_request")     -- от клиента: снять через Q-меню
util.AddNetworkString("zcity_bagmask_gesture")     -- клиентам: сыграть жест
util.AddNetworkString("zcity_bagmask_debug")       -- от клиента: надеть/снять на себя
util.AddNetworkString("zcity_bagmask_calib_done")  -- сервер → клиент: данные для сохранения

-- ─── Применить ───────────────────────────────────────────────────────────────
function zcity_bagmask.Apply(target, by)
    if not IsValid(target) then return false end
    if target:GetNWBool("bagmasked", false) then return false end

    target:SetNWBool("bagmasked", true)
    target:SetNWEntity("bagmasked_by", IsValid(by) and by or NULL)
    return true
end

-- ─── Снять ───────────────────────────────────────────────────────────────────
-- by: игрок, который снял — получит weapon_bagmask обратно.
-- Не передавать by при автоочистке (смерть, спавн, дисконнект).
function zcity_bagmask.Remove(target, by)
    if not IsValid(target) then return false end
    if not target:GetNWBool("bagmasked", false) then return false end

    target:SetNWBool("bagmasked", false)
    target:SetNWEntity("bagmasked_by", NULL)

    -- Возвращаем мешок тому, кто снял
    if IsValid(by) and by:IsPlayer() and by ~= target then
        by:Give("weapon_bagmask")
    end

    if target:IsPlayer() then
        net.Start("zcity_bagmask_clear")
        net.Send(target)
    end
    return true
end

-- ─── Дебаг: надеть/снять на себя ─────────────────────────────────────────────
net.Receive("zcity_bagmask_debug", function(_, ply)
    if not IsValid(ply) then return end
    if ply:GetNWBool("bagmasked", false) then
        zcity_bagmask.Remove(ply)
        ply:ChatPrint("[Мешок] Снят с себя.")
    else
        zcity_bagmask.Apply(ply, ply)
        ply:ChatPrint("[Мешок] Надет на себя. (у тебя черный экран — это нормально для теста)")
    end
end)

-- ─── Q-меню: снять с цели ────────────────────────────────────────────────────
net.Receive("zcity_bagmask_request", function(_, ply)
    if not IsValid(ply) then return end
    local mode = net.ReadString()
    if mode == "trace" then
        local tr = ply:GetEyeTrace()
        local target = tr.Entity
        if IsValid(target) and target:IsPlayer()
           and target:GetNWBool("bagmasked", false)
           and ply:GetPos():Distance(target:GetPos()) < 200 then
            zcity_bagmask.Remove(target, ply)
            ply:ChatPrint("[Мешок] Снят с " .. target:Nick())
        end
    end
end)

-- ─── Физган-калибровка ────────────────────────────────────────────────────────
-- Шаг 1: bagmask_calibrate — спаунит физган-проп рядом с головой цели.
-- Шаг 2: двигай проп физганом куда нужно.
-- Шаг 3: bagmask_save — отправляет данные клиенту, клиент считает offset и сохраняет.
--
-- Цель: игрок в прицеле вызывающего (любой, смотреть на него необязательно быть bagged).
-- Если в прицеле не игрок — ищем ближайшего с мешком.

zcity_bagmask.calibProp   = nil
zcity_bagmask.calibTarget = nil
zcity_bagmask.calibUser   = nil

concommand.Add("bagmask_calibrate", function(ply)
    if not IsValid(ply) then return end

    -- Удалить старый проп если был
    if IsValid(zcity_bagmask.calibProp) then zcity_bagmask.calibProp:Remove() end

    -- Найти цель: смотрим в прицел, иначе ближайший bagged
    local target
    local tr = ply:GetEyeTrace()
    if IsValid(tr.Entity) and tr.Entity:IsPlayer() then
        target = tr.Entity
    else
        local best, bestDist = nil, math.huge
        for _, p in ipairs(player.GetAll()) do
            local d = ply:GetPos():DistToSqr(p:GetPos())
            if p ~= ply and d < bestDist then
                best, bestDist = p, d
            end
        end
        target = best
    end

    if not IsValid(target) then
        ply:ChatPrint("[Мешок] Нет цели. Смотри на игрока или встань рядом.")
        return
    end

    -- Примерная позиция головы: origin + 68 units вверх
    local headPos = target:GetPos() + Vector(0, 0, 68)

    -- prop_physics, но без коллизий и с замороженной физикой —
    -- физган может двигать, но проп не падает и не сталкивается с
    -- головой персонажа (раньше из-за SOLID_VPHYSICS его «отталкивало»).
    local prop = ents.Create("prop_physics")
    prop:SetModel("models/mdl/bag_prop.mdl")
    prop:SetPos(headPos)
    prop:SetAngles(target:GetAngles())
    prop:Spawn()
    prop:SetCollisionGroup(COLLISION_GROUP_WORLD) -- не сталкивается с игроками
    prop:DrawShadow(false)
    local phys = prop:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end

    zcity_bagmask.calibProp   = prop
    zcity_bagmask.calibTarget = target
    zcity_bagmask.calibUser   = ply

    -- При отпускании физгана заморозить обратно
    prop.zcity_calib = true

    ply:ChatPrint("[Мешок] Проп создан на голове " .. target:Nick() ..
        ". Физганом поставь на нужное место, потом: bagmask_save")
end)

-- Заморозка проппа при отпускании физгана (чтобы не падал/не двигался дальше)
hook.Add("PhysgunDrop", "zcity_bagmask_calib_freeze", function(ply, ent)
    if not IsValid(ent) or not ent.zcity_calib then return end
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end
end)

concommand.Add("bagmask_save", function(ply)
    if not IsValid(ply) then return end
    if not IsValid(zcity_bagmask.calibProp) then
        ply:ChatPrint("[Мешок] Нет калибровочного проппа. Запусти bagmask_calibrate.")
        return
    end
    if not IsValid(zcity_bagmask.calibTarget) then
        ply:ChatPrint("[Мешок] Цель исчезла. Запусти bagmask_calibrate заново.")
        return
    end

    -- Шлём клиенту: позицию и угол проппа + entity цели.
    -- Клиент посчитает WorldToLocal относительно кости головы (кости анимированы на клиенте).
    net.Start("zcity_bagmask_calib_done")
    net.WriteVector(zcity_bagmask.calibProp:GetPos())
    net.WriteAngle(zcity_bagmask.calibProp:GetAngles())
    net.WriteEntity(zcity_bagmask.calibTarget)
    net.Send(ply)

    zcity_bagmask.calibProp:Remove()
    zcity_bagmask.calibProp   = nil
    zcity_bagmask.calibTarget = nil
    zcity_bagmask.calibUser   = nil

    ply:ChatPrint("[Мешок] Данные отправлены. Смещение сохранено в ConVar.")
end)

-- ─── Очистка при смерти/респе/дисконнекте ────────────────────────────────────
hook.Add("PlayerDeath", "zcity_bagmask_death", function(ply)
    if ply:GetNWBool("bagmasked", false) then zcity_bagmask.Remove(ply) end
end)

hook.Add("PlayerSpawn", "zcity_bagmask_spawn", function(ply)
    if ply:GetNWBool("bagmasked", false) then zcity_bagmask.Remove(ply) end
end)

hook.Add("PlayerDisconnected", "zcity_bagmask_dc", function(ply)
    if ply:GetNWBool("bagmasked", false) then zcity_bagmask.Remove(ply) end
end)

-- ─── Авто-выдача ЦАХАЛу ──────────────────────────────────────────────────────
hook.Add("PlayerLoadout", "zcity_bagmask_giveISIS", function(ply)
    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        local job = ply:GetNWString("RoleplayJob", "")
        if job == "Солдат ЦАХАЛ" or job == "Глава ЦАХАЛ" then
            if not ply:HasWeapon("weapon_bagmask") then
                ply:Give("weapon_bagmask")
            end
        end
    end)
end)

-- ─── Resource ────────────────────────────────────────────────────────────────
resource.AddFile("models/mdl/bag_prop.mdl")
resource.AddFile("models/mdl/bag_prop.dx80.vtx")
resource.AddFile("models/mdl/bag_prop.dx90.vtx")
resource.AddFile("models/mdl/bag_prop.phy")
resource.AddFile("models/mdl/bag_prop.vvd")
resource.AddFile("materials/mats/bag_prop/bag_mat.vmt")
resource.AddFile("materials/mats/bag_prop/bag_mat.vtf")
resource.AddFile("materials/mats/bag_prop/bag_mat_2.vmt")
resource.AddFile("materials/mats/bag_prop/bag_mat_2.vtf")
resource.AddFile("materials/mats/bag_prop/bag_mat_normal.vtf")
resource.AddFile("materials/vgui/zcity_icons/wep_bag_mask.vmt")
resource.AddFile("materials/vgui/zcity_icons/wep_bag_mask.vtf")
