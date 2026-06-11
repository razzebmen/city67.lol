include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local pos = self:GetPos() + Vector(0, 0, 75)
    local distance = LocalPlayer():GetPos():Distance(pos)
    if distance > 300 then return end

    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    local ownerName = self:GetOwnerName()

    cam.Start3D2D(pos, Angle(0, ang.y, 90), 0.18)
        draw.RoundedBox(8, -160, -45, 320, 90, Color(0, 0, 0, 200))

        draw.SimpleText("Магазин оружия", "DermaLarge", 0, -18,
            Color(255, 200, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local sub = ownerName ~= "" and ("Продавец: " .. ownerName) or "Нажмите E для покупки"
        draw.SimpleText(sub, "DermaLarge", 0, 18,
            Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
