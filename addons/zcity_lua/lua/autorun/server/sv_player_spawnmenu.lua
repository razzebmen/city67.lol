--[[ СПАВН МЕНЮ ДЛЯ ИГРОКОВ - ОТКЛЮЧЕНО

util.AddNetworkString("zb_player_spawn_prop")

-- Разрешённые пропы для обычных игроков
local allowedProps = {
    "models/props_c17/FurnitureCouch001a.mdl",
    "models/props_c17/FurnitureTable001a.mdl",
    "models/props_c17/FurnitureChair001a.mdl",
    "models/props_c17/FurnitureDresser001a.mdl",
    "models/props_c17/FurnitureBathtub001a.mdl",
    "models/props_c17/FurnitureToilet001a.mdl",
    "models/props_c17/FurnitureSink001a.mdl",
    "models/props_c17/FurnitureLamp001a.mdl",
    "models/props_c17/FurnitureLamp002a.mdl",
    "models/props_c17/FurnitureFridge001a.mdl",
    "models/props_c17/FurnitureStove001a.mdl",
    "models/props_c17/FurnitureMicrowave001a.mdl",
    "models/props_c17/FurnitureTV001a.mdl",
    "models/props_c17/FurnitureBookcase001a.mdl",
    "models/props_c17/FurnitureBed001a.mdl",
    "models/hunter/plates/plate.mdl",
    "models/hunter/plates/plate1x1.mdl",
    "models/hunter/plates/plate1x2.mdl",
    "models/hunter/plates/plate2x2.mdl",
    "models/hunter/plates/plate2x4.mdl",
    "models/hunter/plates/plate4x4.mdl",
    "models/hunter/plates/plate1x1corner.mdl",
    "models/hunter/plates/plate1x2corner.mdl",
    "models/hunter/blocks/cube025x025x025.mdl",
    "models/hunter/blocks/cube05x05x05.mdl",
    "models/hunter/blocks/cube1x1x1.mdl",
    "models/hunter/blocks/cube2x2x2.mdl",
    "models/hunter/misc/sphere025x025.mdl",
    "models/hunter/misc/sphere05x05.mdl",
    "models/hunter/misc/sphere1x1.mdl",
    "models/hunter/misc/cone1x1.mdl",
    "models/hunter/misc/cone2x2.mdl",
    "models/hunter/misc/cylinder025x025.mdl",
    "models/hunter/misc/cylinder05x05.mdl",
    "models/hunter/misc/cylinder1x1.mdl",
    "models/hunter/misc/cylinder2x2.mdl",
    "models/props_junk/wood_crate001a.mdl",
    "models/props_junk/wood_crate002a.mdl",
    "models/props_c17/lockers001a.mdl",
    "models/props_c17/fence001a.mdl",
    "models/props_c17/fence002a.mdl",
    "models/props_c17/fence003a.mdl",
    "models/props_c17/staircase001a.mdl",
    "models/props_c17/door01_left.mdl",
    "models/props_c17/door02_left.mdl",
    "models/props_c17/tv_monitor01.mdl",
    "models/props_c17/computer01_keyboard.mdl",
    "models/props_c17/computer01_screen.mdl",
    "models/props_c17/canister01a.mdl",
    "models/props_c17/oildrum001.mdl",
    "models/props_junk/garbage_bag001a.mdl",
    "models/props_junk/garbage_metalcan001a.mdl",
}

local allowedTools = {
    "material", "color", "light", "keypad", "2dtext",
    "weld", "rope", "nocollide", "faceposer", "remover",
    "axis", "ballsocket", "thruster", "wheel", "slider",
    "hydraulic", "winch", "elastic", "hoverball", "emitter",
    "paint", "inflator", "resizer", "stacker", "smartsnap",
    "easy_weld", "easy_ballsocket",
}

local allowedPropsSet = {}
for _, v in ipairs(allowedProps) do allowedPropsSet[v:lower()] = true end

local allowedToolsSet = {}
for _, v in ipairs(allowedTools) do allowedToolsSet[v:lower()] = true end

hook.Add("PlayerSpawnProp", "RestrictedSpawnMenu", function(ply, model)
    if ply:IsAdmin() then return true end
    if not CurrentRound or not CurrentRound() or CurrentRound().name ~= "roleplay" then return false end
    if allowedPropsSet[model:lower()] then return true end
    return false
end)

net.Receive("zb_player_spawn_prop", function(len, ply)
    if not CurrentRound or not CurrentRound() or CurrentRound().name ~= "roleplay" then return end
    if not IsValid(ply) or not ply:Alive() then return end
    local mdl = net.ReadString()
    if not allowedPropsSet[mdl:lower()] then return end
    local tr = ply:GetEyeTrace()
    local pos = tr.HitPos + tr.HitNormal * 10
    local prop = ents.Create("prop_physics")
    prop:SetModel(mdl)
    prop:SetPos(pos)
    prop:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    prop:SetOwner(ply)
    prop:Spawn()
    prop:Activate()
    undo.Create("prop")
    undo.AddEntity(prop)
    undo.SetPlayer(ply)
    undo.Finish()
    cleanup.Add(ply, "props", prop)
end)

hook.Add("CanTool", "RestrictedSpawnMenu", function(ply, tr, tool)
    if ply:IsAdmin() then return true end
    if not CurrentRound or not CurrentRound() or CurrentRound().name ~= "roleplay" then return false end
    if allowedToolsSet[tool:lower()] then return true end
    return false
end)

hook.Add("PhysgunPickup", "RestrictedSpawnMenu", function(ply, ent)
    if ply:IsAdmin() then return true end
    if not CurrentRound or not CurrentRound() or CurrentRound().name ~= "roleplay" then return false end
    if ent:GetOwner() == ply then return true end
    return false
end)

hook.Add("PlayerDeath", "CleanupPropsOnDeath", function(ply)
    if ply:IsAdmin() then return end
    if not CurrentRound or not CurrentRound() or CurrentRound().name ~= "roleplay" then return end
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent:GetOwner() == ply and ent:GetClass() == "prop_physics" then
            ent:Remove()
        end
    end
end)

-- НЕ ВЫДАВАТЬ физган и тулган игрокам
-- hook.Add("PlayerSpawn", "GivePhysgunToolgun", function(ply)
--     if not CurrentRound or not CurrentRound() or CurrentRound().name ~= "roleplay" then return end
--     timer.Simple(0.1, function()
--         if not IsValid(ply) then return end
--         ply:Give("weapon_physgun")
--         ply:Give("gmod_tool")
--     end)
-- end)

hook.Add("PhysgunPickup", "RestrictPhysgun", function(ply, ent)
    if ply:IsAdmin() then return true end
    if not CurrentRound or not CurrentRound() or CurrentRound().name ~= "roleplay" then return false end
    if ent:IsPlayer() then return false end
    if ent:IsRagdoll() then return false end
    if ent:GetClass() == "prop_ragdoll" then return false end
    if ent:GetOwner() == ply then return true end
    return false
end)

hook.Add("CanTool", "RestrictToolgun", function(ply, tr, tool)
    if ply:IsAdmin() then return true end
    if not CurrentRound or not CurrentRound() or CurrentRound().name ~= "roleplay" then return false end
    if not allowedToolsSet[tool:lower()] then return false end
    local ent = tr.Entity
    if tool == "remover" or tool == "light" or tool == "2dtext" or tool == "keypad" then return true end
    if IsValid(ent) and ent:GetOwner() == ply then return true end
    if not IsValid(ent) or ent:IsWorld() then return true end
    return false
end)

]]
