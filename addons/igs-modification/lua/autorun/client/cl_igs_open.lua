-- Клиентская интеграция IGS (City67)

if SERVER then return end

-- ─── F6 — открыть / закрыть донат-меню ──────────────────────────────────────
-- IGS.C.MENUBUTTON = KEY_NONE в config_sh.lua — убирает IGS-обработчик кнопки.
-- NM.Menu() содержит toggle: если фрейм открыт — закрывает, иначе — открывает.
--
-- РАНЬШЕ: F2. Перенесли на F6, чтобы не конфликтовать с F2 (RP door buy)
-- и базовым gm_showteam. Это убирает большинство причин "залипания".
--
-- ВАЖНО: используем Think + input.IsKeyDown с edge-detection, а НЕ PlayerButtonDown.
-- PlayerButtonDown не срабатывает, когда VGUI-меню захватило клавиатуру,
-- поэтому повторный F6 не мог бы закрыть открытое донат-меню.
-- input.IsKeyDown работает с движковым состоянием клавиш всегда.
--
-- Защита от:
--   • многократного открытия (debounce + lock на время асинхронного создания)
--   • залипания (форсированный reset _f6WasDown по таймауту 1.5с)
--   • случайных нажатий в текстовых полях и при вводе в чат
local TOGGLE_KEY        = KEY_F6
local TOGGLE_DELAY      = 0.40   -- минимальный интервал между toggle (сек)
local STUCK_RESET       = 1.5    -- если клавиша "висит" дольше — считаем застрявшей

local _wasDown      = false
local _downSince    = 0
local _lastToggle   = 0
local _opening      = false      -- блок на время создания фрейма

local function isInTextEntry()
    local lp = LocalPlayer()
    if IsValid(lp) and lp.IsTyping and lp:IsTyping() then return true end

    local focus = vgui.GetKeyboardFocus()
    if IsValid(focus) then
        local cls = focus:GetClassName() or ""
        if cls == "TextEntry" or cls == "DTextEntry" or cls == "RichText" then
            return true
        end
    end
    return false
end

hook.Add("Think", "igs_donate_toggle", function()
    local isDown = input.IsKeyDown(TOGGLE_KEY)

    -- Защита от залипания: если клавиша «висит» дольше STUCK_RESET секунд
    -- (например, focus переключился во время удержания) — насильно сбрасываем.
    if isDown and _wasDown and (CurTime() - _downSince) > STUCK_RESET then
        _wasDown = false
        return
    end

    if isDown and not _wasDown then
        _wasDown   = true
        _downSince = CurTime()

        if isInTextEntry() then return end

        -- Debounce (повтор / дребезг)
        if CurTime() - _lastToggle < TOGGLE_DELAY then return end
        _lastToggle = CurTime()

        -- Lock на время создания фрейма — иначе второй edge может проскочить
        -- между «открыть» и моментом, когда фрейм станет IsValid().
        if _opening then return end
        _opening = true
        timer.Simple(0.1, function() _opening = false end)

        if IGS and IGS.UI then
            IGS.UI()
        end
    elseif not isDown then
        _wasDown = false
    end
end)

-- ─── !donate / !донат — открытие через net-message от сервера ────────────────
net.Receive("igs_open_donate_client", function()
    if IGS and IGS.UI then
        IGS.UI()
    end
end)

-- ─── Кнопка в Q-меню ─────────────────────────────────────────────────────────
hook.Add("PopulateToolMenu", "igs_toolmenu_donate", function()
    spawnmenu.AddToolMenuOption("Утилиты", "Сервер", "igs_donate_btn", "Донат-меню", "", "", function(panel)
        panel:ClearControls()
        panel:Button("Открыть донат-меню", "donate_menu")
    end)
end)

-- ─── Рассылка — HUD-баннер (верхний правый) + авто-чат ───────────────────────
local BANNER_SHOW   = 10   -- секунд виден баннер
local BANNER_FADE   = 2    -- последние N сек — плавное исчезновение

local _banner = nil  -- { showUntil = number }

surface.CreateFont("igs_bc_title", {
    font = "Roboto", size = 17, weight = 700, antialias = true,
})
surface.CreateFont("igs_bc_sub", {
    font = "Roboto", size = 14, weight = 400, antialias = true,
})

local C_BLURPLE = Color(88,  101, 242)
local C_GOLD    = Color(255, 215, 60)
local C_WHITE   = Color(255, 255, 255)
local C_SUB     = Color(190, 200, 255)
local C_BG      = Color(14,  16,  32)
local C_ACCENT  = Color(58,  71, 182)

hook.Add("HUDPaint", "igs_broadcast_hud", function()
    if not _banner then return end

    local remaining = _banner.showUntil - CurTime()
    if remaining <= 0 then _banner = nil return end

    local a = remaining < BANNER_FADE
              and math.floor(255 * remaining / BANNER_FADE)
              or 255

    local BW, BH = 310, 68
    local margin  = 16
    local bx = ScrW() - BW - margin
    local by = margin + 4

    local function ca(c, oa)
        return Color(c.r, c.g, c.b, math.floor((oa or 255) * a / 255))
    end

    draw.RoundedBox(10, bx + 3, by + 3, BW, BH, ca(Color(0, 0, 0), 90))
    draw.RoundedBox(8, bx, by, BW, BH, ca(C_BG, 242))
    draw.RoundedBox(4, bx, by, 4, BH, ca(C_BLURPLE))
    surface.SetDrawColor(ca(C_ACCENT, 180))
    surface.DrawRect(bx + 4, by, BW - 4, 1)
    surface.SetDrawColor(ca(C_BLURPLE, 90))
    surface.DrawOutlinedRect(bx, by, BW, BH, 1)

    draw.SimpleText("City67 — поддержи сервер!", "igs_bc_title",
        bx + 14, by + 16,
        ca(C_GOLD), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    draw.SimpleText("Нажми F6 или напиши !donate", "igs_bc_sub",
        bx + 14, by + 38,
        ca(C_SUB), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end)

-- ─── Получение рассылки с сервера ────────────────────────────────────────────
net.Receive("igs_broadcast_msg", function()
    local msgType = net.ReadUInt(4)
    if msgType ~= 1 then return end

    -- 1. HUD-баннер
    _banner = { showUntil = CurTime() + BANNER_SHOW }

    -- 2. Запись в историю чата (без chat.Open — иначе движок опускает/поднимает руку)
    chat.AddText(
        Color(88, 101, 242), "[ City67 ] ",
        Color(220, 225, 255), "Поддержи сервер — купи донат-привилегию!\n",
        Color(170, 175, 220), "Нажми ",
        Color(130, 200, 255), "F6 ",
        Color(170, 175, 220), "или напиши ",
        Color(130, 200, 255), "!donate ",
        Color(170, 175, 220), "чтобы открыть магазин."
    )
end)
