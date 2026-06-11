ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Мани Принтер"
ENT.Author = "ZBattle"
ENT.Category = "ZBattle"
ENT.Spawnable = false
ENT.AdminOnly = false

-- Типы принтеров
ENT.PrinterTypes = {
    basic = {
        name = "Обычный принтер",
        moneyPerTick = 10,
        price = 500,
        color = Color(100, 100, 100)
    },
    medium = {
        name = "Средний принтер",
        moneyPerTick = 25,
        price = 1000,
        color = Color(100, 150, 255)
    },
    advanced = {
        name = "Улучшенный принтер",
        moneyPerTick = 50,
        price = 1500,
        color = Color(255, 200, 100)
    }
}

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "PrinterType")
    self:NetworkVar("Int", 0, "Health")
end

function ENT:Initialize()
    if SERVER then
        self:SetHealth(100)
    end
end

function ENT:GetPrinterInfo()
    local printerType = self:GetPrinterType()
    return self.PrinterTypes[printerType] or self.PrinterTypes.basic
end
