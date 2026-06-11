--[[
    Чат-команды для связывания дверей (только суперадмин).
    Не требуют тулгана — работают через прицел игрока.

    !linkdoor   — выбрать первую дверь, потом вторую (две команды подряд)
    !unlinkdoor — разорвать связь у двери под прицелом
    !showlinks  — на 10 сек показать все связи дверей лучами
--]]

local function isDoor(ent)
    if not IsValid(ent) then return false end
    local c = ent:GetClass()
    return c == "prop_door_rotating" or c == "func_door" or c == "func_door_rotating"
end

local function canUse(ply)
    return IsValid(ply) and ply:IsSuperAdmin()
end

local pendingFirst = {}

local function GetTracedDoor(ply)
    local tr = ply:GetEyeTrace()
    if not isDoor(tr.Entity) then return nil end
    -- Проверка дистанции — не дать связывать дальние двери случайно
    if ply:GetPos():Distance(tr.Entity:GetPos()) > 300 then return nil end
    return tr.Entity
end

util.AddNetworkString("zb_door_link_show")

hook.Add("PlayerSay", "zb_door_link_chat", function(ply, text)
    if not canUse(ply) then return end

    local cmd = string.lower(string.Trim(text or ""))

    if cmd == "!linkdoor" or cmd == "/linkdoor" then
        local ent = GetTracedDoor(ply)
        if not ent then
            ply:ChatPrint("[Door Link] Наведите на дверь и повторите команду (макс 300 юнитов)")
            return ""
        end

        local sid = ply:SteamID()
        if not pendingFirst[sid] then
            pendingFirst[sid] = ent
            ply:ChatPrint("[Door Link] Первая дверь выбрана. Наведитесь на вторую и повторите !linkdoor")
        else
            local entA = pendingFirst[sid]
            if not IsValid(entA) then
                pendingFirst[sid] = ent
                ply:ChatPrint("[Door Link] Первая дверь стала невалидной. Эта будет первой. Наведитесь на вторую и повторите !linkdoor")
                return ""
            end
            if entA == ent then
                ply:ChatPrint("[Door Link] Это та же самая дверь")
                return ""
            end
            if zb.AddDoorLink(entA, ent) then
                ply:ChatPrint("[Door Link] Двери связаны")
            else
                ply:ChatPrint("[Door Link] Не удалось связать двери")
            end
            pendingFirst[sid] = nil
        end
        return ""
    end

    if cmd == "!unlinkdoor" or cmd == "/unlinkdoor" then
        local ent = GetTracedDoor(ply)
        if not ent then
            ply:ChatPrint("[Door Link] Наведите на дверь и повторите команду")
            return ""
        end
        if zb.RemoveDoorLink(ent) then
            ply:ChatPrint("[Door Link] Связь удалена")
        else
            ply:ChatPrint("[Door Link] У этой двери не было связи")
        end
        return ""
    end

    if cmd == "!showlinks" or cmd == "/showlinks" then
        net.Start("zb_door_link_show")
            net.WriteFloat(10)
        net.Send(ply)
        ply:ChatPrint("[Door Link] Подсветка связей на 10 сек")
        return ""
    end

    if cmd == "!resetlink" or cmd == "/resetlink" then
        pendingFirst[ply:SteamID()] = nil
        ply:ChatPrint("[Door Link] Выбор первой двери сброшен")
        return ""
    end

    if cmd == "!doorlinkhelp" or cmd == "/doorlinkhelp" then
        ply:ChatPrint("[Door Link] Команды (только superadmin):")
        ply:ChatPrint("  !linkdoor — выбрать первую/вторую дверь и связать")
        ply:ChatPrint("  !unlinkdoor — разорвать связь у двери под прицелом")
        ply:ChatPrint("  !showlinks — показать связи на 10 сек")
        ply:ChatPrint("  !resetlink — сбросить выбранную первую дверь")
        return ""
    end
end)

hook.Add("PlayerDisconnected", "zb_door_link_chat_cleanup", function(ply)
    pendingFirst[ply:SteamID()] = nil
end)
