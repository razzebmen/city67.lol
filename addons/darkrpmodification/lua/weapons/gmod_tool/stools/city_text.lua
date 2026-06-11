TOOL.Category = "ZCity Roleplay"
TOOL.Name = "City Text Placer"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("tool.city_text.name", "City Text Placer")
    language.Add("tool.city_text.desc", "Размещает 2D текст правил города или казны")
    language.Add("tool.city_text.0", "ЛКМ: Разместить текст | ПКМ: Удалить текст")
end

TOOL.ClientConVar["texttype"] = "rules" -- rules или treasury

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    
    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsAdmin() then
        net.Start("roleplay_error_message")
        net.WriteString("Только администраторы могут использовать этот инструмент")
        net.Send(ply)
        return false
    end
    
    local textType = self:GetClientInfo("texttype")
    
    local textEnt = ents.Create("zb_city_text")
    if IsValid(textEnt) then
        textEnt:SetTextType(textType)
        textEnt:SetPos(trace.HitPos + trace.HitNormal * 1)
        
        local ang = trace.HitNormal:Angle()
        ang:RotateAroundAxis(ang:Forward(), 90)
        ang:RotateAroundAxis(ang:Right(), -90)
        textEnt:SetAngles(ang)
        
        textEnt:Spawn()
        textEnt:Activate()
        
        timer.Simple(0.1, function()
            if IsValid(textEnt) then
                textEnt:SetTextType(textType)
            end
        end)
        
        undo.Create("City Text")
        undo.AddEntity(textEnt)
        undo.SetPlayer(ply)
        undo.Finish()
        
        return true
    end
    
    return false
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    
    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsAdmin() then
        net.Start("roleplay_error_message")
        net.WriteString("Только администраторы могут использовать этот инструмент")
        net.Send(ply)
        return false
    end
    
    local ent = trace.Entity
    if IsValid(ent) and ent:GetClass() == "zb_city_text" then
        ent:Remove()
        return true
    end
    
    return false
end

function TOOL.BuildCPanel(panel)
    panel:Help("Инструмент для размещения 2D текстов города")
    panel:Help("ЛКМ - разместить текст")
    panel:Help("ПКМ - удалить текст")
    
    local combo = panel:ComboBox("Тип текста", "city_text_texttype")
    combo:AddChoice("Правила города", "rules", true)
    combo:AddChoice("Казна города", "treasury", false)
    combo:AddChoice("Разведка ЦАХАЛ (инфо о мэрии)", "isis_intel", false)
    combo:AddChoice("Инфо об ограблении казны", "isis_robbery", false)
end
