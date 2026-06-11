-- Система спавна фракционных машин
zb.Cars = zb.Cars or {}
zb.CarSpawns = zb.CarSpawns or {}

-- Типы машин и их фракции
zb.CarTypes = {
    ["sim_fphys_l4d_police_city2"] = {
        name = "Полицейская Машина",
        faction = "police",
        color = Color(100, 150, 255)
    },
    ["sim_fphys_l4d_hmmwv"] = {
        name = "Хаммер ЦАХАЛ",
        faction = "igil",
        color = nil -- Без цвета
    },
    ["sim_fphys_l4d_pickup_b_78"] = {
        name = "Пикап ЦАХАЛ",
        faction = "igil2",
        color = Color(139, 90, 43)
    },
    ["sim_fphys_l4d_crownvic"] = {
        name = "Машина Мэрии",
        faction = "meria",
        color = Color(255, 255, 255)
    }
}

if SERVER then
    util.AddNetworkString("zb_car_sync")
    util.AddNetworkString("zb_car_request")
    util.AddNetworkString("zb_colored_message")
    
    -- Сохранить точки спавна в файл (с привязкой к карте)
    function zb.SaveCarSpawns()
        local map = game.GetMap()
        
        -- Создаем папку если её нет
        if not file.Exists("zbattle", "DATA") then
            file.CreateDir("zbattle")
        end
        
        if not file.Exists("zbattle/mappoints", "DATA") then
            file.CreateDir("zbattle/mappoints")
        end
        
        if not file.Exists("zbattle/mappoints/" .. map, "DATA") then
            file.CreateDir("zbattle/mappoints/" .. map)
        end
        
        local data = {}
        
        for id, spawn in pairs(zb.CarSpawns) do
            table.insert(data, {
                pos = spawn.pos,
                angles = spawn.angles,
                carType = spawn.carType
            })
        end
        
        local savePath = "zbattle/mappoints/" .. map .. "/car_spawns.json"
        local json = util.TableToJSON(data, true)
        file.Write(savePath, json)
    end
    
    -- Загрузить точки спавна из файла (с привязкой к карте)
    function zb.LoadCarSpawns()
        local map = game.GetMap()
        local savePath = "zbattle/mappoints/" .. map .. "/car_spawns.json"
        
        if not file.Exists(savePath, "DATA") then
            return
        end
        
        local json = file.Read(savePath, "DATA")
        if not json then return end
        
        local data = util.JSONToTable(json)
        if not data then return end
        
        -- Очищаем старые точки
        for id, spawn in pairs(zb.CarSpawns) do
            if IsValid(spawn.vehicle) then
                spawn.vehicle:Remove()
            end
        end
        zb.CarSpawns = {}
        
        -- Загружаем новые точки
        for i, spawnData in ipairs(data) do
            zb.CarSpawns[i] = {
                pos = spawnData.pos,
                angles = spawnData.angles,
                carType = spawnData.carType,
                vehicle = nil
            }
            
            -- Спавним машину
            zb.SpawnCar(i)
        end
    end
    
    -- Загружаем точки при старте сервера
    hook.Add("Initialize", "zb_load_car_spawns", function()
        timer.Simple(2, function()
            zb.LoadCarSpawns()
        end)
    end)
    
    -- Загружаем точки при старте карты
    hook.Add("InitPostEntity", "zb_load_car_spawns_post", function()
        timer.Simple(3, function()
            zb.LoadCarSpawns()
        end)
    end)
    
    -- Сохраняем точки при выключении сервера
    hook.Add("ShutDown", "zb_save_car_spawns", function()
        zb.SaveCarSpawns()
    end)
    
    -- Автосохранение каждые 5 минут
    timer.Create("zb_car_autosave", 300, 0, function()
        if table.Count(zb.CarSpawns) > 0 then
            zb.SaveCarSpawns()
        end
    end)
    
    -- Добавить точку спавна машины
    function zb.AddCarSpawn(pos, angles, carType)
        local id = #zb.CarSpawns + 1
        zb.CarSpawns[id] = {
            pos = pos,
            angles = angles,
            carType = carType,
            vehicle = nil
        }
        
        -- Спавним машину
        zb.SpawnCar(id)
        
        -- Сохраняем
        zb.SaveCarSpawns()
        
        return id
    end
    
    -- Удалить точку спавна
    function zb.RemoveCarSpawn(id)
        if zb.CarSpawns[id] then
            -- Удаляем машину если она есть
            if IsValid(zb.CarSpawns[id].vehicle) then
                zb.CarSpawns[id].vehicle:Remove()
            end
            
            -- Удаляем из таблицы
            table.remove(zb.CarSpawns, id)
            
            -- Пересоздаем индексы
            local newSpawns = {}
            for i, spawn in ipairs(zb.CarSpawns) do
                newSpawns[i] = spawn
                if IsValid(spawn.vehicle) then
                    spawn.vehicle.zbCarSpawnID = i
                end
            end
            zb.CarSpawns = newSpawns
            
            -- Сохраняем
            zb.SaveCarSpawns()
        end
    end
    
    -- Спавн машины на точке
    function zb.SpawnCar(id)
        local spawn = zb.CarSpawns[id]
        if not spawn then return end
        
        -- Удаляем старую машину если есть
        if IsValid(spawn.vehicle) then
            spawn.vehicle:Remove()
        end
        
        -- Получаем информацию о типе машины
        local carInfo = zb.CarTypes[spawn.carType]
        if not carInfo then return end
        
        -- Поднимаем позицию спавна на 5 единиц выше для предотвращения застревания
        local spawnPos = spawn.pos + Vector(0, 0, 5)
        
        -- Проверяем, это Simfphys машина или обычная
        local car
        if simfphys and simfphys.SpawnVehicleSimple then
            -- Временно отключаем хуки simfphysextra
            local oldHooks = {}
            if hook.GetTable()["simfphys_PostSpawn"] then
                for name, func in pairs(hook.GetTable()["simfphys_PostSpawn"]) do
                    oldHooks[name] = func
                    hook.Remove("simfphys_PostSpawn", name)
                end
            end
            
            -- Используем Simfphys для спавна
            car = simfphys.SpawnVehicleSimple(spawn.carType, spawnPos, spawn.angles)
            
            -- Восстанавливаем хуки
            for name, func in pairs(oldHooks) do
                hook.Add("simfphys_PostSpawn", name, func)
            end
            
            -- Устанавливаем параметры машины
            if IsValid(car) then
                -- Отключаем физику на момент настройки
                local phys = car:GetPhysicsObject()
                if IsValid(phys) then
                    phys:EnableMotion(false)
                end
                
                -- Устанавливаем топливо сразу
                if car.SetFuel then
                    car:SetFuel(100)
                end
                
                -- Устанавливаем здоровье на максимум
                if car.SetCurHealth then
                    car:SetCurHealth(car.MaxHealth or 1000)
                end
                
                -- Устанавливаем цвет фракции для Simfphys
                if carInfo.color then
                    timer.Simple(0.1, function()
                        if IsValid(car) then
                            if car.SetVehicleColor then
                                car:SetVehicleColor(carInfo.color)
                            end
                            
                            local base = car.GetBaseEnt and car:GetBaseEnt()
                            if IsValid(base) then
                                if base.SetVehicleColor then
                                    base:SetVehicleColor(carInfo.color)
                                end
                                base:SetColor(carInfo.color)
                                base:SetRenderMode(RENDERMODE_TRANSCOLOR)
                            end
                            
                            car:SetColor(carInfo.color)
                            car:SetRenderMode(RENDERMODE_TRANSCOLOR)
                            
                            for _, child in ipairs(car:GetChildren()) do
                                if IsValid(child) then
                                    child:SetColor(carInfo.color)
                                    child:SetRenderMode(RENDERMODE_TRANSCOLOR)
                                end
                            end
                            
                            if base and IsValid(base) then
                                local colorVec = Vector(carInfo.color.r / 255, carInfo.color.g / 255, carInfo.color.b / 255)
                                base:SetNWVector("simfphys_VehicleColor", colorVec)
                            end
                        end
                    end)
                end
                
                -- Включаем физику обратно через небольшую задержку
                timer.Simple(0.5, function()
                    if IsValid(car) then
                        local phys = car:GetPhysicsObject()
                        if IsValid(phys) then
                            phys:EnableMotion(true)
                            phys:Wake()
                        end
                    end
                end)
            end
        else
            -- Обычный спавн
            car = ents.Create(spawn.carType)
            if IsValid(car) then
                car:SetPos(spawnPos)
                car:SetAngles(spawn.angles)
                car:Spawn()
                car:Activate()
                
                if carInfo.color then
                    car:SetColor(carInfo.color)
                end
            end
        end
        
        if not IsValid(car) then return end
        
        -- Сохраняем ссылку
        spawn.vehicle = car
        car.zbCarSpawnID = id
        car.zbLastUsedTime = CurTime()
        car.zbIsSpawnedCar = true -- Маркер что это машина из спавна
        
        return car
    end
    
    -- Возврат машины на точку спавна
    function zb.ReturnCarToSpawn(id)
        local spawn = zb.CarSpawns[id]
        if not spawn or not IsValid(spawn.vehicle) then return end
        
        local car = spawn.vehicle
        
        -- Проверяем, есть ли кто-то в машине
        local hasDriver = IsValid(car:GetDriver())
        
        -- Проверяем пассажиров
        local hasPassengers = false
        if car.GetPassenger then
            for i = 1, 10 do
                if IsValid(car:GetPassenger(i)) then
                    hasPassengers = true
                    break
                end
            end
        end
        
        if hasDriver or hasPassengers then
            car.zbLastUsedTime = CurTime()
            return
        end
        
        -- Проверяем расстояние от точки спавна
        local distance = car:GetPos():Distance(spawn.pos)
        if distance < 100 then
            -- Машина уже близко к точке спавна, не трогаем её
            car.zbLastUsedTime = CurTime()
            return
        end
        
        -- Телепортируем машину на точку спавна
        car:SetPos(spawn.pos)
        car:SetAngles(spawn.angles)
        
        -- Сбрасываем физику
        local phys = car:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(Vector(0, 0, 0))
            phys:SetAngleVelocity(Vector(0, 0, 0))
        end
        
        car.zbLastUsedTime = CurTime()
    end
    
    -- Респавн машины
    function zb.RespawnCar(id, delay)
        delay = delay or 30
        
        timer.Simple(delay, function()
            zb.SpawnCar(id)
        end)
    end
    
    -- Отправить все точки спавна клиенту
    function zb.SendCarSpawns(ply)
        net.Start("zb_car_sync")
        net.WriteUInt(table.Count(zb.CarSpawns), 16)
        
        for id, spawn in pairs(zb.CarSpawns) do
            net.WriteUInt(id, 16)
            net.WriteVector(spawn.pos)
            net.WriteAngle(spawn.angles)
            net.WriteString(spawn.carType)
        end
        
        if IsValid(ply) then
            net.Send(ply)
        else
            net.Broadcast()
        end
    end
    
    -- Запрос точек спавна от клиента
    net.Receive("zb_car_request", function(len, ply)
        zb.SendCarSpawns(ply)
    end)
    
    -- Хук на уничтожение машины
    hook.Add("EntityRemoved", "zb_car_respawn", function(ent)
        if ent.zbCarSpawnID and ent.zbIsSpawnedCar then
            -- Машина удалена, респавним её через 5 секунд
            zb.RespawnCar(ent.zbCarSpawnID, 5)
        end
    end)
    
    -- Спавн всех машин при старте раунда
    hook.Add("RoundStart", "zb_spawn_cars", function()
        for id, spawn in pairs(zb.CarSpawns) do
            if not IsValid(spawn.vehicle) then
                zb.SpawnCar(id)
            end
        end
    end)
    
    -- Хук на вход/выход из машины
    hook.Add("PlayerEnteredVehicle", "zb_car_enter", function(ply, vehicle)
        if vehicle.zbCarSpawnID then
            vehicle.zbLastUsedTime = CurTime()
        end
    end)
    
    hook.Add("PlayerLeaveVehicle", "zb_car_leave", function(ply, vehicle)
        if vehicle.zbCarSpawnID then
            vehicle.zbLastUsedTime = CurTime()
        end
    end)
    
    -- Проверка неиспользуемых машин каждые 30 секунд
    timer.Create("zb_car_auto_return", 30, 0, function()
        for id, spawn in pairs(zb.CarSpawns) do
            if IsValid(spawn.vehicle) then
                local car = spawn.vehicle
                
                -- Инициализируем время если не установлено
                if not car.zbLastUsedTime then
                    car.zbLastUsedTime = CurTime()
                end
                
                local lastUsed = car.zbLastUsedTime or CurTime()
                
                -- Проверяем, есть ли кто-то в машине
                local hasDriver = IsValid(car:GetDriver())
                
                -- Проверяем пассажиров
                local hasPassengers = false
                if car.GetPassenger then
                    for i = 1, 10 do
                        if IsValid(car:GetPassenger(i)) then
                            hasPassengers = true
                            break
                        end
                    end
                end
                
                if hasDriver or hasPassengers then
                    car.zbLastUsedTime = CurTime()
                elseif CurTime() - lastUsed > 300 then
                    -- Прошло больше 5 минут без использования
                    zb.ReturnCarToSpawn(id)
                end
            end
        end
    end)
    
