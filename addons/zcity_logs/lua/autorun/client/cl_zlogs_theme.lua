--[[
    ZCity Logs — клиентская тема: шрифты + утилиты отрисовки.
]]

if not ZLogs then
    include("autorun/sh_zlogs.lua")
end

ZLogs.Fonts = ZLogs.Fonts or {}

-- Шрифты
surface.CreateFont("ZLogs.Header", {
    font   = "Roboto",
    size   = 22,
    weight = 700,
    extended = true,
})
surface.CreateFont("ZLogs.Title", {
    font   = "Roboto",
    size   = 18,
    weight = 600,
    extended = true,
})
surface.CreateFont("ZLogs.Text", {
    font   = "Roboto",
    size   = 15,
    weight = 400,
    extended = true,
})
surface.CreateFont("ZLogs.TextBold", {
    font   = "Roboto",
    size   = 15,
    weight = 600,
    extended = true,
})
surface.CreateFont("ZLogs.Small", {
    font   = "Roboto",
    size   = 13,
    weight = 400,
    extended = true,
})
surface.CreateFont("ZLogs.Mono", {
    font   = "Consolas",
    size   = 14,
    weight = 400,
    extended = true,
})

-- Хелперы отрисовки
function ZLogs.DrawPanel(x, y, w, h, color)
    surface.SetDrawColor(color or ZLogs.Theme.BgPanel)
    surface.DrawRect(x, y, w, h)
end

function ZLogs.DrawBorder(x, y, w, h, color, thick)
    thick = thick or 1
    surface.SetDrawColor(color or ZLogs.Theme.Border)
    surface.DrawOutlinedRect(x, y, w, h, thick)
end

function ZLogs.DrawAccentLine(x, y, w, color)
    surface.SetDrawColor(color or ZLogs.Theme.Accent)
    surface.DrawRect(x, y, w, 2)
end

-- Кнопка категории — угловатая, жёсткая
function ZLogs.DrawChip(x, y, w, h, color, active)
    if active then
        -- Активная: тёмный фон с цветной вертикальной полосой
        local bg = Color(
            math.floor(color.r * 0.18),
            math.floor(color.g * 0.18),
            math.floor(color.b * 0.18), 240)
        draw.RoundedBox(2, x, y, w, h, bg)
        surface.SetDrawColor(color)
        surface.DrawRect(x, y, 3, h)
    else
        -- Неактивная: очень тёмный, почти невидимый
        local bg = Color(
            math.floor(color.r * 0.08),
            math.floor(color.g * 0.08),
            math.floor(color.b * 0.08), 180)
        draw.RoundedBox(2, x, y, w, h, bg)
    end
end

-- Тёмный полупрозрачный фон под модалкой
function ZLogs.DrawDim(w, h)
    surface.SetDrawColor(0, 0, 0, 180)
    surface.DrawRect(0, 0, w, h)
end
