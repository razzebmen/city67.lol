include("shared.lua")

-- Получаем данные города из клиентской части roleplay
local function GetCityData()
    return {
        taxRate = GetGlobalInt("CityTaxRate", 0),
        treasury = GetGlobalInt("CityTreasury", 0),
        rules = GetGlobalString("CityRules", "Правила города не установлены"),
        mayorName = GetGlobalString("CityMayorName", "Отсутствует"),
        nextRobbery = GetGlobalInt("NextTreasuryRobbery", 0)
    }
end

function ENT:Initialize()
    self.NextDebug = CurTime()
end

-- Отображение точек табличек когда держишь инструмент
hook.Add("PostDrawTranslucentRenderables", "DrawCityTextPoints", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return end
    
    local tool = ply:GetTool()
    if not tool or tool.Mode ~= "city_text" then return end
    
    -- Рисуем точки для всех табличек
    for _, ent in ipairs(ents.FindByClass("zb_city_text")) do
        if IsValid(ent) then
            local pos = ent:GetPos()
            local textType = ent:GetTextType() or ent:GetNWString("TextType", "unknown")
            
            -- Цвет в зависимости от типа
            local color = Color(100, 200, 255)
            if textType == "treasury" then
                color = Color(100, 255, 100)
            elseif textType == "rules" then
                color = Color(255, 200, 100)
            elseif textType == "isis_intel" then
                color = Color(255, 100, 100)
            elseif textType == "isis_robbery" then
                color = Color(200, 100, 200)
            end
            
            -- Рисуем сферу
            render.SetColorMaterial()
            render.DrawSphere(pos, 10, 20, 20, color)
            
            -- Рисуем текст с типом
            local ang = (ply:EyePos() - pos):Angle()
            ang:RotateAroundAxis(ang:Forward(), 90)
            ang:RotateAroundAxis(ang:Right(), 90)
            
            cam.Start3D2D(pos + Vector(0, 0, 20), ang, 0.1)
                local displayText = "Неизвестно"
                if textType == "treasury" then
                    displayText = "Казна"
                elseif textType == "rules" then
                    displayText = "Правила"
                elseif textType == "isis_intel" then
                    displayText = "Разведка"
                elseif textType == "isis_robbery" then
                    displayText = "Ограбление"
                end
                draw.SimpleText(displayText, "DermaLarge", 0, 0, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            cam.End3D2D()
        end
    end
end)

function ENT:Draw()
    -- Не рисуем модель, только текст
    -- self:DrawModel()
    
    local textType = self:GetTextType()
    
    if not textType or textType == "" then 
        textType = self:GetNWString("TextType", "")
    end
    
    if not textType or textType == "" then
        return
    end
    
    local pos = self:GetPos()
    local ang = self:GetAngles()
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local distance = ply:GetPos():Distance(pos)
    if distance > 1000 then return end
    
    -- Копируем углы
    local drawAng = Angle(ang.p, ang.y, ang.r)
    
    -- Сдвигаем позицию вперёд по нормали поверхности
    local drawPos = pos + ang:Forward() * 1
    
    local success = pcall(function()
        cam.Start3D2D(drawPos, drawAng, 0.15)
            if textType == "rules" then
                -- Увеличенный фон для правил
                surface.SetDrawColor(20, 20, 20, 230)
                surface.DrawRect(-300, -200, 600, 400)
                
                -- Рамка
                surface.SetDrawColor(100, 100, 100, 255)
                surface.DrawOutlinedRect(-300, -200, 600, 400, 3)
            elseif textType == "isis_intel" or textType == "isis_robbery" then
                -- Фон для табличек ЦАХАЛ
                surface.SetDrawColor(20, 20, 20, 230)
                surface.DrawRect(-300, -150, 600, 300)
                
                -- Рамка
                surface.SetDrawColor(255, 100, 100, 255)
                surface.DrawOutlinedRect(-300, -150, 600, 300, 3)
            else
                -- Фон для казны (меньше по высоте)
                surface.SetDrawColor(20, 20, 20, 230)
                surface.DrawRect(-300, -150, 600, 300)
                
                -- Рамка
                surface.SetDrawColor(100, 100, 100, 255)
                surface.DrawOutlinedRect(-300, -150, 600, 300, 3)
            end
            
            if textType == "rules" then
                -- Заголовок выше
                draw.SimpleText("ПРАВИЛА ГОРОДА", "DermaLarge", 0, -170, Color(255, 200, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                local cityData = GetCityData()
                local rules = cityData.rules or "Правила не установлены"
                local mayorName = cityData.mayorName or "Отсутствует"
                
                -- Мэр (увеличенный шрифт)
                draw.SimpleText("Мэр: " .. mayorName, "DermaLarge", 0, -130, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                -- Разбиваем текст на строки и переносим длинные строки
                surface.SetFont("DermaLarge")
                local maxWidth = 550 -- Максимальная ширина текста
                local lines = {}
                
                for _, line in ipairs(string.Explode("\n", rules)) do
                    if line == "" then
                        table.insert(lines, "")
                    else
                        -- Разбиваем длинную строку на несколько
                        local words = string.Explode(" ", line)
                        local currentLine = ""
                        
                        for _, word in ipairs(words) do
                            local testLine = currentLine == "" and word or (currentLine .. " " .. word)
                            local w, h = surface.GetTextSize(testLine)
                            
                            if w > maxWidth then
                                if currentLine ~= "" then
                                    table.insert(lines, currentLine)
                                    currentLine = word
                                else
                                    table.insert(lines, word)
                                    currentLine = ""
                                end
                            else
                                currentLine = testLine
                            end
                        end
                        
                        if currentLine ~= "" then
                            table.insert(lines, currentLine)
                        end
                    end
                end
                
                -- Отображаем максимум 8 строк
                local y = -80
                for i = 1, math.min(#lines, 8) do
                    draw.SimpleText(lines[i], "DermaLarge", 0, y, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    y = y + 35
                end
                
                -- Если строк больше 8, показываем "..."
                if #lines > 8 then
                    draw.SimpleText("...", "DermaLarge", 0, y, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                
            elseif textType == "treasury" then
                -- Заголовок
                draw.SimpleText("КАЗНА ГОРОДА", "DermaLarge", 0, -100, Color(255, 200, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                local cityData = GetCityData()
                local treasury = cityData.treasury or 0
                local taxRate = cityData.taxRate or 0
                local nextRobbery = cityData.nextRobbery or 0
                
                -- Сумма
                draw.SimpleText(treasury .. "$", "DermaLarge", 0, -30, Color(100, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                -- Налог
                draw.SimpleText("Налог: " .. taxRate .. "%", "DermaLarge", 0, 30, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                -- Статус ограбления
                local canRob = CurTime() >= nextRobbery
                if canRob then
                    draw.SimpleText("Доступно для взлома!", "DermaLarge", 0, 70, Color(100, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("Для взлома воспользуйтесь радиальным меню", "DermaDefault", 0, 100, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("Доступно только Главе ЦАХАЛ", "DermaDefault", 0, 120, Color(255, 200, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                else
                    local timeLeft = math.ceil(nextRobbery - CurTime())
                    local minutes = math.floor(timeLeft / 60)
                    local seconds = timeLeft % 60
                    draw.SimpleText("Недоступно для взлома", "DermaLarge", 0, 70, Color(255, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText(string.format("Таймер: %d:%02d", minutes, seconds), "DermaDefault", 0, 100, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            
            elseif textType == "isis_intel" then
                -- Табличка разведки ЦАХАЛ - информация о мэрии
                draw.SimpleText("РАЗВЕДКА МЭРИИ", "DermaLarge", 0, -100, Color(255, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                local cityData = GetCityData()
                local treasury = cityData.treasury or 0
                local taxRate = cityData.taxRate or 0
                local mayorName = cityData.mayorName or "Отсутствует"
                local nextRobbery = cityData.nextRobbery or 0
                
                -- Мэр
                draw.SimpleText("Мэр: " .. mayorName, "DermaLarge", 0, -50, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                -- Казна
                draw.SimpleText("Казна: " .. treasury .. "$", "DermaLarge", 0, 0, Color(100, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                -- Налог (увеличенный шрифт)
                draw.SimpleText("Налог: " .. taxRate .. "%", "DermaLarge", 0, 40, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                -- Статус ограбления
                local canRob = CurTime() >= nextRobbery
                if canRob then
                    draw.SimpleText("МОЖНО ГРАБИТЬ!", "DermaLarge", 0, 80, Color(100, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                else
                    local timeLeft = math.ceil(nextRobbery - CurTime())
                    local minutes = math.floor(timeLeft / 60)
                    local seconds = timeLeft % 60
                    draw.SimpleText("Нельзя грабить", "DermaLarge", 0, 80, Color(255, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText(string.format("Ждать: %d:%02d", minutes, seconds), "DermaDefault", 0, 110, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            
            elseif textType == "isis_robbery" then
                -- Табличка с информацией об ограблении
                draw.SimpleText("ОГРАБЛЕНИЕ КАЗНЫ", "DermaLarge", 0, -100, Color(255, 200, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                draw.SimpleText("Как работает:", "DermaLarge", 0, -50, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                draw.SimpleText("1. Только Глава ЦАХАЛ может ограбить", "DermaLarge", 0, -10, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("2. Используй радиальное меню (Q)", "DermaLarge", 0, 15, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("3. Кулдаун: 5 минут", "DermaLarge", 0, 40, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                draw.SimpleText("Распределение денег:", "DermaLarge", 0, 75, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("Глава: 50% + равная доля", "DermaLarge", 0, 105, Color(100, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("Солдаты: равная доля каждому", "DermaLarge", 0, 130, Color(100, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            
        cam.End3D2D()
    end)
end
