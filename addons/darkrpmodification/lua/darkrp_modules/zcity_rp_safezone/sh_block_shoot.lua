--[[---------------------------------------------------------------------------
ZCity RP — блокировка стрельбы через хук ZCity_CanShoot
---------------------------------------------------------------------------
Используем:
  hook.Add("ZCity_CanShoot", "key", function(ply, weapon)
      if что-то then return false end -- блокирует выстрел
  end)

Реализация: оборачиваем homigrad_base SWEP:Shoot — это самая глубокая точка
которая контролирует всё (звук EmitShoot, эффект, FireBullet, репликацию через
net "hgwep shoot"). Если Shoot вернёт false — выстрел не происходит ни на
сервере ни на клиенте.

По умолчанию подключён один листенер: блокировка в safezone (rp_safezone NWBool).
---------------------------------------------------------------------------]]

local function wrapShoot(swepName)
    local sw = weapons.GetStored(swepName)
    if not sw then return end
    if sw._ZCity_ShootWrapped then return end

    local original = sw.Shoot
    if not original then return end

    sw.Shoot = function(self, override)
        local owner = self:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then
            local allowed = hook.Run("ZCity_CanShoot", owner, self)
            if allowed == false then
                -- Cooldown чтобы PrimaryAttack не вызывался каждый кадр
                if self.SetNextPrimaryFire then
                    self:SetNextPrimaryFire(CurTime() + 0.2)
                end
                return false -- homigrad_base уважает этот return false
            end
        end
        return original(self, override)
    end

    sw._ZCity_ShootWrapped = true
end

local function wrapAll()
    wrapShoot("homigrad_base")
    for _, swep in pairs(weapons.GetList()) do
        if swep.Base == "homigrad_base" or swep.ClassName == "homigrad_base" then
            wrapShoot(swep.ClassName)
        end
    end
end

hook.Add("InitPostEntity", "ZCity_RP_WrapShoot", wrapAll)
timer.Simple(0, wrapAll)
timer.Simple(2, wrapAll)

-- ============================================================================
-- Дефолтный листенер: запрет стрельбы в safezone
-- ============================================================================
hook.Add("ZCity_CanShoot", "ZCity_RP_BlockShootInSafezone", function(ply, weapon)
    if not IsValid(ply) then return end
    if ply:GetNWBool("rp_safezone", false) then
        return false
    end
end)

print("[ZCity RP] Weapon shoot block via SWEP:Shoot wrapper + safezone listener")
