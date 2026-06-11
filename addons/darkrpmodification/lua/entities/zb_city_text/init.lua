AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- Путь к файлу сохранения
local saveFile = "zcity/city_texts.txt"

-- Загрузка табличек из файла
local function LoadCityTexts()
    if not file.Exists(saveFile, "DATA") then return end
    
    local data = file.Read(saveFile, "DATA")
    if not data then return end
    
    local texts = util.JSONToTable(data)
    if not texts then return end
    
    for i, textData in ipairs(texts) do
        local ent = ents.Create("zb_city_text")
        if IsValid(ent) then
            ent:SetPos(Vector(textData.pos.x, textData.pos.y, textData.pos.z))
            ent:SetAngles(Angle(textData.ang.p, textData.ang.y, textData.ang.r))
            ent:SetTextType(textData.type)
            ent:Spawn()
            ent:Activate()
            ent.IsLoaded = true
        end
    end
end

-- Сохранение табличек в файл
local function SaveCityTexts()
    local texts = {}
    
    for _, ent in ipairs(ents.FindByClass("zb_city_text")) do
        if IsValid(ent) then
            local pos = ent:GetPos()
            local ang = ent:GetAngles()
            local textType = ent:GetTextType()
            
            table.insert(texts, {
                pos = {x = pos.x, y = pos.y, z = pos.z},
                ang = {p = ang.p, y = ang.y, r = ang.r},
                type = textType
            })
        end
    end
    
    if not file.Exists("zcity", "DATA") then
        file.CreateDir("zcity")
    end
    
    file.Write(saveFile, util.TableToJSON(texts, true))
end

-- Загружаем таблички при инициализации карты (один раз при старте сервера)
hook.Add("InitPostEntity", "LoadCityTexts", function()
    timer.Simple(2, function()
        LoadCityTexts()
    end)
end)

-- Сохраняем таблички при выключении сервера
hook.Add("ShutDown", "SaveCityTexts", function()
    SaveCityTexts()
end)

-- Сохраняем позиции табличек перед CleanUpMap
local savedTexts = {}
hook.Add("PreCleanupMap", "SaveCityTextsBeforeCleanup", function()
    savedTexts = {}
    
    for _, ent in ipairs(ents.FindByClass("zb_city_text")) do
        if IsValid(ent) then
            local pos = ent:GetPos()
            local ang = ent:GetAngles()
            local textType = ent:GetTextType()
            
            table.insert(savedTexts, {
                pos = pos,
                ang = ang,
                type = textType
            })
        end
    end
end)

-- Восстанавливаем таблички после CleanUpMap
hook.Add("PostCleanupMap", "RestoreCityTextsAfterCleanup", function()
    if #savedTexts == 0 then return end
    
    timer.Simple(0.1, function()
        for i, textData in ipairs(savedTexts) do
            local ent = ents.Create("zb_city_text")
            if IsValid(ent) then
                ent:SetPos(textData.pos)
                ent:SetAngles(textData.ang)
                ent:SetTextType(textData.type)
                ent:Spawn()
                ent:Activate()
                ent.IsLoaded = true
            end
        end
    end)
end)

-- Команда для ручного сохранения
concommand.Add("city_text_save", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    SaveCityTexts()
    if IsValid(ply) then
        ply:ChatPrint("[City Text] Таблички сохранены")
    end
end)

-- Экспортируем функции для использования в режиме
_G.LoadCityTexts = LoadCityTexts
_G.SaveCityTexts = SaveCityTexts

function ENT:Initialize()
    self:SetModel("models/hunter/plates/plate2x2.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    
    -- Помечаем как постоянную энтити
    self:SetPersistent(true)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end
    
    -- Дублируем через NWString для надёжности
    timer.Simple(0, function()
        if IsValid(self) then
            local textType = self:GetTextType()
            self:SetNWString("TextType", textType)
        end
    end)
    
    -- Автосохранение при создании (если не загружается из файла)
    if not self.IsLoaded then
        timer.Simple(0.2, function()
            if SaveCityTexts then
                SaveCityTexts()
            end
        end)
    end
end

function ENT:Think()
    self:NextThink(CurTime() + 1)
    return true
end

function ENT:OnRemove()
    -- Автосохранение при удалении
    timer.Simple(0.1, function()
        if SaveCityTexts then
            SaveCityTexts()
        end
    end)
end
