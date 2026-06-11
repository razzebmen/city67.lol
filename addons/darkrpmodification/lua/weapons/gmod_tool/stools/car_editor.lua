TOOL.Category = "ZBattle"
TOOL.Name = "Car Editor"

TOOL.ClientConVar["car_type"] = "sim_fphys_l4d_police_city2"

function TOOL:LeftClick(trace)
    local ply = self:GetOwner()
    if not ply:IsAdmin() then
        if CLIENT then
            ply:ChatPrint("Только для администраторов")
        end
        return false
    end
    
    if SERVER then
        local carType = ply:GetInfo(self:GetMode() .. "_car_type")
        
        -- Проверяем, что тип машины существует
        if not zb.CarTypes[carType] then
            ply:ChatPrint("Неизвестный тип машины: " .. carType)
            return false
        end
        
        -- Создаем точку спавна
        local pos = trace.HitPos + trace.HitNormal * 50
        local angles = ply:EyeAngles()
        angles.pitch = 0
        angles.roll = 0
        
        local id = zb.AddCarSpawn(pos, angles, carType)
        
        local carInfo = zb.CarTypes[carType]
        ply:ChatPrint("Точка спавна создана: " .. carInfo.name .. " (ID: " .. id .. ")")
        
        -- Отправляем обновление всем
        zb.SendCarSpawns()
    end
    
    return true
end

function TOOL:RightClick(trace)
    local ply = self:GetOwner()
    if not ply:IsAdmin() then
        if CLIENT then
            ply:ChatPrint("Только для администраторов")
        end
        return false
    end
    
    if SERVER then
        -- Ищем ближайшую точку спавна
        local nearestID = nil
        local nearestDist = 200
        
        for id, spawn in pairs(zb.CarSpawns) do
            local dist = trace.HitPos:Distance(spawn.pos)
            if dist < nearestDist then
                nearestID = id
                nearestDist = dist
            end
        end
        
        if nearestID then
            local carInfo = zb.CarTypes[zb.CarSpawns[nearestID].carType]
            zb.RemoveCarSpawn(nearestID)
            ply:ChatPrint("Точка спавна удалена: " .. (carInfo and carInfo.name or "Unknown"))
            
            -- Отправляем обновление всем
            zb.SendCarSpawns()
        else
            ply:ChatPrint("Точка спавна не найдена рядом")
        end
    end
    
    return true
end

function TOOL:Reload()
    local ply = self:GetOwner()
    if not ply:IsAdmin() then return false end
    
    if SERVER then
        ply:ChatPrint("[Car Editor] Респавн всех машин...")
        print("[ZBattle] Всего точек спавна: " .. table.Count(zb.CarSpawns))
        
        -- Респавн всех машин
        local count = 0
        for id, spawn in pairs(zb.CarSpawns) do
            print("[ZBattle] Респавн машины #" .. id)
            zb.SpawnCar(id)
            count = count + 1
        end
        
        ply:ChatPrint("[Car Editor] Респавнено машин: " .. count)
    end
    
    return true
end

function TOOL.BuildCPanel(CPanel)
    CPanel:AddControl("Header", {
        Description = "ЛКМ - создать точку спавна\nПКМ - удалить ближайшую точку\nR - респавнить все машины"
    })
    
    local combo = CPanel:AddControl("ComboBox", {
        Label = "Тип машины",
        MenuButton = 0,
        Options = {
            ["Police Car (Полиция)"] = {car_editor_car_type = "sim_fphys_l4d_police_city2"},
            ["HMMWV (ЦАХАЛ)"] = {car_editor_car_type = "sim_fphys_l4d_hmmwv"},
            ["Pickup 78 (ЦАХАЛ 2)"] = {car_editor_car_type = "sim_fphys_l4d_pickup_b_78"},
            ["Crown Victoria (Мэрия)"] = {car_editor_car_type = "sim_fphys_l4d_crownvic"}
        }
    })
end

function TOOL:Allowed()
    return self:GetOwner():IsAdmin()
end

function TOOL:Deploy()
    if SERVER then
        local ply = self:GetOwner()
        zb.SendCarSpawns(ply)
    end
end

-- Отрисовка HUD
function TOOL:DrawHUD()
    local lply = LocalPlayer()
    if not lply:IsAdmin() then return end
    
    -- Отрисовываем все точки спавна
    for id, spawn in pairs(zb.ClCarSpawns or {}) do
        local carInfo = zb.CarTypes[spawn.carType]
        if not carInfo then continue end
        
        local pos = spawn.pos
        local data = pos:ToScreen()
        if not data.visible then continue end
        
        local distance = lply:GetPos():Distance(pos)
        local factor = 1 - math.Clamp(distance / 2048, 0, 1)
        local alpha = math.max(255 * factor, 20)
        
        local text = carInfo.name .. " [" .. id .. "]"
        
        surface.SetFont("ChatFont")
        local txtW, txtH = surface.GetTextSize(text)
        
        -- Фон
        surface.SetDrawColor(0, 0, 0, alpha - 15)
        surface.DrawRect(data.x - txtW / 2 - 5, data.y - txtH / 2 - 5, txtW + 10, txtH + 10)
        
        -- Текст
        local textColor = carInfo.color or Color(255, 255, 255)
        draw.SimpleTextOutlined(
            text,
            "ChatFont",
            data.x,
            data.y,
            ColorAlpha(textColor, alpha),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER,
            1,
            ColorAlpha(color_black, alpha)
        )
        
        -- Рисуем стрелку направления
        local forward = spawn.angles:Forward()
        local arrowEnd = pos + forward * 100
        local arrowData = arrowEnd:ToScreen()
        
        if arrowData.visible then
            -- Используем цвет машины или белый по умолчанию
            local color = carInfo.color or Color(255, 255, 255)
            surface.SetDrawColor(color.r, color.g, color.b, alpha)
            surface.DrawLine(data.x, data.y, arrowData.x, arrowData.y)
        end
    end
    
    -- Показываем количество точек
    draw.SimpleTextOutlined(
        "Точек спавна: " .. table.Count(zb.ClCarSpawns or {}),
        "DermaDefault",
        ScrW() / 2,
        ScrH() - 50,
        Color(255, 255, 255),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        1,
        Color(0, 0, 0)
    )
end

local clr = Color(20, 20, 20)
function TOOL:DrawToolScreen(width, height)
    surface.SetDrawColor(clr)
    surface.DrawRect(0, 0, width, height)
    
    draw.SimpleText("Car Editor", "ZB_ScrappersMedium", width / 2, height / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    local ply = self:GetOwner()
    local carType = ply:GetInfo("car_editor_car_type")
    local carInfo = zb.CarTypes[carType]
    
    if carInfo then
        local color = carInfo.color or Color(255, 255, 255)
        draw.SimpleText(carInfo.name, "ZB_ScrappersSmall", width / 2, height * 0.7, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(carInfo.faction, "ZB_ScrappersSmall", width / 2, height * 0.85, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end
