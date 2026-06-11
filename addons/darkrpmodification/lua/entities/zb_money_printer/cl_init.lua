include("shared.lua")

function ENT:Draw()
    self:DrawModel()
    
    -- Отрисовка информации над принтером
    local pos = self:GetPos() + Vector(0, 0, 20)
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)
    
    local distance = LocalPlayer():GetPos():Distance(pos)
    if distance > 500 then return end
    
    local printerInfo = self:GetPrinterInfo()
    local money = self:GetNWInt("Money", 0)
    local ownerName = self:GetNWString("OwnerName", "Неизвестно")
    
    cam.Start3D2D(pos, Angle(0, ang.y, 90), 0.15)
        -- Фон (увеличенный)
        draw.RoundedBox(8, -150, -80, 300, 120, Color(0, 0, 0, 200))
        
        -- Название
        draw.SimpleText(printerInfo.name, "DermaLarge", 0, -50, printerInfo.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Деньги (увеличенный шрифт)
        draw.SimpleText("Деньги: $" .. money, "ChatFont", 0, -15, Color(100, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Владелец
        draw.SimpleText("Владелец: " .. ownerName, "DermaDefault", 0, 15, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