else
    -- CLIENT
    zb.ClCarSpawns = zb.ClCarSpawns or {}
    
    -- Получение точек спавна от сервера
    net.Receive("zb_car_sync", function()
        zb.ClCarSpawns = {}
        
        local count = net.ReadUInt(16)
        for i = 1, count do
            local id = net.ReadUInt(16)
            local pos = net.ReadVector()
            local angles = net.ReadAngle()
            local carType = net.ReadString()
            
            zb.ClCarSpawns[id] = {
                pos = pos,
                angles = angles,
                carType = carType
            }
        end
        
        print("[ZBattle] Получено точек спавна машин: " .. count)
    end)
    
    -- Получение цветных сообщений
    net.Receive("zb_colored_message", function()
        local args = net.ReadTable()
        chat.AddText(unpack(args))
    end)
    
    -- Запросить точки спавна при подключении
    hook.Add("InitPostEntity", "zb_request_cars", function()
        timer.Simple(1, function()
            net.Start("zb_car_request")
            net.SendToServer()
        end)
    end)
end


if SERVER then
    -- Команда для отладки
    concommand.Add("zb_cars_debug", function(ply, cmd, args)
        if IsValid(ply) and not ply:IsAdmin() then return end
        
        print("=== CAR SPAWNS DEBUG ===")
        print("Всего точек спавна: " .. table.Count(zb.CarSpawns))
        
        for id, spawn in pairs(zb.CarSpawns) do
            print("Точка #" .. id .. ":")
            print("  Тип: " .. spawn.carType)
            print("  Позиция: " .. tostring(spawn.pos))
            print("  Машина валидна: " .. tostring(IsValid(spawn.vehicle)))
            if IsValid(spawn.vehicle) then
                print("  Класс машины: " .. spawn.vehicle:GetClass())
            end
        end
        
        print("========================")
    end)
