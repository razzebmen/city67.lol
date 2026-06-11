-- =====================================================
-- ZB Greenzone — серверная логика (полигон-призма из 4 точек)
-- =====================================================
-- Каждая зона = 4 точки пола (XY-полигон) + диапазон высоты [zMin, zMax].
-- При входе/выходе игрока — toggle god mode через ZCity.SetGod(silent=true).
-- Сохранение: data/zb_greenzones/<map>.json per-map.

if not SERVER then return end

local PREFIX = "[Greenzone] "
local DATA_DIR = "zb_greenzones"
local FILE_EXT = ".json"
local DEFAULT_HEIGHT_UP = 200 -- сколько добавить к maxZ для потолка по умолчанию

ZBGreenzone = ZBGreenzone or {}
ZBGreenzone.Zones    = ZBGreenzone.Zones or {}
ZBGreenzone.NextId   = ZBGreenzone.NextId or 1
ZBGreenzone.InZoneOf = ZBGreenzone.InZoneOf or {} -- [steamid] = zoneId

local function isAdmin(ply)
    return IsValid(ply) and ply:IsSuperAdmin()
end

local function mapFile()
    return DATA_DIR .. "/" .. string.lower(game.GetMap()) .. FILE_EXT
end

local function ensureDir()
    if not file.IsDir(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end
end

-- =====================================================
-- Геометрия
-- =====================================================

-- Сортировка точек по углу вокруг центроида (CCW), чтобы 4 точки
-- образовывали корректный (не самопересекающийся) четырёхугольник.
local function sortCornersCCW(points)
    local cx, cy = 0, 0
    for _, p in ipairs(points) do cx = cx + p.x; cy = cy + p.y end
    cx = cx / #points; cy = cy / #points
    table.sort(points, function(a, b)
        return math.atan2(a.y - cy, a.x - cx) < math.atan2(b.y - cy, b.x - cx)
    end)
    return points
end

-- Ray-casting: точка внутри полигона (2D)
local function pointInPoly2D(pt, poly)
    local inside = false
    local n = #poly
    local j = n
    for i = 1, n do
        local xi, yi = poly[i].x, poly[i].y
        local xj, yj = poly[j].x, poly[j].y
        if ((yi > pt.y) ~= (yj > pt.y))
           and (pt.x < (xj - xi) * (pt.y - yi) / (yj - yi + 1e-9) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function pointInZone(pt, zone)
    if pt.z < zone.zMin or pt.z > zone.zMax then return false end
    return pointInPoly2D(pt, zone.points)
end

-- Центроид зоны (для NearestTo)
local function zoneCenter(zone)
    local cx, cy = 0, 0
    for _, p in ipairs(zone.points) do cx = cx + p.x; cy = cy + p.y end
    cx = cx / #zone.points; cy = cy / #zone.points
    return Vector(cx, cy, (zone.zMin + zone.zMax) * 0.5)
end

-- AABB-проверка для быстрого отбора
local function boundsOf(points)
    local minx, miny = math.huge, math.huge
    local maxx, maxy = -math.huge, -math.huge
    for _, p in ipairs(points) do
        if p.x < minx then minx = p.x end
        if p.y < miny then miny = p.y end
        if p.x > maxx then maxx = p.x end
        if p.y > maxy then maxy = p.y end
    end
    return minx, miny, maxx, maxy
end

-- =====================================================
-- Хранение
-- =====================================================

function ZBGreenzone.Save()
    ensureDir()
    -- Конвертируем векторы в массивы [x,y,z] для JSON
    local out = { zones = {} }
    for _, z in ipairs(ZBGreenzone.Zones) do
        local pts = {}
        for _, p in ipairs(z.points) do
            table.insert(pts, { p.x, p.y, p.z })
        end
        table.insert(out.zones, {
            id = z.id,
            name = z.name,
            points = pts,
            zMin = z.zMin,
            zMax = z.zMax,
        })
    end
    file.Write(mapFile(), util.TableToJSON(out, true))
end

function ZBGreenzone.Load()
    ZBGreenzone.Zones = {}
    ZBGreenzone.NextId = 1
    local path = mapFile()
    if not file.Exists(path, "DATA") then
        print(PREFIX .. "Файл зон для карты не найден: " .. path)
        return
    end
    local raw = file.Read(path, "DATA") or ""
    local data = util.JSONToTable(raw)
    if not data or not data.zones then
        print(PREFIX .. "Не удалось распарсить " .. path)
        return
    end
    for _, z in ipairs(data.zones) do
        local pts = {}
        for _, pp in ipairs(z.points or {}) do
            table.insert(pts, Vector(pp[1], pp[2], pp[3]))
        end
        if #pts >= 3 then
            local zone = {
                id = z.id, name = z.name or "",
                points = pts, zMin = z.zMin, zMax = z.zMax,
            }
            table.insert(ZBGreenzone.Zones, zone)
            if z.id and z.id >= ZBGreenzone.NextId then
                ZBGreenzone.NextId = z.id + 1
            end
        end
    end
    print(PREFIX .. "Загружено " .. #ZBGreenzone.Zones .. " зон для карты " .. game.GetMap())
end

-- =====================================================
-- Sync клиентам
-- =====================================================

function ZBGreenzone.BroadcastSync(targetPly)
    net.Start(ZBGreenzone.NET.SYNC)
    net.WriteUInt(#ZBGreenzone.Zones, 16)
    for _, z in ipairs(ZBGreenzone.Zones) do
        net.WriteUInt(z.id, 16)
        net.WriteString(z.name or "")
        net.WriteFloat(z.zMin)
        net.WriteFloat(z.zMax)
        net.WriteUInt(#z.points, 8)
        for _, p in ipairs(z.points) do
            net.WriteVector(p)
        end
    end

    if IsValid(targetPly) then
        net.Send(targetPly)
    else
        net.Broadcast() -- видимость регулируется тулом на стороне клиента
    end
end

-- =====================================================
-- Создание / удаление
-- =====================================================

function ZBGreenzone.Create(points, height, name)
    -- points: массив из 4 Vector. height: ceiling-добавка к maxZ.
    if not points or #points < 3 then return nil, "Нужно минимум 3 точки" end

    local sorted = {}
    for i, p in ipairs(points) do sorted[i] = Vector(p.x, p.y, p.z) end
    sortCornersCCW(sorted)

    local minZ, maxZ = math.huge, -math.huge
    for _, p in ipairs(sorted) do
        if p.z < minZ then minZ = p.z end
        if p.z > maxZ then maxZ = p.z end
    end
    -- Расширяем диапазон по Z: чуть ниже пола + добавка вверх
    local zMin = minZ - 8
    local zMax = maxZ + (tonumber(height) or DEFAULT_HEIGHT_UP)

    local zone = {
        id = ZBGreenzone.NextId,
        name = name or ("Зона #" .. ZBGreenzone.NextId),
        points = sorted,
        zMin = zMin,
        zMax = zMax,
    }
    ZBGreenzone.NextId = ZBGreenzone.NextId + 1
    table.insert(ZBGreenzone.Zones, zone)
    ZBGreenzone.Save()
    ZBGreenzone.BroadcastSync()
    return zone
end

function ZBGreenzone.DeleteById(id)
    for i, z in ipairs(ZBGreenzone.Zones) do
        if z.id == id then
            table.remove(ZBGreenzone.Zones, i)
            ZBGreenzone.Save()
            ZBGreenzone.BroadcastSync()
            return true
        end
    end
    return false
end

function ZBGreenzone.NearestTo(pos)
    local bestZone, bestDist
    for _, z in ipairs(ZBGreenzone.Zones) do
        local center = zoneCenter(z)
        local d = pos:DistToSqr(center)
        if not bestDist or d < bestDist then
            bestDist = d
            bestZone = z
        end
    end
    return bestZone, bestDist and math.sqrt(bestDist) or nil
end

function ZBGreenzone.FindContaining(pos)
    for _, z in ipairs(ZBGreenzone.Zones) do
        if pointInZone(pos, z) then return z end
    end
end

-- =====================================================
-- Применение god mode при входе/выходе
-- =====================================================

local function applyState(ply, zone)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local sid = ply:SteamID()
    local prev = ZBGreenzone.InZoneOf[sid]

    if zone and not prev then
        ZBGreenzone.InZoneOf[sid] = zone.id
        ply:SetNWBool("zb_safezone", true)
        ply:SetNWString("zb_safezone_name", zone.name or "")
        if ZCity and ZCity.SetGod then
            ZCity.SetGod(ply, true, true)
        else
            ply:GodEnable()
        end
        net.Start(ZBGreenzone.NET.NOTIFY)
            net.WriteBool(true)
            net.WriteString(zone.name or "")
        net.Send(ply)
    elseif not zone and prev then
        ZBGreenzone.InZoneOf[sid] = nil
        ply:SetNWBool("zb_safezone", false)
        ply:SetNWString("zb_safezone_name", "")
        if ZCity and ZCity.SetGod then
            ZCity.SetGod(ply, false, true)
        else
            ply:GodDisable()
        end
        net.Start(ZBGreenzone.NET.NOTIFY)
            net.WriteBool(false)
            net.WriteString("")
        net.Send(ply)
    elseif zone and prev and prev ~= zone.id then
        ZBGreenzone.InZoneOf[sid] = zone.id
        ply:SetNWString("zb_safezone_name", zone.name or "")
    end
end

-- =====================================================
-- Запрет стрельбы в зелёной зоне
-- =====================================================
local function preventShootCheck(wep)
    if not SERVER then return end
    
    local ply = wep:GetOwner()
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    -- Проверяем находится ли игрок в зелёной зоне
    local pos = ply:GetPos()
    local zone = ZBGreenzone.FindContaining(pos)
    
    if zone then
        -- Игрок в зелёной зоне - запрещаем стрельбу
        if (wep.LastShootBlocked or 0) < CurTime() then
            wep.LastShootBlocked = CurTime() + 3
            ply:SendLua('chat.AddText(Color(0, 255, 0), "[Зелёная зона] ", Color(255, 255, 255), "Здесь запрещено стрелять!")')
        end
        return true -- Запрещаем выстрел
    end
    
    return false -- Разрешаем выстрел
end

-- Hook для перехвата PrimaryAttack (основной выстрел)
hook.Add("PlayerCanFire", "ZBGreenzone_NoShoot", function(ply, wep)
    if not IsValid(ply) or not wep then return end
    
    local pos = ply:GetPos()
    local zone = ZBGreenzone.FindContaining(pos)
    
    if zone then
        if (ply.LastShootBlocked or 0) < CurTime() then
            ply.LastShootBlocked = CurTime() + 3
            ply:SendLua('chat.AddText(Color(0, 255, 0), "[Зелёная зона] ", Color(255, 255, 255), "Здесь запрещено стрелять!")')
        end
        return false
    end
end)

-- Дополнительная защита: перехватываем выстрел через SWEP
hook.Add("WeaponEquip", "ZBGreenzone_WeaponHook", function(wep)
    if not SERVER then return end
    
    local originalShoot = wep.Shoot
    
    wep.Shoot = function(self, override)
        local ply = self:GetOwner()
        if IsValid(ply) and ply:IsPlayer() then
            local pos = ply:GetPos()
            local zone = ZBGreenzone.FindContaining(pos)
            
            if zone then
                if (self.LastShootBlocked or 0) < CurTime() then
                    self.LastShootBlocked = CurTime() + 3
                    ply:SendLua('chat.AddText(Color(0, 255, 0), "[Зелёная зона] ", Color(255, 255, 255), "Здесь запрещено стрелять!")')
                end
                return false
            end
        end
        
        if originalShoot then
            return originalShoot(self, override)
        end
    end
    
    local originalPrimaryAttack = wep.PrimaryAttack
    
    wep.PrimaryAttack = function(self, broadcast)
        local ply = self:GetOwner()
        if IsValid(ply) and ply:IsPlayer() then
            local pos = ply:GetPos()
            local zone = ZBGreenzone.FindContaining(pos)
            
            if zone then
                if (self.LastShootBlocked or 0) < CurTime() then
                    self.LastShootBlocked = CurTime() + 3
                    ply:SendLua('chat.AddText(Color(0, 255, 0), "[Зелёная зона] ", Color(255, 255, 255), "Здесь запрещено стрелять!")')
                end
                return
            end
        end
        
        if originalPrimaryAttack then
            originalPrimaryAttack(self, broadcast)
        end
    end
end)

local function tickAllPlayers()
    if #ZBGreenzone.Zones == 0 then
        for sid in pairs(ZBGreenzone.InZoneOf) do
            local ply = player.GetBySteamID and player.GetBySteamID(sid)
            if IsValid(ply) and ply:Alive() then applyState(ply, nil) end
        end
        return
    end
    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() then
            local pos = ply:GetPos()
            local z = ZBGreenzone.FindContaining(pos)
            applyState(ply, z)
        end
    end
end

timer.Create("ZBGreenzone_Tick", 0.5, 0, tickAllPlayers)

hook.Add("PlayerDeath", "ZBGreenzone_Death", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()

    -- БАГ-ФИКС: если игрок умер находясь в зоне — god был ВКЛ. Просто очистить
    -- InZoneOf без GodDisable() оставит god включённым на entity, и после
    -- респавна ВНЕ зоны он сохранится (ни одна ветка applyState не сработает:
    -- prev=nil потому что мы здесь очистили, zone=nil потому что вне зоны).
    -- Это и был баг "у всех начал включаться годмод после спавна".
    if ZBGreenzone.InZoneOf[sid] then
        if ZCity and ZCity.SetGod then
            ZCity.SetGod(ply, false, true)
        else
            ply:GodDisable()
        end
    end

    ZBGreenzone.InZoneOf[sid] = nil
    ply:SetNWBool("zb_safezone", false)
end)

hook.Add("PlayerSpawn", "ZBGreenzone_Spawn", function(ply)
    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        local z = ZBGreenzone.FindContaining(ply:GetPos())
        applyState(ply, z)
    end)
end)

-- =====================================================
-- Net handlers
-- =====================================================

net.Receive(ZBGreenzone.NET.CREATE, function(_, ply)
    if not isAdmin(ply) then return end
    local count = net.ReadUInt(8)
    if count < 3 or count > 8 then
        ply:ChatPrint("[Грин-зона] Некорректное число точек: " .. count)
        return
    end
    local pts = {}
    for i = 1, count do pts[i] = net.ReadVector() end
    local height = net.ReadFloat()
    local name = net.ReadString()
    if name == "" then name = nil end

    -- Минимальный размер: длина любого ребра bounding-box ≥ 1 ед.
    local minx, miny, maxx, maxy = boundsOf(pts)
    if (maxx - minx) < 1 or (maxy - miny) < 1 then
        ply:ChatPrint("[Грин-зона] Зона слишком маленькая (минимум 1 ед.).")
        return
    end
    if (maxx - minx) > 32768 or (maxy - miny) > 32768 then
        ply:ChatPrint("[Грин-зона] Зона слишком большая.")
        return
    end

    local z, err = ZBGreenzone.Create(pts, height, name)
    if not z then
        ply:ChatPrint("[Грин-зона] Ошибка создания: " .. (err or "?"))
        return
    end
    ply:ChatPrint(string.format("[Грин-зона] Создана: %s (id %d, точек %d, высота %d)",
        z.name, z.id, #z.points, math.floor(z.zMax - z.zMin)))
end)

net.Receive(ZBGreenzone.NET.DELETE, function(_, ply)
    if not isAdmin(ply) then return end
    local pos = net.ReadVector()
    local inside = ZBGreenzone.FindContaining(pos)
    if inside then
        ZBGreenzone.DeleteById(inside.id)
        ply:ChatPrint("[Грин-зона] Удалена: " .. (inside.name or inside.id))
        return
    end
    local nearest, dist = ZBGreenzone.NearestTo(pos)
    if not nearest then
        ply:ChatPrint("[Грин-зона] Зон на карте нет.")
        return
    end
    if dist and dist > 4096 then
        ply:ChatPrint("[Грин-зона] Ближайшая зона слишком далеко: " .. math.floor(dist))
        return
    end
    ZBGreenzone.DeleteById(nearest.id)
    ply:ChatPrint("[Грин-зона] Удалена: " .. (nearest.name or nearest.id))
end)

-- =====================================================
-- Hooks
-- =====================================================

hook.Add("InitPostEntity", "ZBGreenzone_Load", function()
    ZBGreenzone.Load()
end)

hook.Add("PlayerInitialSpawn", "ZBGreenzone_SyncOnJoin", function(ply)
    timer.Simple(3, function()
        if not IsValid(ply) then return end
        ZBGreenzone.BroadcastSync(ply)
    end)
end)

-- =====================================================
-- Команды
-- =====================================================

concommand.Add("zb_greenzone_list", function(ply)
    if IsValid(ply) and not isAdmin(ply) then return end
    local out = { PREFIX .. "=== Зоны на карте " .. game.GetMap() .. " (" .. #ZBGreenzone.Zones .. ") ===" }
    for _, z in ipairs(ZBGreenzone.Zones) do
        table.insert(out, string.format("%s#%d  %s  точек=%d  высота=%d",
            PREFIX, z.id, z.name or "", #z.points, math.floor(z.zMax - z.zMin)))
    end
    for _, line in ipairs(out) do
        if IsValid(ply) then ply:ChatPrint(line) else print(line) end
    end
end)

concommand.Add("zb_greenzone_reload", function(ply)
    if IsValid(ply) and not isAdmin(ply) then return end
    ZBGreenzone.Load()
    ZBGreenzone.BroadcastSync()
    if IsValid(ply) then ply:ChatPrint(PREFIX .. "Перезагружено") end
end)

print(PREFIX .. "Серверный модуль (полигон-призма) загружен")

