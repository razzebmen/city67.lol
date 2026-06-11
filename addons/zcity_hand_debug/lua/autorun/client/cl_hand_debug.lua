-- =====================================================
-- ZCity Hand Debug — диагностика проблем с руками
-- =====================================================
-- Команда: zcity_hands_debug
-- Печатает текущее состояние рендера рук локального игрока:
--   • модель плеера + модель c_hands
--   • активное оружие + worldModel
--   • инвентарь (наличие brassknuckles → кастет на правой руке)
--   • активные клиентсайд-модели прицепленные к плееру
--   • видимость в зеркале zb_safezone

if not CLIENT then return end

local function dumpInventory(ply)
    local inv = ply:GetNetVar("Inventory", {})
    if not istable(inv) then
        print("  Inventory: <не таблица>")
        return
    end
    if table.IsEmpty(inv) then
        print("  Inventory: пусто")
        return
    end
    for cat, items in pairs(inv) do
        print("  [" .. tostring(cat) .. "]")
        if istable(items) then
            for k, v in pairs(items) do
                print("    " .. tostring(k) .. " = " .. tostring(v))
            end
        end
    end
end

local function dumpClientsideModels(ply)
    print("[ClientsideModel attached]")
    if IsValid(ply.c_hands) then
        print("  ply.c_hands = " .. tostring(ply.c_hands:GetModel()))
    end
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) then
        if IsValid(wep.worldModel) then
            print("  wep.worldModel = " .. tostring(wep.worldModel:GetModel()))
        end
        if IsValid(wep.model) then
            print("  wep.model (kastet?) = " .. tostring(wep.model:GetModel()))
        end
    end
end

concommand.Add("zcity_hands_debug", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then print("Нет LocalPlayer") return end

    print("===== ZCity Hand Debug =====")
    print("Player model: " .. tostring(ply:GetModel()))
    print("Hands ent: " .. tostring(ply:GetHands()))
    if IsValid(ply:GetHands()) then
        print("  Hands model: " .. tostring(ply:GetHands():GetModel()))
    end

    local wep = ply:GetActiveWeapon()
    print("Active weapon: " .. (IsValid(wep) and wep:GetClass() or "<none>"))
    if IsValid(wep) then
        print("  ViewModel: '" .. tostring(wep.ViewModel) .. "'")
        print("  WorldModel: '" .. tostring(wep.WorldModel) .. "'")
        print("  UseHands: " .. tostring(wep.UseHands))
        if wep.GetFists then
            print("  GetFists(): " .. tostring(wep:GetFists()))
        end
    end

    print("RP job: " .. tostring(ply:GetNWString("rp_job", "<none>")))
    print("Safezone (rp): " .. tostring(ply:GetNWBool("rp_safezone", false)))
    print("Safezone (zb): " .. tostring(ply:GetNWBool("zb_safezone", false)))
    print("Player class name: " .. tostring(ply.PlayerClassName))

    print("--- Inventory NetVar ---")
    dumpInventory(ply)

    dumpClientsideModels(ply)

    -- Проверяем привязанные клиентсайдные сущности
    print("--- Все clientside models в мире ---")
    local count = 0
    for _, ent in ipairs(ents.GetAll()) do
        if ent.GetModel and ent:IsValid() and ent:EntIndex() < 0 then
            -- clientside ent (entindex отрицательный)
            local p = ent:GetPos()
            local dist = ply:EyePos():Distance(p)
            if dist < 200 then
                count = count + 1
                if count <= 20 then
                    print(string.format("  [%d] %s @ %d unit, model=%s",
                        ent:EntIndex(), tostring(ent:GetClass()),
                        math.floor(dist), tostring(ent:GetModel())))
                end
            end
        end
    end
    print("  (всего рядом: " .. count .. ")")

    print("===== END =====")
end)

print("[Hand Debug] Загружен. Команда: zcity_hands_debug")
