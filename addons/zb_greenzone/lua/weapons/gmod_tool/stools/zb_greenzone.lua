-- =====================================================
-- STool: Грин-зона (zb_greenzone) — 4-точечный полигон
-- =====================================================
-- ЛКМ  — поставить следующую точку (1 → 2 → 3 → 4). На 4-й точке
--        зона создаётся автоматически.
-- ПКМ  — досрочно создать зону (если уже стоит ≥3 точки).
-- Reload — удалить зону под прицелом / ближайшую.
-- Shift+Reload — сбросить незаконченную расстановку точек.

if SERVER then
    AddCSLuaFile()
end

TOOL.Category   = "Админ"
TOOL.Name       = "#tool.zb_greenzone.name"
TOOL.Command    = nil
TOOL.ConfigName = ""

TOOL.ClientConVar = TOOL.ClientConVar or {}
TOOL.ClientConVar["zonename"] = ""
TOOL.ClientConVar["height"]   = "200"

if CLIENT then
    language.Add("tool.zb_greenzone.name",  "Грин-зона")
    language.Add("tool.zb_greenzone.desc",  "Безопасные зоны с авто-god (4 точки)")
    language.Add("tool.zb_greenzone.0",
        "ЛКМ: точка 1 → 2 → 3 → 4 (авто-создание)  •  ПКМ: создать сейчас (≥3 точки)  •  Reload: удалить  •  Shift+Reload: сброс")
    print("[Greenzone] stool zb_greenzone загружен на КЛИЕНТЕ")
end

if SERVER then
    print("[Greenzone] stool zb_greenzone загружен на СЕРВЕРЕ")
end

local MAX_POINTS = 4

local function isAllowed(ply)
    return IsValid(ply) and ply:IsSuperAdmin()
end

local function aimPoint(ply)
    local tr = util.TraceLine({
        start  = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * 16384,
        filter = ply,
        mask   = MASK_SOLID_BRUSHONLY,
    })
    return tr.HitPos
end

-- =====================================================
-- Серверные хелперы синхронизации точек в NW
-- =====================================================
local function pushPointsNW(ply)
    if CLIENT then return end
    local pts = ply.zb_gz_points or {}
    ply:SetNWInt("zb_gz_count", #pts)
    for i = 1, MAX_POINTS do
        ply:SetNWVector("zb_gz_p" .. i, pts[i] or vector_origin)
    end
end

local function clearPoints(ply)
    if CLIENT then return end
    ply.zb_gz_points = {}
    pushPointsNW(ply)
end

local function addPoint(ply, p)
    if CLIENT then return end
    ply.zb_gz_points = ply.zb_gz_points or {}
    table.insert(ply.zb_gz_points, p)
    pushPointsNW(ply)
end

local function sendCreate(ply, height, name)
    if CLIENT then return end
    if not (ZBGreenzone and ZBGreenzone.Create) then
        ply:ChatPrint("[Грин-зона] ОШИБКА: серверный модуль не загружен.")
        return false
    end
    local pts = ply.zb_gz_points or {}
    if #pts < 3 then
        ply:ChatPrint("[Грин-зона] Нужно минимум 3 точки, поставлено " .. #pts)
        return false
    end
    local z, err = ZBGreenzone.Create(pts, height, name)
    if not z then
        ply:ChatPrint("[Грин-зона] Ошибка: " .. (err or "?"))
        return false
    end
    ply:ChatPrint(string.format("[Грин-зона] Создана: %s (id %d, точек %d)", z.name, z.id, #z.points))
    clearPoints(ply)
    return true
end

-- =====================================================
-- ЛКМ — следующая точка
-- =====================================================
function TOOL:LeftClick(trace)
    local ply = self:GetOwner()
    if not isAllowed(ply) then
        if SERVER then ply:ChatPrint("[Грин-зона] Нужны права superadmin.") end
        return false
    end
    if CLIENT then return true end

    local p = aimPoint(ply)
    ply.zb_gz_points = ply.zb_gz_points or {}

    if #ply.zb_gz_points >= MAX_POINTS then
        ply:ChatPrint("[Грин-зона] Уже стоит " .. MAX_POINTS .. " точек, ПКМ для создания или Shift+Reload для сброса.")
        return false
    end

    addPoint(ply, p)
    local n = #ply.zb_gz_points
    ply:ChatPrint(string.format("[Грин-зона] Точка %d/%d: %.0f %.0f %.0f", n, MAX_POINTS, p.x, p.y, p.z))

    if n >= MAX_POINTS then
        -- 4-я точка → создаём автоматически
        local h = tonumber(self:GetClientNumber("height", 200)) or 200
        local name = self:GetClientInfo("zonename") or ""
        if name == "" then name = nil end
        sendCreate(ply, h, name)
    end
    return true
end

-- =====================================================
-- ПКМ — досрочно создать
-- =====================================================
function TOOL:RightClick(trace)
    local ply = self:GetOwner()
    if not isAllowed(ply) then
        if SERVER then ply:ChatPrint("[Грин-зона] Нужны права superadmin.") end
        return false
    end
    if CLIENT then return true end

    local h = tonumber(self:GetClientNumber("height", 200)) or 200
    local name = self:GetClientInfo("zonename") or ""
    if name == "" then name = nil end
    return sendCreate(ply, h, name)
end

-- =====================================================
-- Reload — удалить зону / Shift+Reload — сброс точек
-- =====================================================
function TOOL:Reload(trace)
    local ply = self:GetOwner()
    if not isAllowed(ply) then return false end
    if CLIENT then return true end

    if ply:KeyDown(IN_SPEED) then
        if ply.zb_gz_points and #ply.zb_gz_points > 0 then
            clearPoints(ply)
            ply:ChatPrint("[Грин-зона] Расстановка сброшена.")
        end
        return true
    end

    if not (ZBGreenzone and ZBGreenzone.FindContaining) then
        ply:ChatPrint("[Грин-зона] ОШИБКА: серверный модуль не загружен.")
        return false
    end

    local pos = aimPoint(ply)
    local target = ZBGreenzone.FindContaining(pos)
    if not target then target = ZBGreenzone.FindContaining(ply:GetPos()) end
    if not target then
        local nearest, dist = ZBGreenzone.NearestTo(pos)
        if not nearest then
            ply:ChatPrint("[Грин-зона] Зон на карте нет.")
            return false
        end
        if dist and dist > 4096 then
            ply:ChatPrint(string.format("[Грин-зона] Ближайшая слишком далеко: %d ед.", math.floor(dist)))
            return false
        end
        target = nearest
    end

    ZBGreenzone.DeleteById(target.id)
    ply:ChatPrint("[Грин-зона] Удалена: " .. (target.name or target.id))
    return true
end

-- =====================================================
-- Контекстная панель
-- =====================================================
if CLIENT then
    function TOOL.BuildCPanel(panel)
        panel:Help("Грин-зоны: безопасные зоны с авто-god mode.")
        panel:Help("ЛКМ — следующая точка (1→2→3→4 авто-создание).")
        panel:Help("ПКМ — создать сейчас (нужно ≥3 точки).")
        panel:Help("Reload — удалить зону. Shift+Reload — сброс точек.")
        panel:TextEntry("Название (опционально):", "zb_greenzone_zonename")
        panel:NumSlider("Высота зоны (ед.):", "zb_greenzone_height", 32, 1024, 0)
        panel:Button("Список зон в чат", "zb_greenzone_list")
        panel:Button("Перезагрузить из файла", "zb_greenzone_reload")
        panel:CheckBox("Показывать зоны всегда (отладка)", "zb_greenzone_show")
    end
end
