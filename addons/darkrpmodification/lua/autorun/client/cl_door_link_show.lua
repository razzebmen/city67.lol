-- Подсветка связей дверей (по команде !showlinks).

local showUntil = 0

net.Receive("zb_door_link_show", function()
    local secs = net.ReadFloat()
    showUntil = CurTime() + (secs or 10)
end)

local function isDoor(ent)
    if not IsValid(ent) then return false end
    local c = ent:GetClass()
    return c == "prop_door_rotating" or c == "func_door" or c == "func_door_rotating"
end

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

hook.Add("PostDrawOpaqueRenderables", "zb_door_link_show_draw", function()
    if CurTime() > showUntil then return end
    if not zb or not zb.ClDoorLinks then return end

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
            render.DrawBeam(pa, pb, 4, 0, 1, Color(100, 255, 100, 220))
            render.DrawSphere(pa, 6, 12, 12, Color(255, 220, 50, 200))
            render.DrawSphere(pb, 6, 12, 12, Color(255, 220, 50, 200))
        end
    end
end)
