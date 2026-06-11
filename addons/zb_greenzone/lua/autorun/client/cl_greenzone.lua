-- =====================================================
-- ZB Greenzone — клиент (полигон-призма)
-- =====================================================
-- • Принимает SYNC.
-- • Рисует яркие зелёные призмы когда у игрока выбран тул zb_greenzone.
-- • Рисует превью текущей расстановки (маркеры точек + соединительные рёбра).
-- • Баннер «БЕЗОПАСНАЯ ЗОНА» когда игрок внутри.

if not CLIENT then return end

ZBGreenzone = ZBGreenzone or {}
ZBGreenzone.Zones = ZBGreenzone.Zones or {}

local cvShow = CreateClientConVar("zb_greenzone_show", "0", true, false,
    "Принудительно показывать гранзоны (1 = всегда видны)")

-- =====================================================
-- Net: приём списка зон
-- =====================================================
net.Receive(ZBGreenzone.NET.SYNC, function()
    local n = net.ReadUInt(16)
    local list = {}
    for _ = 1, n do
        local id   = net.ReadUInt(16)
        local name = net.ReadString()
        local zMin = net.ReadFloat()
        local zMax = net.ReadFloat()
        local cnt  = net.ReadUInt(8)
        local pts = {}
        for i = 1, cnt do pts[i] = net.ReadVector() end
        list[#list + 1] = { id = id, name = name, zMin = zMin, zMax = zMax, points = pts }
    end
    ZBGreenzone.Zones = list
end)

-- Тихо: ни звуков, ни всплывашек. Игрок видит индикатор в правом нижнем углу.
net.Receive(ZBGreenzone.NET.NOTIFY, function()
    net.ReadBool()
    net.ReadString()
end)

-- =====================================================
-- Когда показывать зоны
-- =====================================================
local function isHoldingGreenzoneTool()
    local lp = LocalPlayer()
    if not IsValid(lp) then return false end
    local wep = lp:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return false end
    -- Самый надёжный способ — проверить выбранный режим тулгана через convar.
    return lp:GetInfo("gmod_toolmode") == "zb_greenzone"
end

local function shouldDrawZones()
    if cvShow:GetInt() == 1 then return true end
    return isHoldingGreenzoneTool()
end

-- =====================================================
-- Рендер призмы
-- =====================================================
local matFill = Material("models/debug/debugwhite")

local CLR_FILL_TOP   = Color(50,  255, 100, 70)
local CLR_FILL_SIDE  = Color(50,  255, 100, 45)
local CLR_EDGE       = Color(100, 255, 140, 255)
local CLR_EDGE_TOP   = Color(180, 255, 200, 255)

local CLR_PREVIEW_PT     = Color(255, 220, 80,  255)
local CLR_PREVIEW_EDGE   = Color(255, 240, 120, 230)
local CLR_PREVIEW_PEND   = Color(255, 160, 60,  180) -- линия от последней точки к прицелу

-- Нарисовать одну зону-призму
local function drawZone(z)
    local n = #z.points
    if n < 3 then return end

    local lo, hi = {}, {}
    for i = 1, n do
        lo[i] = Vector(z.points[i].x, z.points[i].y, z.zMin)
        hi[i] = Vector(z.points[i].x, z.points[i].y, z.zMax)
    end

    render.SetMaterial(matFill)

    -- Верхняя крышка (триангуляция веером от точки 1)
    for i = 2, n - 1 do
        render.DrawQuad(hi[1], hi[i], hi[i + 1], hi[i + 1], CLR_FILL_TOP)
    end
    -- Нижняя крышка
    for i = 2, n - 1 do
        render.DrawQuad(lo[1], lo[i + 1], lo[i], lo[i], CLR_FILL_TOP)
    end
    -- Боковые грани
    for i = 1, n do
        local j = i % n + 1
        render.DrawQuad(lo[i], lo[j], hi[j], hi[i], CLR_FILL_SIDE)
    end

    -- Контуры (две стороны, чтобы рёбра ярко виднелись)
    for i = 1, n do
        local j = i % n + 1
        render.DrawLine(lo[i], lo[j],  CLR_EDGE,     false)
        render.DrawLine(hi[i], hi[j],  CLR_EDGE_TOP, false)
        render.DrawLine(lo[i], hi[i],  CLR_EDGE,     false)
    end
end

hook.Add("PostDrawTranslucentRenderables", "ZBGreenzone_Draw", function(_, drawingSkybox)
    if drawingSkybox then return end
    if not shouldDrawZones() then return end

    for _, z in ipairs(ZBGreenzone.Zones) do
        drawZone(z)
    end

    -- Превью текущей расстановки
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local count = lp:GetNWInt("zb_gz_count", 0)
    if count <= 0 then return end

    local pts = {}
    for i = 1, count do
        pts[i] = lp:GetNWVector("zb_gz_p" .. i, vector_origin)
    end

    -- Маркеры точек
    render.SetColorMaterial()
    for i, p in ipairs(pts) do
        render.DrawSphere(p, 6, 12, 12, CLR_PREVIEW_PT)
    end

    -- Линии между поставленными точками
    for i = 1, count - 1 do
        render.DrawLine(pts[i], pts[i + 1], CLR_PREVIEW_EDGE, false)
    end

    -- Линия от последней точки к прицелу (показывает где будет следующая)
    if count < 4 then
        local tr = util.TraceLine({
            start  = lp:EyePos(),
            endpos = lp:EyePos() + lp:GetAimVector() * 16384,
            filter = lp,
            mask   = MASK_SOLID_BRUSHONLY,
        })
        render.DrawLine(pts[count], tr.HitPos, CLR_PREVIEW_PEND, false)
        render.DrawSphere(tr.HitPos, 4, 12, 12, CLR_PREVIEW_PEND)
    end
end)

-- =====================================================
-- HUD: подписи зон и баннер «БЕЗОПАСНАЯ ЗОНА»
-- =====================================================
hook.Add("HUDPaint", "ZBGreenzone_Labels", function()
    if not shouldDrawZones() then return end
    for _, z in ipairs(ZBGreenzone.Zones) do
        local cx, cy = 0, 0
        for _, p in ipairs(z.points) do cx = cx + p.x; cy = cy + p.y end
        cx = cx / #z.points; cy = cy / #z.points
        local label = Vector(cx, cy, z.zMax + 16)
        local sp = label:ToScreen()
        if sp.visible then
            draw.SimpleTextOutlined(
                "Грин-зона #" .. z.id .. (z.name ~= "" and (" • " .. z.name) or ""),
                "DermaDefault", sp.x, sp.y,
                Color(220, 255, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
                1, Color(0, 0, 0, 220)
            )
        end
    end

    -- Подсказка по количеству поставленных точек
    local lp = LocalPlayer()
    if IsValid(lp) and isHoldingGreenzoneTool() then
        local count = lp:GetNWInt("zb_gz_count", 0)
        if count > 0 then
            draw.SimpleTextOutlined(
                "Точки: " .. count .. "/4  (ЛКМ — добавить, ПКМ — создать, Shift+R — сброс)",
                "DermaDefault", ScrW() * 0.5, ScrH() - 80,
                Color(255, 230, 130), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                1, Color(0, 0, 0, 220)
            )
        end
    end
end)

-- Создаём жирный шрифт
surface.CreateFont("ZBGreenzone_Bold", {
    font      = "Roboto",
    size      = 18,
    weight    = 800,
    antialias = true,
    extended  = true,
})

-- Минималистичный индикатор: только надпись в самом углу
hook.Add("HUDPaint", "ZBGreenzone_Status", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if not lp:GetNWBool("zb_safezone", false) then return end
    if not lp:Alive() then return end

    draw.SimpleText("БЕЗОПАСНАЯ ЗОНА", "ZBGreenzone_Bold", ScrW() - 10, ScrH() - 5,
        Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end)

print("[Greenzone] cl_greenzone.lua загружен")
