if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_melee"
SWEP.PrintName = "Battering Ram"
SWEP.Instructions = "A powerful and heavy weapon that can crush doors. Use it to break down barricades and get through tight spaces.\n\nLMB to attack.\nRMB to block."
SWEP.Category = "Weapons - Melee"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Damage = 35
SWEP.DamageType = DMG_CLUB
SWEP.WorldModel = "models/weapons/custom/w_batram.mdl"
SWEP.WorldModelReal = "models/weapons/tfa_nmrih/v_me_sledge.mdl"
SWEP.WorldModelExchange = "models/weapons/custom/w_batram.mdl"
SWEP.DontChangeDropped = false
SWEP.ViewModel = ""

SWEP.HoldType = "slam"
SWEP.weight = 1.5

SWEP.HoldPos = Vector(-13,0,0)
SWEP.HoldAng = Angle(0,0,0)

SWEP.DamageType = DMG_CLUB
SWEP.DamagePrimary = 48

SWEP.PenetrationPrimary = 7

SWEP.MaxPenLen = 9

SWEP.PenetrationSizePrimary = 4

SWEP.StaminaPrimary = 55

SWEP.AttackTime = 0.5
SWEP.AnimTime1 = 1.4
SWEP.WaitTime1 = 1
SWEP.AttackLen1 = 60
SWEP.ViewPunch1 = Angle(1,2,0)

SWEP.attack_ang = Angle(0,0,0)
SWEP.sprint_ang = Angle(15,0,0)

SWEP.basebone = 94

SWEP.weaponPos = Vector(0,0,-6)
SWEP.weaponAng = Angle(0,0,-90)

SWEP.AnimList = {
    ["idle"] = "Idle",
    ["deploy"] = "Draw",
    ["attack"] = "Shove",
    ["attack2"] = "Shove",
}

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_ram")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_ram"
	SWEP.BounceWeaponIcon = false
end

SWEP.setlh = true
SWEP.setrh = true
SWEP.TwoHanded = true

SWEP.AttackHit = "Canister.ImpactHard"
SWEP.Attack2Hit = "Canister.ImpactHard"
SWEP.AttackHitFlesh = "Flesh.ImpactHard"
SWEP.Attack2HitFlesh = "Flesh.ImpactHard"
SWEP.DeploySnd = "physics/wood/wood_plank_impact_soft2.wav"

SWEP.AttackPos = Vector(0,0,0)

if SERVER then
    local function RestoreDoor(door)
        if not IsValid(door) then return end
        door:SetNoDraw(false)
        door:SetNotSolid(false)
        door:Fire("Unlock", "", 0)
        door:Fire("Close", "", 0)
        door.hg_door_blasted = nil

        -- Сбрасываем статус блокировки в zb.Doors. После сноса дверь
        -- физически открывалась через Fire("Open"), и если до сноса в
        -- данных стояло locked = true, то Q-меню продолжало бы показывать
        -- "Open Door", хотя дверь по факту разблокирована. Синхронизируем
        -- состояние и рассылаем клиентам, чтобы радиальное меню обновилось.
        if zb and zb.GetDoorData and zb.Doors then
            local data = zb.GetDoorData(door)
            if data then
                local keys = {}
                if data.groupID and zb.GetDoorsInGroup then
                    keys = zb.GetDoorsInGroup(data.groupID)
                else
                    local fp = zb.GetDoorFingerprint and zb.GetDoorFingerprint(door)
                    if fp and zb.GetDoorKey then
                        table.insert(keys, zb.GetDoorKey(fp))
                    end
                end

                for _, doorKey in ipairs(keys) do
                    local d = zb.Doors[doorKey]
                    if d then d.locked = false end
                end

                if zb.SaveDoors then zb.SaveDoors() end
                if zb.SendDoors then zb.SendDoors() end
            end
        end
    end

    local function ScheduleRestore(door, flyingProp)
        if not IsValid(door) then return end
        door.hg_door_blasted = true
        if IsValid(flyingProp) then
            timer.Simple(30, function()
                if IsValid(flyingProp) then flyingProp:Remove() end
                RestoreDoor(door)
            end)
        else
            timer.Simple(30, function()
                RestoreDoor(door)
            end)
        end
    end

    hook.Add("EntityTakeDamage", "hg_door_restore_on_damage", function(ent, dmginfo)
        if not IsValid(ent) then return end
        if ent:GetClass() ~= "prop_door_rotating" then return end
        if ent.hg_door_blasted then return end
        if not dmginfo:IsDamageType(DMG_BLAST) then return end

        local doorPos = ent:GetPos()
        local doorModel = ent:GetModel()
        timer.Simple(0.3, function()
            if not IsValid(ent) then return end
            local flyingProp
            for _, prop in ipairs(ents.FindInSphere(doorPos, 300)) do
                if IsValid(prop) and prop:GetClass() == "prop_physics" and prop:GetModel() == doorModel and not prop.hg_door_scheduled then
                    prop.hg_door_scheduled = true
                    flyingProp = prop
                    break
                end
            end
            ScheduleRestore(ent, flyingProp)
        end)
    end)

    -- Глобальная функция для вызова из PrimaryAttackAdd
    function HG_DoorBlasted(door)
        local doorPos = door:GetPos()
        local doorModel = door:GetModel()
        timer.Simple(0.3, function()
            if not IsValid(door) then return end
            local flyingProp
            for _, prop in ipairs(ents.FindInSphere(doorPos, 300)) do
                if IsValid(prop) and prop:GetClass() == "prop_physics" and prop:GetModel() == doorModel and not prop.hg_door_scheduled then
                    prop.hg_door_scheduled = true
                    flyingProp = prop
                    break
                end
            end
            ScheduleRestore(door, flyingProp)
        end)
    end
end

function SWEP:CustomBlockAnim(addPosLerp, addAngLerp)
	addPosLerp.z = addPosLerp.z + (self:GetBlocking() and 5 or 0)
	addPosLerp.x = addPosLerp.x + (self:GetBlocking() and -4 or 0)
	addPosLerp.y = addPosLerp.y + (self:GetBlocking() and 2 or 0)
	addAngLerp.r = addAngLerp.r + (self:GetBlocking() and -30 or 0)
    return true
end

function SWEP:SecondaryAttack()
end

function SWEP:PrimaryAttackAdd(ent, trace)
    if hgIsDoor(ent) and math.random(5) > 3 then
        hgBlastThatDoor(ent, self:GetOwner():GetAimVector() * 50 + self:GetOwner():GetVelocity())
    end

    local phys = ent:GetPhysicsObjectNum(trace.PhysicsBone)
    if phys and not ent:IsRagdoll() then
        phys:ApplyForceOffset(trace.Normal * 1000, trace.HitPos)
    end

    if ent:IsConstrained() and math.random(5) > 3 then
        constraint.RemoveAll(ent)
        ent:EmitSound("physics/wood/wood_furniture_break" .. math.random(1, 2) .. ".wav")
    end

    if SERVER and ent:GetClass() == "prop_door_rotating" then
        HG_DoorBlasted(ent)
    end
end

SWEP.AttackTimeLength = 0.01
SWEP.Attack2TimeLength = 0.1

SWEP.AttackRads = 0
SWEP.AttackRads2 = 0

SWEP.SwingAng = -90
SWEP.SwingAng2 = 0

SWEP.MinSensivity = 0.85
