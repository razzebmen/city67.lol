--[[
    Door Link tool — связывает две двери в пару.
    Только для суперадминов.
    ЛКМ — выбрать первую дверь, ЛКМ на вторую — связать.
    ПКМ на связанной двери — разорвать связь.
    Reload — сбросить выбор первой двери.

    Сделан по образцу door_editor.lua (без net-сообщений).
--]]

TOOL.Category = "ZBattle"
TOOL.Name = "Door Link (двойные двери)"

-- Первая выбранная дверь — храним прямо на TOOL (по образцу door_editor.GroupedDoors)
TOOL.FirstDoor = TOOL.FirstDoor or nil

local function isDoor(ent)
    if not IsValid(ent) then return false end
    local c = ent:GetClass()
    return c == "prop_door_rotating" or c == "func_door" or c == "func_door_rotating"
end

local function canUse(ply)
    -- Принимаем admin и superadmin (по образцу door_editor.lua который тоже на IsAdmin)
    return IsValid(ply) and (ply:IsSuperAdmin() or ply:IsAdmin())
end

if SERVER then
    -- Хук CanTool с приоритетом MONITOR_HIGH — чтобы наш ответ перебивал
    -- любые ограничения FPP / DarkRP / ULib для нашего тула на дверях.
    -- Срабатывает только для нашего тула + дверей + админа, остальное не трогаем.
    hook.Add("CanTool", "zb_door_link_allow", function(ply, tr, toolname)
        if toolname ~= "door_link" then return end
        if not canUse(ply) then return end
        if not isDoor(tr.Entity) then return end
        return true
    end)
end

function TOOL:LeftClick(trace)
    local ply = self:GetOwner()
    if not canUse(ply) then
        if CLIENT then ply:ChatPrint("[Door Link] Только для суперадминов") end
        return false
    end

    local ent = trace.Entity
    if not isDoor(ent) then
        if CLIENT then
            ply:ChatPrint("[Door Link] Это не дверь! Класс: " .. (IsValid(ent) and ent:GetClass() or "nil"))
        end
        return false
    end

    if SERVER then
        if not IsValid(self.FirstDoor) then
            -- Первый клик — выбираем дверь
            self.FirstDoor = ent
            ply:ChatPrint("[Door Link] Первая дверь выбрана. Кликните по второй чтобы связать.")
        else
            -- Второй клик — связываем
            local entA = self.FirstDoor
            if entA == ent then
                ply:ChatPrint("[Door Link] Это та же самая дверь")
                return false
            end

            if not zb or not zb.AddDoorLink then
                ply:ChatPrint("[Door Link] zb.AddDoorLink не загружен — перезапустите сервер")
                return false
            end

            if zb.AddDoorLink(entA, ent) then
                ply:ChatPrint("[Door Link] Двери связаны")
            else
                ply:ChatPrint("[Door Link] Не удалось связать двери")
            end
            self.FirstDoor = nil
        end
    end

    return true
end

function TOOL:RightClick(trace)
    local ply = self:GetOwner()
    if not canUse(ply) then
        if CLIENT then ply:ChatPrint("[Door Link] Только для суперадминов") end
        return false
    end

    local ent = trace.Entity
    if not isDoor(ent) then return false end

    if SERVER then
        if not zb or not zb.RemoveDoorLink then
            ply:ChatPrint("[Door Link] zb.RemoveDoorLink не загружен — перезапустите сервер")
            return false
        end
        if zb.RemoveDoorLink(ent) then
            ply:ChatPrint("[Door Link] Связь удалена")
        else
            ply:ChatPrint("[Door Link] У этой двери не было связи")
        end
    end

    return true
end

function TOOL:Reload()
    local ply = self:GetOwner()
    if not canUse(ply) then return false end

    if SERVER then
        if IsValid(self.FirstDoor) then
            self.FirstDoor = nil
            ply:ChatPrint("[Door Link] Выбор первой двери сброшен")
        end
    end

    return true
end

function TOOL:Allowed()
    return canUse(self:GetOwner())
end

function TOOL:Deploy()
    if SERVER then
        self.FirstDoor = nil
    end
end

function TOOL.BuildCPanel(CPanel)
    CPanel:AddControl("Header", {
        Description =
            "Связывает две двери чтобы они открывались вместе.\n" ..
            "Только для суперадминов.\n\n" ..
            "ЛКМ: выбрать первую дверь, затем ЛКМ по второй — связать.\n" ..
            "ПКМ: разорвать связь.\n" ..
            "R: сбросить выбор."
    })
end

local clr = Color(20, 20, 20)
function TOOL:DrawToolScreen(width, height)
    surface.SetDrawColor(clr)
    surface.DrawRect(0, 0, width, height)

    draw.SimpleText("Door Link", "ZB_ScrappersMedium", width / 2, height / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- HUD: подсвечиваем все связанные пары + выбранную "первую" дверь.
function TOOL:DrawHUD()
    local lply = LocalPlayer()
    if not canUse(lply) then return end

    zb = zb or {}
    zb.ClDoorLinks = zb.ClDoorLinks or {}

    local function findDoor(k)
        local x, y, z, model = k:match("([%d%.%-]+)_([%d%.%-]+)_([%d%.%-]+)_(.+)")
        if not x then return nil end
        x, y, z = tonumber(x), tonumber(y), tonumber(z)
        for _, e in ipairs(ents.GetAll()) do
            if isDoor(e) then
                local p = e:GetPos()
                if math.Round(p.x, 2) == x and math.Round(p.y, 2) == y and math.Round(p.z, 2) == z and (e:GetModel() or "") == model then
                    return e
                end
            end
        end
    end

    cam.Start3D()
        local seen = {}
        for keyA, keyB in pairs(zb.ClDoorLinks) do
            if seen[keyA] or seen[keyB] then continue end
            seen[keyA] = true
            seen[keyB] = true

            local eA = findDoor(keyA)
            local eB = findDoor(keyB)
            if IsValid(eA) and IsValid(eB) then
                local pa = eA:LocalToWorld(eA:OBBCenter())
                local pb = eB:LocalToWorld(eB:OBBCenter())
                render.SetColorMaterial()
                render.DrawBeam(pa, pb, 4, 0, 1, Color(100, 255, 100, 200))
            end
        end
    cam.End3D()
end
