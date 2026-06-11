local CLASS = player.RegClass("isis")

-- Разрешённая одежда для игила (топ и штаны — одинаковый материал)
local ISISClothes = {
    "lonsdale_hoodie",
    "Lambda",
    "bomber_jacket1",
    "alpha_bomber",
    "golden_adidas",
    "russian_army",
    "tactical_outfit",
    "Army_Shirt",
    "camo_variant2",
    "leather_jacket",
}

function CLASS.Off(self)
    if CLIENT then return end
    -- Возвращаем оригинальный цвет одежды
    if self.ISISOriginalColor then
        self:SetPlayerColor(self.ISISOriginalColor)
        self:SetNWVector("PlayerColor", self.ISISOriginalColor)
        self.ISISOriginalColor = nil
    end
end

local masks = {
    "arctic_balaclava",
    "phoenix_balaclava",
}

function CLASS.On(self)
    if CLIENT then return end
    ApplyAppearance(self, nil, nil, nil, true)
    -- Используем уникальное имя таймера, чтобы отменить предыдущий вызов при быстрой смене
    local timerName = "isis_on_" .. self:EntIndex()
    timer.Create(timerName, 0.1, 1, function()
        if not IsValid(self) then return end

        local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()

        -- Балаклава + повязка игила
        Appearance.AAttachments = {
            masks[math.random(#masks)],
            "isis_band"
        }

        -- Одежда — случайная из разрешённого списка игила
        local chosen = ISISClothes[math.random(#ISISClothes)]
        Appearance.AClothes = Appearance.AClothes or {}
        Appearance.AClothes.main  = chosen
        Appearance.AClothes.pants = chosen

        -- Бодигруп ног — Boots Wider
        Appearance.ABodygroups = Appearance.ABodygroups or {}
        Appearance.ABodygroups["LEGS"] = "Boots Wider"

        -- Сохраняем оригинальный цвет и форсируем чёрный через AColor,
        -- чтобы ForceApplyAppearance не сбросил его обратно
        self.ISISOriginalColor = Vector(self:GetNWVector("PlayerColor", Vector(1, 1, 1)))
        Appearance.AColor = Color(0, 0, 0)

        -- Применяем всё за один раз (одежда + цвет + аксессуары + бодигрупы)
        hg.Appearance.ForceApplyAppearance(self, Appearance)
    end)
end

function CLASS.Guilt(self, victim)
    if CLIENT then return end

    if victim:GetPlayerClass() == self:GetPlayerClass() then
        return 1
    end

    if victim == zb.hostage then
        return 1
    end
end

hook.Add("HG_PlayerFootstep", "isis_footsteps", function(ply, pos, foot, sound, volume, rf)
    if ply:Alive() and ply.PlayerClassName == "isis" then
        local ent = hg.GetCurrentCharacter(ply)

        if not (ply:IsWalking() or ply:Crouching()) and ent == ply then
            local snd = "homigrad/" .. sound
            if SoundDuration(snd) <= 0 then
                snd = sound
            end

            EmitSound("homigrad/player/footsteps/new/bass_0" .. math.random(9) .. ".wav", pos, ply:EntIndex(), CHAN_AUTO, volume, 75, nil, changePitch(math.random(95, 105)))
            EmitSound(snd, pos, ply:EntIndex(), CHAN_AUTO, volume, 75, nil, changePitch(math.random(95, 105)))
        end
    end
end)
