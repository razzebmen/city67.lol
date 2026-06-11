TOOL.Category = "ZBattle"
TOOL.Name = "Door Editor"

TOOL.ClientConVar["door_type"] = "buyable"
TOOL.ClientConVar["group_mode"] = "0"

-- Типы дверей
local DoorTypes = {
    ["buyable"] = {name = "Покупаемая", color = Color(100, 255, 100)},
    ["police"] = {name = "Полиция", color = Color(100, 150, 255)},
    ["mayor"] = {name = "Мэрия", color = Color(255, 200, 100)},
    ["isis"] = {name = "ЦАХАЛ", color = Color(255, 100, 100)},
    ["none"] = {name = "Убрать", color = Color(150, 150, 150)}
}

-- Временное хранилище для группировки дверей
TOOL.GroupedDoors = TOOL.GroupedDoors or {}

function TOOL:LeftClick(trace)
    local ply = self:GetOwner()
    if not ply:IsAdmin() then
        if CLIENT then
            ply:ChatPrint("Только для администраторов")
        end
        return false
    end
    
    local ent = trace.Entity
    if not IsValid(ent) then return false end
    
    -- Проверяем, является ли это дверью
    local class = ent:GetClass()
    if class ~= "prop_door_rotating" and class ~= "func_door" and class ~= "func_door_rotating" then
        if CLIENT then
            ply:ChatPrint("Это не дверь! Класс: " .. class)
        end
        return false
    end
    
    local groupMode = ply:GetInfoNum(self:GetMode() .. "_group_mode", 0) == 1
    
    if groupMode then
        -- Режим группировки дверей
        if CLIENT then
            -- Добавляем дверь в группу
            local entIndex = ent:EntIndex()
            local alreadyInGroup = false
            
            for i, idx in ipairs(self.GroupedDoors) do
                if idx == entIndex then
                    alreadyInGroup = true
                    break
                end
            end
            
            if not alreadyInGroup then
                table.insert(self.GroupedDoors, entIndex)
                surface.PlaySound("buttons/button15.wav")
                ply:ChatPrint("Дверь добавлена в группу (" .. #self.GroupedDoors .. ")")
            else
                ply:ChatPrint("Эта дверь уже в группе")
            end
        end
    else
        -- Обычный режим
        if SERVER then
            local doorType = ply:GetInfo(self:GetMode() .. "_door_type")
            
            if doorType == "none" then
                -- Удаляем дверь из системы
                zb.RemoveDoor(ent)
                ply:ChatPrint("Дверь удалена из системы")
            else
                -- Добавляем дверь в систему
                zb.AddDoor(ent, doorType)
                ply:ChatPrint("Дверь добавлена: " .. (DoorTypes[doorType] and DoorTypes[doorType].name or doorType))
            end
            
            zb.SendDoors()
        end
    end
    
    return true
end

function TOOL:RightClick(trace)
    local ply = self:GetOwner()
    if not ply:IsAdmin() then
        ply:ChatPrint("Только для администраторов")
        return false
    end
    
    local groupMode = ply:GetInfoNum(self:GetMode() .. "_group_mode", 0) == 1
    
    if groupMode then
        -- В режиме группировки - применяем группу
        if CLIENT then
            if #self.GroupedDoors > 0 then
                -- Отправляем группу на сервер
                net.Start("zb_door_create_group")
                net.WriteUInt(#self.GroupedDoors, 8)
                for _, entIndex in ipairs(self.GroupedDoors) do
                    net.WriteUInt(entIndex, 16)
                end
                net.WriteString(ply:GetInfo(self:GetMode() .. "_door_type"))
                net.SendToServer()
                
                surface.PlaySound("buttons/button14.wav")
                ply:ChatPrint("Группа из " .. #self.GroupedDoors .. " дверей создана")
                self.GroupedDoors = {}
            else
                ply:ChatPrint("Сначала добавьте двери в группу (ЛКМ)")
            end
        end
    else
        -- Обычный режим - удаление двери
        local ent = trace.Entity
        if not IsValid(ent) then return false end
        
        if SERVER then
            -- Удаляем дверь из системы
            zb.RemoveDoor(ent)
            zb.SendDoors()
        end
    end
    
    return true
end

function TOOL.BuildCPanel(CPanel)
    CPanel:AddControl("Header", {
        Description = "Обычный режим:\nЛКМ - установить тип двери\nПКМ - убрать дверь\n\nРежим группировки:\nЛКМ - добавить дверь в группу\nПКМ - применить группу\nR - очистить группу"
    })
    
    CPanel:AddControl("CheckBox", {
        Label = "Режим группировки дверей",
        Command = "door_editor_group_mode"
    })
    
    local combo = CPanel:AddControl("ComboBox", {
        Label = "Тип двери",
        MenuButton = 0,
        Options = {
            ["Покупаемая"] = {door_editor_door_type = "buyable"},
            ["Полиция"] = {door_editor_door_type = "police"},
            ["Мэрия"] = {door_editor_door_type = "mayor"},
            ["ЦАХАЛ"] = {door_editor_door_type = "isis"},
            ["Убрать"] = {door_editor_door_type = "none"}
        }
    })
end

function TOOL:Allowed()
    return self:GetOwner():IsAdmin()
end

function TOOL:Deploy()
    if SERVER then
        local ply = self:GetOwner()
        zb.SendDoorsToPly(ply)
    else
        -- Очищаем группу при смене инструмента
        self.GroupedDoors = {}
    end
end

function TOOL:Reload()
    local ply = self:GetOwner()
    if not ply:IsAdmin() then return false end
    
    if CLIENT then
        -- Очищаем группу дверей
        if #self.GroupedDoors > 0 then
            self.GroupedDoors = {}
            surface.PlaySound("buttons/button10.wav")
            ply:ChatPrint("Группа дверей очищена")
        end
    end
    
    return true
end

-- Отрисовка HUD
function TOOL:DrawHUD()
    local lply = LocalPlayer()
    if not lply:IsAdmin() then return end
    
    local groupMode = lply:GetInfoNum(self:GetMode() .. "_group_mode", 0) == 1
    
    -- Отрисовываем все двери в системе
    for entIndex, doorData in pairs(zb.ClDoors or {}) do
        local ent = Entity(entIndex)
        if not IsValid(ent) then continue end
        
        local pos = ent:LocalToWorld(ent:OBBCenter())
        local doorType = DoorTypes[doorData.type]
        
        if not doorType then continue end
        
        local data = pos:ToScreen()
        if not data.visible then continue end
        
        local distance = lply:GetPos():Distance(pos)
        local factor = 1 - math.Clamp(distance / 2048, 0, 1)
        local alpha = math.max(255 * factor, 20)
        
        -- Проверяем, находится ли дверь в группе
        local inGroup = false
        if groupMode then
            for _, idx in ipairs(self.GroupedDoors) do
                if idx == entIndex then
                    inGroup = true
                    break
                end
            end
        end
        
        local text = doorType.name
        if doorData.groupID then
            text = text .. " [G:" .. doorData.groupID .. "]"
        end
        
        surface.SetFont("ChatFont")
        local txtW, txtH = surface.GetTextSize(text)
        
        -- Фон (зеленый если в группе)
        if inGroup then
            surface.SetDrawColor(0, 255, 0, alpha)
            surface.DrawRect(data.x - txtW / 2 - 5, data.y - txtH / 2 - 5, txtW + 10, txtH + 10)
        else
            surface.SetDrawColor(0, 0, 0, alpha - 15)
            surface.DrawRect(data.x - txtW / 2 - 5, data.y - txtH / 2 - 5, txtW + 10, txtH + 10)
        end
        
        -- Текст
        draw.SimpleTextOutlined(text, "ChatFont", data.x, data.y, ColorAlpha(doorType.color, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, ColorAlpha(color_black, alpha))
    end
    
    -- Показываем количество дверей в группе
    if groupMode and #self.GroupedDoors > 0 then
        draw.SimpleTextOutlined(
            "Дверей в группе: " .. #self.GroupedDoors,
            "DermaLarge",
            ScrW() / 2,
            ScrH() - 100,
            Color(100, 255, 100),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER,
            2,
            Color(0, 0, 0)
        )
    end
end

local clr = Color(20, 20, 20)
function TOOL:DrawToolScreen(width, height)
    surface.SetDrawColor(clr)
    surface.DrawRect(0, 0, width, height)
    
    draw.SimpleText("Door Editor", "ZB_ScrappersMedium", width / 2, height / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    local ply = self:GetOwner()
    local doorType = ply:GetInfo("door_editor_door_type")
    local typeData = DoorTypes[doorType]
    local groupMode = ply:GetInfoNum("door_editor_group_mode", 0) == 1
    
    if typeData then
        draw.SimpleText(typeData.name, "ZB_ScrappersSmall", width / 2, height * 0.7, typeData.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    if groupMode then
        draw.SimpleText("GROUP: " .. #self.GroupedDoors, "ZB_ScrappersSmall", width / 2, height * 0.85, Color(100, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end
