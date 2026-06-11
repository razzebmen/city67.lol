ENT.Type     = "anim"
ENT.Base     = "base_gmodentity"

ENT.PrintName = "Магазин оружия"
ENT.Author    = "ZBattle"
ENT.Category  = "ZBattle"
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "OwnerID")    -- SteamID владельца (продавца)
    self:NetworkVar("String", 1, "OwnerName")  -- Имя продавца
end
