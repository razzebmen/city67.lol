-- Система контроля доступа к фракционным машинам

-- Функция для отправки цветного сообщения
local function SendColoredMessage(ply, ...)
    net.Start("zb_colored_message")
    net.WriteTable({...})
    net.Send(ply)
end

-- Функция проверки доступа
local function CheckCarAccess(ply, vehicle)
    if not IsValid(ply) or not IsValid(vehicle) then return false end
    
    -- Ищем zbCarSpawnID на самом vehicle или на его родителе
    local carSpawnID = vehicle.zbCarSpawnID
    
    -- Если это сиденье, проверяем родителя
    if not carSpawnID and IsValid(vehicle:GetParent()) then
        carSpawnID = vehicle:GetParent().zbCarSpawnID
    end
    
    -- Если это Simfphys, проверяем GetBaseEnt
    if not carSpawnID and vehicle.GetBaseEnt then
        local base = vehicle:GetBaseEnt()
        if IsValid(base) then
            carSpawnID = base.zbCarSpawnID
        end
    end
    
    if not carSpawnID then return true end -- Не фракционная машина
    
    local spawn = zb.CarSpawns[carSpawnID]
    if not spawn then return true end
    
    local carInfo = zb.CarTypes[spawn.carType]
    if not carInfo then return true end
    
    local jobName = ply.RoleplayJob or "Гражданский"
    local faction = carInfo.faction
    local hasAccess = false
    
    if faction == "police" then
        if jobName == "Полицейский" or jobName == "Спецназ" or jobName == "Глава Полиции" then
            hasAccess = true
        end
    elseif faction == "meria" then
        if jobName == "Мэр" or jobName == "Глава Полиции" then
            hasAccess = true
        end
    elseif faction == "igil" or faction == "igil2" then
        if jobName == "Солдат ЦАХАЛ" or jobName == "Глава ЦАХАЛ" then
            hasAccess = true
        end
    end
    
    return hasAccess, carInfo
end

-- Хук для стандартных машин
hook.Add("CanPlayerEnterVehicle", "zb_car_access_control", function(ply, vehicle, role)
    local round = CurrentRound()
    if not round or round.name ~= "roleplay" then return end
    
    local hasAccess, carInfo = CheckCarAccess(ply, vehicle)
    
    if not hasAccess and carInfo then
        SendColoredMessage(ply, 
            Color(255, 100, 100), "[Roleplay] ",
            Color(255, 255, 255), "У вас нет доступа к этой машине (",
            carInfo.color, carInfo.name,
            Color(255, 255, 255), ")"
        )
        return false
    end
end)

-- Хук для Simfphys (проверяем после входа)
hook.Add("PlayerEnteredVehicle", "zb_car_access_simfphys", function(ply, vehicle, role)
    local round = CurrentRound()
    if not round or round.name ~= "roleplay" then return end
    
    timer.Simple(0.1, function()
        if not IsValid(ply) or not IsValid(vehicle) then return end
        
        local hasAccess, carInfo = CheckCarAccess(ply, vehicle)
        
        if not hasAccess and carInfo then
            SendColoredMessage(ply, 
                Color(255, 100, 100), "[Roleplay] ",
                Color(255, 255, 255), "У вас нет доступа к этой машине (",
                carInfo.color, carInfo.name,
                Color(255, 255, 255), ")"
            )
            ply:ExitVehicle()
        end
    end)
end)

-- Постоянная проверка (на случай если хуки не работают)
local nextCheck = 0
hook.Add("Think", "zb_car_access_think", function()
    if CurTime() < nextCheck then return end
    nextCheck = CurTime() + 1
    
    local round = CurrentRound()
    if not round or round.name ~= "roleplay" then return end
    
    for _, ply in ipairs(player.GetAll()) do
        local vehicle = ply:GetVehicle()
        
        if IsValid(vehicle) then
            local hasAccess, carInfo = CheckCarAccess(ply, vehicle)
            
            if not hasAccess and carInfo then
                SendColoredMessage(ply, 
                    Color(255, 100, 100), "[Roleplay] ",
                    Color(255, 255, 255), "У вас нет доступа к этой машине!"
                )
                ply:ExitVehicle()
            end
        end
    end
end)

-- Команда для отладки
concommand.Add("zb_check_vehicle", function(ply, cmd, args)
    if not IsValid(ply) then return end
    
    local vehicle = ply:GetVehicle()
    
    print("=== ПРОВЕРКА МАШИНЫ ===")
    print("Игрок: " .. ply:Name())
    print("Профессия: " .. (ply.RoleplayJob or "Гражданский"))
    print("Режим: " .. (CurrentRound() and CurrentRound().name or "НЕТ"))
    print("В машине: " .. tostring(IsValid(vehicle)))
    
    if IsValid(vehicle) then
        print("Класс сиденья: " .. vehicle:GetClass())
        print("zbCarSpawnID на сиденье: " .. tostring(vehicle.zbCarSpawnID))
        
        local parent = vehicle:GetParent()
        if IsValid(parent) then
            print("Родитель: " .. parent:GetClass())
            print("zbCarSpawnID на родителе: " .. tostring(parent.zbCarSpawnID))
        end
        
        if vehicle.GetBaseEnt then
            local base = vehicle:GetBaseEnt()
            if IsValid(base) then
                print("BaseEnt: " .. base:GetClass())
                print("zbCarSpawnID на BaseEnt: " .. tostring(base.zbCarSpawnID))
            end
        end
    end
    
    print("======================")
end)
