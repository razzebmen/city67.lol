AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Кастомный материал автомата с оружием (АК-47).
-- Переопределяем ВСЕ материал-слоты модели VendingMachineSoda01a, чтобы все
-- стороны (лицевая, бока, верх, низ, задняя стекляная панель) были одинаковыми.
-- Обычные prop'ы с лимонадом на карте НЕ затрагиваются (SubMaterial/SetMaterial
-- живут только на конкретном entity, не на модели глобально).
local AK_MATERIAL = "zb_weapons/dispenser_ak47"

function ENT:Initialize()
    self:SetModel("models/props_interiors/VendingMachineSoda01a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    -- НЕ используем self:SetMaterial(...) — он переопределяет mesh shader и
    -- ломает UV mapping prop'а (все грани начинают показывать один UV-блок).
    -- Только SetSubMaterial — он заменяет конкретный slot, сохраняя UV.
    --
    -- Узнаём реальные slot'ы модели через GetMaterials() и логируем —
    -- удобно если потом понадобится отдельный материал на отдельный slot
    -- (например стекло витрины с $translucent).
    local mats = self:GetMaterials() or {}
    if #mats > 0 then
        print(string.format("[zb_gun_shop] Модель имеет %d slot'ов:", #mats))
        for i, m in ipairs(mats) do
            print(string.format("  slot[%d] = %s", i - 1, tostring(m)))
        end
    end

    -- Перекрываем все реальные слоты + запас на случай если GetMaterials
    -- что-то пропустит. Несуществующие slot'ы GMod игнорирует без ошибок.
    local maxSlot = math.max(#mats - 1, 5)
    for i = 0, maxSlot do
        self:SetSubMaterial(i, AK_MATERIAL)
    end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
end

-- Игрок нажимает E — отправляем ему сигнал открыть меню
function ENT:Use(activator, caller)
    if not IsValid(caller) or not caller:IsPlayer() then return end

    local round = CurrentRound()
    if not round or round.name ~= "roleplay" then return end
    if not caller:Alive() then return end

    net.Start("zb_gun_shop_open")
    net.WriteEntity(self)
    net.Send(caller)
end

function ENT:OnRemove()
end
