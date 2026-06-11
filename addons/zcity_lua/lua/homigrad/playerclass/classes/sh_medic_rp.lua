local CLASS = player.RegClass("medic_rp")

local MedicClothes = {
    "Office_Worker",
    "worker",
    "striped",
    "sweater_xmas",
    "medic1",
}

local MedicPants = {
    "worker",
    "sweater_xmas",
    "casual",
}

function CLASS.On(self)
    if CLIENT then return end
    ApplyAppearance(self, nil, nil, nil, true)
    local timerName = "medic_rp_on_" .. self:EntIndex()
    timer.Create(timerName, 0.1, 1, function()
        if not IsValid(self) then return end

        local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()

        -- Сохраняем оригинальный цвет и форсируем белый для одежды
        self.MedicOriginalColor = Vector(self:GetNWVector("PlayerColor", Vector(1, 1, 1)))
        Appearance.AColor = Color(255, 255, 255)

        Appearance.AClothes       = Appearance.AClothes or {}
        Appearance.AClothes.main  = MedicClothes[math.random(#MedicClothes)]
        Appearance.AClothes.pants = MedicPants[math.random(#MedicPants)]
        Appearance.AClothes.hands = "medical_gloves"
        Appearance.AAttachments   = {"cap nurse", "medic_band"}

        hg.Appearance.ForceApplyAppearance(self, Appearance)
    end)
end

function CLASS.Off(self)
    if CLIENT then return end
    if self.MedicOriginalColor then
        self:SetPlayerColor(self.MedicOriginalColor)
        self:SetNWVector("PlayerColor", self.MedicOriginalColor)
        self.MedicOriginalColor = nil
    end
end
