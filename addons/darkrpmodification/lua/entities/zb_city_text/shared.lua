ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "City Text"
ENT.Author = "ZBattle"
ENT.Category = "ZBattle"

ENT.Spawnable = false
ENT.AdminOnly = true

-- Помечаем как постоянную энтити
ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "TextType") -- "rules" или "treasury"
end
