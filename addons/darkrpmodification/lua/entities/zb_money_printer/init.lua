AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_c17/consolebox01a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
    
    -- Инициализация переменных
    self:SetNWInt("Money", 0)
    self:SetNWString("Owner", "")
    self:SetNWString("OwnerName", "")
    
    -- Таймер для генерации денег
    timer.Create("MoneyPrinter_" .. self:EntIndex(), 10, 0, function()
        if not IsValid(self) then return end
        
        local currentMoney = self:GetNWInt("Money", 0)
        local moneyPerTick = self:GetMoneyPerTick()
        
        self:SetNWInt("Money", currentMoney + moneyPerTick)
    end)
end

function ENT:SetPrinterOwner(ply)
    if not IsValid(ply) then return end
    
    self:SetNWString("Owner", ply:SteamID())
    self:SetNWString("OwnerName", ply:GetName())
end

function ENT:GetMoneyPerTick()
    local printerType = self:GetPrinterType()
    
    if printerType == "basic" then
        return 10
    elseif printerType == "medium" then
        return 25
    elseif printerType == "advanced" then
        return 50
    end
    
    return 10
end

function ENT:Use(activator, caller)
    if not IsValid(caller) or not caller:IsPlayer() then return end
    
    local owner = self:GetNWString("Owner", "")
    
    -- Только владелец может забрать деньги
    if owner ~= caller:SteamID() then
        net.Start("roleplay_error_message")
        net.WriteString("Это не ваш принтер")
        net.Send(caller)
        return
    end
    
    local money = self:GetNWInt("Money", 0)
    
    if money <= 0 then
        net.Start("roleplay_error_message")
        net.WriteString("В принтере нет денег")
        net.Send(caller)
        return
    end
    
    -- Передаём деньги игроку
    local round = CurrentRound()
    if round and round.name == "roleplay" then
        round:AddMoney(caller, money)
        
        net.Start("roleplay_printer_collect")
        net.WriteInt(money, 32)
        net.Send(caller)
        
        self:SetNWInt("Money", 0)
    end
end

function ENT:OnTakeDamage(dmg)
    self:TakePhysicsDamage(dmg)
    
    local health = self:Health()
    health = health - dmg:GetDamage()
    
    if health <= 0 then
        self:Remove()
    else
        self:SetHealth(health)
    end
end

function ENT:OnRemove()
    timer.Remove("MoneyPrinter_" .. self:EntIndex())
end