end


if SERVER then
    -- Команда для поиска доступных машин
    concommand.Add("zb_find_vehicles", function(ply, cmd, args)
        if IsValid(ply) and not ply:IsAdmin() then return end
        
        print("=== ПОИСК ДОСТУПНЫХ МАШИН ===")
        
        local vehicles = list.Get("Vehicles")
        local count = 0
        
        for class, data in pairs(vehicles) do
            print("Класс: " .. class)
            if data.Name then
                print("  Название: " .. data.Name)
            end
            if data.Model then
                print("  Модель: " .. data.Model)
            end
            count = count + 1
        end
        
        print("Всего найдено машин: " .. count)
        print("=============================")
        
        if IsValid(ply) then
            ply:ChatPrint("Найдено машин: " .. count .. ". Смотрите консоль сервера.")
        end
    end)
end


if SERVER then
    -- Команда для ручного сохранения точек спавна
    concommand.Add("zb_save_car_spawns", function(ply, cmd, args)
        if IsValid(ply) and not ply:IsAdmin() then return end
        
        zb.SaveCarSpawns()
        
        if IsValid(ply) then
            ply:ChatPrint("[ZBattle] Точки спавна машин сохранены!")
        end
        
        print("[ZBattle] Точки спавна машин сохранены вручную")
    end)
    
    -- Команда для ручной загрузки точек спавна
    concommand.Add("zb_load_car_spawns", function(ply, cmd, args)
        if IsValid(ply) and not ply:IsAdmin() then return end
        
        zb.LoadCarSpawns()
        zb.SendCarSpawns()
        
        if IsValid(ply) then
            ply:ChatPrint("[ZBattle] Точки спавна машин загружены!")
        end
        
        print("[ZBattle] Точки спавна машин загружены вручную")
    end)
end


if SERVER then
    -- Хук для принудительной установки цвета фракционных машин
    hook.Add("Think", "zb_car_force_color", function()
        for id, spawn in pairs(zb.CarSpawns) do
            if IsValid(spawn.vehicle) then
                local car = spawn.vehicle
                local carInfo = zb.CarTypes[spawn.carType]
                
                if carInfo and carInfo.color then
                    -- Проверяем, не изменился ли цвет
                    local currentColor = car:GetColor()
                    
                    if currentColor.r ~= carInfo.color.r or currentColor.g ~= carInfo.color.g or currentColor.b ~= carInfo.color.b then
                        -- Цвет изменился, восстанавливаем
                        if car.SetVehicleColor then
                            car:SetVehicleColor(carInfo.color)
                        end
                        car:SetColor(carInfo.color)
                        
                        local base = car.GetBaseEnt and car:GetBaseEnt()
                        if IsValid(base) then
                            if base.SetVehicleColor then
                                base:SetVehicleColor(carInfo.color)
                            end
                            base:SetColor(carInfo.color)
                        end
                    end
                end
            end
        end
    end)
end
