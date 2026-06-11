--[[---------------------------------------------------------------------------
city67: weapon_bagmask
---------------------------------------------------------------------------
Тканевый мешок (надевается на голову цели).

UX:
* ЛКМ по игроку без мешка — надеть. Мешок исчезает из инвентаря.
* ЛКМ по игроку с мешком   — снять. Мешок остаётся в инвентаре, можно
                              использовать дальше.
* Без звука. Жест — стандартный slam-replace через AnimRestartGesture.
---------------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_base"
SWEP.PrintName = "Тканевый мешок"
SWEP.Instructions = "ЛКМ — надеть мешок на цель в радиусе 500u.\nЛКМ по цели с мешком — снять."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Wait = 2
SWEP.Primary.Next = 0
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/mdl/bag_prop.mdl"
if CLIENT then
	SWEP.WepSelectIcon    = Material("vgui/zcity_icons/wep_bag_mask")
	SWEP.IconOverride     = "vgui/zcity_icons/wep_bag_mask"
	SWEP.BounceWeaponIcon = false
end

SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Slot = 3
SWEP.SlotPos = 5
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(0, 0, -28)
SWEP.offsetAng = Angle(0, 0, 10)
SWEP.ModelScale = 1

-- Длительность жеста и задержка перед применением (sync со звуком/анимацией).
SWEP.ApplyDelay = 0.8
SWEP.CoolDownTime = 2

if SERVER then
	function SWEP:OnRemove() end
	-- net-строка регистрируется и в sv_zcity_bagmask.lua; дублирование безопасно
	util.AddNetworkString("zcity_bagmask_gesture")
end

if CLIENT then
	function SWEP:OnRemove()
		if IsValid(self.model) then self.model:Remove() end
	end
end

function SWEP:DrawWorldModel()
	local owner = self:GetOwner()

	-- Лежит на земле — рисуем как обычный prop
	if not IsValid(owner) then
		self:DrawModel()
		return
	end

	-- В руках — рисуем кастомным ClientsideModel, привязанным к ладони,
	-- с собственным offset/angle/scale (стандартный attachment "anim_attachment_RH"
	-- даёт неподходящую позу для prop-модели мешка).
	self.model = IsValid(self.model) and self.model or ClientsideModel(self.WorldModel)
	local WorldModel = self.model
	WorldModel:SetNoDraw(true)
	WorldModel:SetModelScale(self.ModelScale or 1)

	local boneName = "ValveBiped.Bip01_R_Hand"
	if (owner.organism and owner.organism.rarmamputated)
	   or (owner.zmanipstart ~= nil and owner.zmanipseq == "interact"
	       and owner.organism and not owner.organism.larmamputated) then
		boneName = "ValveBiped.Bip01_L_Hand"
	end
	local boneid = owner:LookupBone(boneName)
	if not boneid then return end
	local matrix = owner:GetBoneMatrix(boneid)
	if not matrix then return end

	local newPos, newAng = LocalToWorld(self.offsetVec, self.offsetAng,
	                                    matrix:GetTranslation(), matrix:GetAngles())
	WorldModel:SetPos(newPos)
	WorldModel:SetAngles(newAng)
	WorldModel:SetupBones()
	WorldModel:DrawModel()
end

function SWEP:SetHold(value)
	self:SetWeaponHoldType(value)
	self:SetHoldType(value)
	self.holdtype = value
end

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "Holding")
end

function SWEP:Animation()
end

function SWEP:Think()
	self:SetHold(self.HoldType)
end

SWEP.traceLen = 5
function SWEP:GetEyeTrace()
	if hg and hg.eyeTrace then
		return hg.eyeTrace(self:GetOwner()) or self:GetOwner():GetEyeTrace()
	end
	return self:GetOwner():GetEyeTrace()
end

if CLIENT then
	function SWEP:DrawHUD()
		if GetViewEntity() ~= LocalPlayer() then return end
		if LocalPlayer():InVehicle() then return end
		local tr = self:GetEyeTrace()
		if not tr or not tr.HitPos then return end
		local toScreen = tr.HitPos:ToScreen()
		surface.SetDrawColor(255,255,255,155)
		surface.DrawRect(toScreen.x-2.5, toScreen.y-2.5, 5, 5)
	end
end

function SWEP:SecondaryAttack()
end

function SWEP:Initialize()
	self:SetHold(self.HoldType)
end

-- ─── Применение / снятие ─────────────────────────────────────────────────────
SWEP.CoolDown = 0

local function resolveTarget(ent)
	if not IsValid(ent) then return nil end
	if ent:IsRagdoll() then
		local rOwner = hg and hg.RagdollOwner and hg.RagdollOwner(ent)
		if IsValid(rOwner) and rOwner:IsPlayer() and rOwner:Alive() then return rOwner end
		return nil
	end
	if ent:IsPlayer() and ent:Alive() then return ent end
	return nil
end

function SWEP:Bag(ent)
	if SERVER == false then return end
	local owner = self:GetOwner()
	if not (IsValid(self) and IsValid(owner) and owner:Alive()) then return end

	local target = resolveTarget(ent)
	if not IsValid(target) then return end
	if owner:GetPos():Distance(target:GetPos()) > 500 then return end

	if target == owner then
		owner:ChatPrint("[Мешок] Не сам себе. Используй zcity_bagmask_self.")
		return
	end

	-- Уже надет → снимаем. Мешок возвращается в инвентарь атакующего.
	if target:GetNWBool("bagmasked", false) then
		if zcity_bagmask and zcity_bagmask.Remove and zcity_bagmask.Remove(target, owner) then
			owner:ChatPrint("[Мешок] Снят с " .. target:Nick())
		else
			owner:ChatPrint("[Мешок] Не удалось снять.")
		end
		return
	end

	-- Не надет → надеваем и убираем мешок из инвентаря.
	if zcity_bagmask and zcity_bagmask.Apply and zcity_bagmask.Apply(target, owner) then
		owner:ChatPrint("[Мешок] Надет на " .. target:Nick())
		self:Remove()
	else
		owner:ChatPrint("[Мешок] Не удалось надеть.")
	end
end

function SWEP:PrimaryAttack()
	if CLIENT then return end
	if self.CoolDown > CurTime() then return end
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:Alive() then return end

	-- Проверим что в прицеле есть валидная цель — иначе не тратим cooldown/жест
	local tr = self:GetEyeTrace()
	if not tr or not IsValid(resolveTarget(tr.Entity)) then return end

	self.CoolDown = CurTime() + self.CoolDownTime
	self:SetNextPrimaryFire(CurTime() + self.CoolDownTime)

	-- Жест надевания: broadcast всем клиентам (включая самого игрока)
	net.Start("zcity_bagmask_gesture")
	net.WriteEntity(owner)
	net.Broadcast()

	-- Применяем с задержкой, чтобы успела отыграться анимация
	local wep = self
	timer.Simple(self.ApplyDelay, function()
		if not IsValid(wep) or not IsValid(owner) then return end
		if wep:GetOwner() ~= owner then return end
		-- Повторно трейсим в момент применения (цель могла отойти)
		local tr2 = wep:GetEyeTrace()
		if not tr2 then return end
		wep:Bag(tr2.Entity)
	end)
end

function SWEP:Reload()
end
