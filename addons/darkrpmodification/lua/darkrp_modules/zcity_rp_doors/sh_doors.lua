zb = zb or {}
zb.Doors = zb.Doors or {}
-- Ручные связи дверей: { [doorKeyA] = doorKeyB, [doorKeyB] = doorKeyA }
-- Зеркальные записи на обеих сторонах. Используется тулом door_link.
zb.DoorLinks = zb.DoorLinks or {}

if SERVER then
    util.AddNetworkString("zb_getalldoors")
    util.AddNetworkString("zb_door_buy")
    util.AddNetworkString("zb_door_sell")
    util.AddNetworkString("zb_door_unlock")
    util.AddNetworkString("zb_door_lock")
    util.AddNetworkString("zb_door_create_group")
    util.AddNetworkString("zb_door_links_sync")
    util.AddNetworkString("roleplay_door_message")
    
    zb.NextDoorGroupID = zb.NextDoorGroupID or 1
    
    -- Функция для получения уникального отпечатка двери (по координатам)
    function zb.GetDoorFingerprint(ent)
        if not IsValid(ent) then return nil end
        
        local pos = ent:GetPos()
        local model = ent:GetModel() or ""
        
        -- Округляем координаты до 2 знаков после запятой для надежности
        return {
            x = math.Round(pos.x, 2),
            y = math.Round(pos.y, 2),
            z = math.Round(pos.z, 2),
            model = model,
            class = ent:GetClass()
        }
    end
    
    -- Функция для поиска двери по отпечатку (по координатам)
    local function FindDoorByFingerprint(fingerprint)
        if not fingerprint then return nil end
        
        -- Ищем дверь по координатам и модели
        for _, ent in ipairs(ents.GetAll()) do
            local class = ent:GetClass()
            if class == "prop_door_rotating" or class == "func_door" or class == "func_door_rotating" then
                local pos = ent:GetPos()
                local x = math.Round(pos.x, 2)
                local y = math.Round(pos.y, 2)
                local z = math.Round(pos.z, 2)
                local model = ent:GetModel() or ""
                
                -- Сравниваем координаты и модель
                if x == fingerprint.x and y == fingerprint.y and z == fingerprint.z and model == fingerprint.model then
                    return ent
                end
            end
        end
        
        return nil
    end
    
    -- Функция для создания уникального ключа двери
    function zb.GetDoorKey(fingerprint)
        if not fingerprint then return nil end
        return string.format("%.2f_%.2f_%.2f_%s", fingerprint.x, fingerprint.y, fingerprint.z, fingerprint.model)
    end

    -- Поиск двери (entity) по ключу. Используется для применения физических
    -- inputs ко всем дверям в группе (например при открытии двойных дверей).
    function zb.FindDoorEntByKey(doorkey)
        if not doorkey then return nil end

        local x, y, z, model = doorkey:match("([%d%.%-]+)_([%d%.%-]+)_([%d%.%-]+)_(.+)")
        if not x or not y or not z or not model then return nil end

        x = tonumber(x)
        y = tonumber(y)
        z = tonumber(z)
        if not x or not y or not z then return nil end

        for _, ent in ipairs(ents.GetAll()) do
            local class = ent:GetClass()
            if class == "prop_door_rotating" or class == "func_door" or class == "func_door_rotating" then
                local pos = ent:GetPos()
                if math.Round(pos.x, 2) == x
                   and math.Round(pos.y, 2) == y
                   and math.Round(pos.z, 2) == z
                   and (ent:GetModel() or "") == model then
                    return ent
                end
            end
        end

        return nil
    end
    
    -- Функция для получения данных двери по entity
    function zb.GetDoorData(ent)
        if not IsValid(ent) then return nil end
        
        local fp = zb.GetDoorFingerprint(ent)
        if not fp then return nil end
        
        local key = zb.GetDoorKey(fp)
        return zb.Doors[key]
    end
    
    -- Функция для установки данных двери
    function zb.SetDoorData(ent, data)
        if not IsValid(ent) then return false end
        
        local fp = zb.GetDoorFingerprint(ent)
        if not fp then return false end
        
        local key = zb.GetDoorKey(fp)
        zb.Doors[key] = data
        return true
    end
    
    -- Загрузка дверей из файла
    function zb.LoadDoors()
        local map = game.GetMap()
        local savePath = "zbattle/mappoints/" .. map .. "/doors.json"
        
        zb.Doors = {}
        zb.NextDoorGroupID = 1
        
        if not file.Exists(savePath, "DATA") then 
            return 
        end
        
        local json = file.Read(savePath, "DATA")
        if not json then
            return
        end
        
        local data = util.JSONToTable(json)
        if not data then
            return
        end
        
        -- Восстанавливаем NextDoorGroupID
        if data.nextGroupID then
            zb.NextDoorGroupID = data.nextGroupID
        end
        
        -- Загружаем двери напрямую по ключам (координатам)
        if data.doors then
            for doorkey, doorData in pairs(data.doors) do
                -- Сбрасываем владельца и блокировку при загрузке —
                -- покупки не переживают перезапуск сервера
                if doorData.type == "buyable" then
                    doorData.owner     = nil
                    doorData.ownerName = nil
                    doorData.locked    = false
                end
                zb.Doors[doorkey] = doorData
            end
        end
    end
    
    -- Сохранение дверей в файл
    function zb.SaveDoors()
        local map = game.GetMap()
        local savePath = "zbattle/mappoints/" .. map .. "/doors.json"
        
        -- Создаем папки
        if not file.Exists("zbattle", "DATA") then
            file.CreateDir("zbattle")
        end
        if not file.Exists("zbattle/mappoints", "DATA") then
            file.CreateDir("zbattle/mappoints")
        end
        if not file.Exists("zbattle/mappoints/" .. map, "DATA") then
            file.CreateDir("zbattle/mappoints/" .. map)
        end
        
        -- zb.Doors уже хранит данные по ключам координат, просто сохраняем
        local data = {
            nextGroupID = zb.NextDoorGroupID,
            doors = zb.Doors
        }
        
        local json = util.TableToJSON(data, true)
        file.Write(savePath, json)
    end
    
    -- Добавление двери
    function zb.AddDoor(ent, doorType, groupID)
        if not IsValid(ent) then return end
        
        local fp = zb.GetDoorFingerprint(ent)
        if not fp then return end
        
        local key = zb.GetDoorKey(fp)
        zb.Doors[key] = {
            type = doorType,
            owner = nil,
            locked = false,
            groupID = groupID
        }
        
        -- Сохраняем двери
        zb.SaveDoors()
        return true
    end
    
    -- Создание группы дверей
    function zb.CreateDoorGroup(doorIndices, doorType)
        local groupID = zb.NextDoorGroupID
        zb.NextDoorGroupID = zb.NextDoorGroupID + 1
        
        for _, entIndex in ipairs(doorIndices) do
            local ent = Entity(entIndex)
            if IsValid(ent) then
                local fp = zb.GetDoorFingerprint(ent)
                if fp then
                    local key = zb.GetDoorKey(fp)
                    zb.Doors[key] = {
                        type = doorType,
                        owner = nil,
                        locked = false,
                        groupID = groupID
                    }
                end
            end
        end
        
        -- Сохраняем двери
        zb.SaveDoors()
        return groupID
    end
    
    -- Получение всех дверей в группе
    function zb.GetDoorsInGroup(groupID)
        local doors = {}
        for doorKey, doorData in pairs(zb.Doors) do
            if doorData.groupID == groupID then
                table.insert(doors, doorKey)
            end
        end
        return doors
    end
    
    -- Удаление двери
    function zb.RemoveDoor(ent)
        if not IsValid(ent) then return end
        
        local fp = zb.GetDoorFingerprint(ent)
        if not fp then return end
        
        local key = zb.GetDoorKey(fp)
        zb.Doors[key] = nil

        -- Чистим связи если были
        if zb.DoorLinks[key] then
            local other = zb.DoorLinks[key]
            zb.DoorLinks[other] = nil
            zb.DoorLinks[key] = nil
            if zb.SaveDoorLinks then zb.SaveDoorLinks() end
            if zb.SyncDoorLinks then zb.SyncDoorLinks() end
        end

        -- Сохраняем двери
        zb.SaveDoors()
    end

    -- ============================================
    -- РУЧНЫЕ СВЯЗИ ДВЕРЕЙ (door_link tool)
    -- ============================================
    -- Хранятся отдельно от zb.Doors, потому что:
    --   1. Связь работает даже на дверях которые не в системе zb.Doors
    --      (мэр-офис, любые декоративные двери) — суперадмин может связать
    --      любые две prop_door_rotating и они начнут открываться вместе.
    --   2. Это карта map-specific (rp_bangclaw), отдельный JSON удобнее.

    function zb.SaveDoorLinks()
        local map = game.GetMap()
        local savePath = "zbattle/mappoints/" .. map .. "/door_links.json"

        if not file.Exists("zbattle", "DATA") then file.CreateDir("zbattle") end
        if not file.Exists("zbattle/mappoints", "DATA") then file.CreateDir("zbattle/mappoints") end
        if not file.Exists("zbattle/mappoints/" .. map, "DATA") then file.CreateDir("zbattle/mappoints/" .. map) end

        file.Write(savePath, util.TableToJSON(zb.DoorLinks, true))
    end

    function zb.LoadDoorLinks()
        local map = game.GetMap()
        local savePath = "zbattle/mappoints/" .. map .. "/door_links.json"

        zb.DoorLinks = {}
        if not file.Exists(savePath, "DATA") then return end

        local json = file.Read(savePath, "DATA")
        if not json then return end

        local data = util.JSONToTable(json)
        if data then zb.DoorLinks = data end
    end

    function zb.SyncDoorLinks(ply)
        local pairs_list = {}
        local seen = {}
        for k, v in pairs(zb.DoorLinks) do
            if not seen[k] and not seen[v] then
                seen[k] = true
                seen[v] = true
                table.insert(pairs_list, { a = k, b = v })
            end
        end

        net.Start("zb_door_links_sync")
            net.WriteUInt(#pairs_list, 16)
            for _, p in ipairs(pairs_list) do
                net.WriteString(p.a)
                net.WriteString(p.b)
            end
        if IsValid(ply) then net.Send(ply) else net.Broadcast() end
    end

    function zb.AddDoorLink(entA, entB)
        if not IsValid(entA) or not IsValid(entB) then return false end
        if entA == entB then return false end

        local fpA = zb.GetDoorFingerprint(entA)
        local fpB = zb.GetDoorFingerprint(entB)
        if not fpA or not fpB then return false end

        local keyA = zb.GetDoorKey(fpA)
        local keyB = zb.GetDoorKey(fpB)

        -- Если у одной из дверей уже была связь — рвём её
        if zb.DoorLinks[keyA] then
            zb.DoorLinks[ zb.DoorLinks[keyA] ] = nil
        end
        if zb.DoorLinks[keyB] then
            zb.DoorLinks[ zb.DoorLinks[keyB] ] = nil
        end

        zb.DoorLinks[keyA] = keyB
        zb.DoorLinks[keyB] = keyA

        zb.SaveDoorLinks()
        zb.SyncDoorLinks()
        return true
    end

    function zb.RemoveDoorLink(ent)
        if not IsValid(ent) then return false end
        local fp = zb.GetDoorFingerprint(ent)
        if not fp then return false end
        local key = zb.GetDoorKey(fp)
        local other = zb.DoorLinks[key]
        if not other then return false end

        zb.DoorLinks[key] = nil
        zb.DoorLinks[other] = nil

        zb.SaveDoorLinks()
        zb.SyncDoorLinks()
        return true
    end

    -- Получить парную дверь (или nil)
    function zb.GetLinkedDoor(ent)
        if not IsValid(ent) then return nil end
        local fp = zb.GetDoorFingerprint(ent)
        if not fp then return nil end
        local key = zb.GetDoorKey(fp)
        local other = zb.DoorLinks[key]
        if not other then return nil end
        return zb.FindDoorEntByKey(other), other, key
    end
    
    -- Отправка всех дверей клиенту
    function zb.SendDoorsToPly(ply)
        local doorsToSend = {}
        
        for doorKey, doorData in pairs(zb.Doors) do
            table.insert(doorsToSend, {
                doorkey = doorKey,
                data = doorData
            })
        end
        
        net.Start("zb_getalldoors")
            net.WriteUInt(#doorsToSend, 16)
            for _, doorInfo in ipairs(doorsToSend) do
                net.WriteString(doorInfo.doorkey)
                net.WriteTable(doorInfo.data)
            end
        net.Send(ply)
    end
    
    -- Отправка всех дверей всем игрокам
    function zb.SendDoors()
        local doorsToSend = {}
        
        for doorKey, doorData in pairs(zb.Doors) do
            table.insert(doorsToSend, {
                doorkey = doorKey,
                data = doorData
            })
        end
        
        net.Start("zb_getalldoors")
            net.WriteUInt(#doorsToSend, 16)
            for _, doorInfo in ipairs(doorsToSend) do
                net.WriteString(doorInfo.doorkey)
                net.WriteTable(doorInfo.data)
            end
        net.Broadcast()
    end
    
    -- Загружаем двери при старте карты
    hook.Add("InitPostEntity", "ZB_LoadDoors", function()
        timer.Simple(2, function()
            zb.LoadDoors()
            zb.LoadDoorLinks()
            -- Отправляем двери всем игрокам после загрузки
            timer.Simple(0.5, function()
                zb.SendDoors()
                zb.SyncDoorLinks()
            end)
        end)
    end)
    
    -- Сохраняем двери при выключении сервера
    hook.Add("ShutDown", "ZB_SaveDoors", function()
        zb.SaveDoors()
    end)
    
    -- Автосохранение дверей каждые 5 минут
    timer.Create("zb_doors_autosave", 300, 0, function()
        if table.Count(zb.Doors) > 0 then
            zb.SaveDoors()
        end
    end)
    
    -- Команда для очистки дверей (только для админов)
    concommand.Add("zb_doors_clear", function(ply, cmd, args)
        if IsValid(ply) and not ply:IsAdmin() then
            ply:ChatPrint("Только для администраторов")
            return
        end
        
        zb.Doors = {}
        zb.SendDoors()
        
        if IsValid(ply) then
            ply:ChatPrint("[ZBattle] Все двери очищены")
        else
            print("[ZBattle] Все двери очищены")
        end
    end)
    
    -- Команда для ручного сохранения дверей
    concommand.Add("zb_doors_save", function(ply, cmd, args)
        if IsValid(ply) and not ply:IsAdmin() then
            ply:ChatPrint("Только для администраторов")
            return
        end
        
        zb.SaveDoors()
        
        if IsValid(ply) then
            ply:ChatPrint("[ZBattle] Двери сохранены вручную")
        else
            print("[ZBattle] Двери сохранены вручную")
        end
    end)
    
    -- Команда для ручной загрузки дверей
    concommand.Add("zb_doors_load", function(ply, cmd, args)
        if IsValid(ply) and not ply:IsAdmin() then
            ply:ChatPrint("Только для администраторов")
            return
        end
        
        zb.LoadDoors()
        zb.SendDoors()
        
        if IsValid(ply) then
            ply:ChatPrint("[ZBattle] Двери загружены вручную")
        else
            print("[ZBattle] Двери загружены вручную")
        end
    end)
    
    -- Обработчик создания группы дверей
    net.Receive("zb_door_create_group", function(len, ply)
        if not ply:IsAdmin() then return end
        
        local count = net.ReadUInt(8)
        local doorIndices = {}
        
        for i = 1, count do
            table.insert(doorIndices, net.ReadUInt(16))
        end
        
        local doorType = net.ReadString()
        
        if #doorIndices > 0 then
            zb.CreateDoorGroup(doorIndices, doorType)
            zb.SendDoors()
        end
    end)
    
    -- Отправляем двери игроку при подключении
    hook.Add("PlayerInitialSpawn", "ZB_SendDoorsToPlayer", function(ply)
        timer.Simple(1, function()
            if IsValid(ply) then
                zb.SendDoorsToPly(ply)
                zb.SyncDoorLinks(ply)
            end
        end)
    end)
    
    -- Обработчик запроса дверей от клиента
    net.Receive("zb_getalldoors", function(len, ply)
        if IsValid(ply) then
            zb.SendDoorsToPly(ply)
        end
    end)

    -- ============================================
    -- ФИЗИЧЕСКАЯ СИНХРОНИЗАЦИЯ СВЯЗАННЫХ ДВЕРЕЙ
    -- ============================================
    -- Когда игрок открывает/закрывает одну створку (через E, через `Open`,
    -- через любую другую логику в карте), мы повторяем то же самое на
    -- парной двери. Используем m_eDoorState — если у двух дверей он
    -- разошёлся, выравниваем.
    --
    -- Лёгкий timer вместо Think, чтобы не нагружать сервер. 5 раз в секунду
    -- более чем достаточно — задержка в 0.2 сек незаметна при открывании.

    local function GetDoorOpenState(door)
        if not IsValid(door) then return nil end
        local class = door:GetClass()
        if class == "prop_door_rotating" then
            -- 0 = closed, 1 = opening, 2 = open, 3 = closing
            local s = door:GetInternalVariable("m_eDoorState")
            if s == 1 or s == 2 then return true end
            return false
        elseif class == "func_door" or class == "func_door_rotating" then
            return door:GetInternalVariable("m_toggle_state") == 0
        end
        return nil
    end

    timer.Create("zb_door_link_sync", 0.2, 0, function()
        if not zb.DoorLinks then return end

        local processed = {}
        for keyA, keyB in pairs(zb.DoorLinks) do
            if processed[keyA] or processed[keyB] then continue end
            processed[keyA] = true
            processed[keyB] = true

            local entA = zb.FindDoorEntByKey(keyA)
            local entB = zb.FindDoorEntByKey(keyB)
            if not IsValid(entA) or not IsValid(entB) then continue end

            -- Не трогаем снесённые двери (NoDraw = true)
            if entA:GetNoDraw() or entB:GetNoDraw() then continue end

            local openA = GetDoorOpenState(entA)
            local openB = GetDoorOpenState(entB)
            if openA == nil or openB == nil then continue end
            if openA == openB then continue end

            -- Запоминаем кто инициатор по таймстемпу. Если у одной двери
            -- состояние изменилось позже — она ведёт. По умолчанию ведёт A.
            local leader, follower
            local tA = entA.zb_link_lastChange or 0
            local tB = entB.zb_link_lastChange or 0
            if tB > tA then
                leader, follower = entB, entA
            else
                leader, follower = entA, entB
            end

            local leaderOpen = GetDoorOpenState(leader)
            if leaderOpen then
                follower:Fire("Unlock")
                follower:Fire("Open")
            else
                follower:Fire("Close")
            end
            follower.zb_link_lastChange = CurTime()
        end
    end)

    -- Отслеживаем когда дверь меняет состояние (через PlayerUse), чтобы
    -- понять кто из двух — лидер.
    hook.Add("PlayerUse", "zb_door_link_track_use", function(ply, ent)
        if IsValid(ent) and (ent:GetClass() == "prop_door_rotating"
                          or ent:GetClass() == "func_door"
                          or ent:GetClass() == "func_door_rotating") then
            ent.zb_link_lastChange = CurTime()
        end
    end)

    -- ============================================
    -- СИНХРОНИЗАЦИЯ КЕША zb.Doors[].locked С ФИЗИЧЕСКИМ СОСТОЯНИЕМ
    -- ============================================
    -- Q-меню (cl_roleplay.lua) и серверный обработчик zb_door_lock читают
    -- doorData.locked. Если кеш расходится с реальным замком (а это часто
    -- происходит при ручных Fire из карты, после сноса/восстановления и
    -- сменах раунда) — кнопка показывает не то состояние.
    --
    -- Раз в 2 секунды проходим по всем зарегистрированным дверям, читаем
    -- m_bLocked напрямую из движка и подравниваем кеш. Если что-то реально
    -- изменилось — рассылаем клиентам обновлённую таблицу.

    timer.Create("zb_door_lock_state_sync", 2, 0, function()
        if not zb.Doors then return end

        local changed = false
        for doorKey, data in pairs(zb.Doors) do
            local ent = zb.FindDoorEntByKey(doorKey)
            if IsValid(ent) and not ent:GetNoDraw() then
                local mb = ent:GetInternalVariable("m_bLocked")
                if mb ~= nil and data.locked ~= mb then
                    data.locked = mb
                    changed = true
                end
            end
        end

        if changed then
            zb.SendDoors()
        end
    end)
end

if CLIENT then
    zb.ClDoors = zb.ClDoors or {}
    zb.ClDoorLinks = zb.ClDoorLinks or {}

    net.Receive("zb_door_links_sync", function()
        zb.ClDoorLinks = {}
        local n = net.ReadUInt(16)
        for i = 1, n do
            local a = net.ReadString()
            local b = net.ReadString()
            zb.ClDoorLinks[a] = b
            zb.ClDoorLinks[b] = a
        end
    end)
    
    -- Функция для поиска двери по координатам и модели
    local function FindDoorByKey(doorkey)
        local x, y, z, model = doorkey:match("([%d%.%-]+)_([%d%.%-]+)_([%d%.%-]+)_(.+)")
        
        if not x or not y or not z or not model then return nil end
        
        x = tonumber(x)
        y = tonumber(y)
        z = tonumber(z)
        
        for _, ent in ipairs(ents.GetAll()) do
            local class = ent:GetClass()
            if class == "prop_door_rotating" or class == "func_door" or class == "func_door_rotating" then
                local pos = ent:GetPos()
                local entX = math.Round(pos.x, 2)
                local entY = math.Round(pos.y, 2)
                local entZ = math.Round(pos.z, 2)
                local entModel = ent:GetModel() or ""
                
                if entX == x and entY == y and entZ == z and entModel == model then
                    return ent
                end
            end
        end
        
        return nil
    end
    
    net.Receive("zb_getalldoors", function()
        local count = net.ReadUInt(16)
        
        -- Очищаем старые данные
        zb.ClDoors = {}
        
        for i = 1, count do
            local doorkey = net.ReadString()
            local doorData = net.ReadTable()
            
            -- Ищем дверь на клиенте по ключу
            local door = FindDoorByKey(doorkey)
            
            if IsValid(door) then
                local entIndex = door:EntIndex()
                zb.ClDoors[entIndex] = doorData
            end
        end
    end)
end
