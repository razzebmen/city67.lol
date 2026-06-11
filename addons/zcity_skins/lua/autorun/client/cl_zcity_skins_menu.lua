--[[---------------------------------------------------------------------------
ZCity Skins — UI скинов (v2)
---------------------------------------------------------------------------
Открывается консольной командой `zcity_skins_menu` (вызывается из ESC).
Структура:
  Слева  — список оружий
  Центр  — превью DModelPanel + плавный переход при смене скина
  Справа — карточки скинов (с плавным выделением)
  Снизу  — кнопка "Применить" / "Снять" / "Только для VIP"

Изменения относительно v1:
  * Защита PerformLayout от вызова до создания дочерних панелей.
  * Все панели создаются ДО любого SetSize/MakePopup, никаких nil-ошибок.
  * Стандартный скин («Без скина») всегда показывается для каждого оружия.
  * Hover/select анимации с Lerp.
  * Аккуратная сетка-фон, рамки скруглены, цвета насыщеннее.
  * Smooth re-layout превью при смене скина (опасный «мерцающий» Clear()
    заменён на DModelPanel:SetModel + переустановку SubMaterial без пересоздания).
---------------------------------------------------------------------------]]
if not CLIENT then return end

-- sh_config.lua уже включён через sh_zcity_skins_loader.lua

local PANEL_REF

-- ─── Live-редактор пресетов камеры (concommand'ы) ───────────────────────────
-- Регистрируются один раз при загрузке клиента, доступны всегда — не зависят
-- от того, открыто меню или нет (если меню закрыто — выводят ошибку).
--
-- Команды:
--   zcity_skins_show                          — показать текущие значения
--   zcity_skins_set <key> <val>               — установить (cx/cy/cz/radius/yaw)
--   zcity_skins_adj <key> <delta>             — изменить на дельту
--   zcity_skins_edit <cx> <cy> <cz> <r> <yaw> — установить всё разом
--   zcity_skins_reset                         — удалить пресет (авто-AABB)
--   zcity_skins_save                          — сохранить пресет ТЕКУЩЕЙ модели
--                                              в data/zcity_skins/camera_preset.lua
--                                              + скопировать строку в буфер
--   zcity_skins_save_all                      — сохранить ВСЕ пресеты
do
    ZCITY_SKINS = ZCITY_SKINS or {}
    ZCITY_SKINS.CameraPresets = ZCITY_SKINS.CameraPresets or {}

    local function getActive()
        if not IsValid(PANEL_REF) or not IsValid(PANEL_REF.PreviewModel) then
            return nil
        end
        return PANEL_REF.PreviewModel
    end

    local function getCurrent()
        local p = getActive(); if not p then return nil end
        local path = p:GetModel() or ""
        local c    = p._OrbitCenter or Vector(0, 0, 0)
        return {
            path   = path,
            cx     = c.x, cy = c.y, cz = c.z,
            radius = p._OrbitRadius or 50,
            yaw    = p._StaticYaw   or 145,
        }
    end

    local function applyToPanel(p, cur)
        p._OrbitCenter = Vector(cur.cx, cur.cy, cur.cz)
        p._OrbitRadius = cur.radius
        p._StaticYaw   = cur.yaw
        ZCITY_SKINS.CameraPresets[cur.path] = {
            center = Vector(cur.cx, cur.cy, cur.cz),
            radius = cur.radius,
            yaw    = cur.yaw,
        }
    end

    local KEY_MAP = { cx=true, cy=true, cz=true, radius=true, yaw=true }

    local function chatErr(msg)  chat.AddText(Color(220,80,80),  "[skins] ", color_white, msg) end
    local function chatOk(msg)   chat.AddText(Color(120,220,120),"[skins] ", color_white, msg) end
    local function chatInfo(msg) chat.AddText(Color(255,200,80), "[skins] ", color_white, msg) end

    local function presetLuaLine(path, cur)
        return string.format(
            '    [%q] = { center = Vector(%g, %g, %g), radius = %g, yaw = %g },',
            path, cur.cx, cur.cy, cur.cz, cur.radius, cur.yaw)
    end

    concommand.Add("zcity_skins_show", function()
        local cur = getCurrent()
        if not cur then chatErr("Меню скинов не открыто.") return end
        chatInfo(string.format("model: %s", cur.path))
        chatInfo(string.format("  center = (%g, %g, %g)", cur.cx, cur.cy, cur.cz))
        chatInfo(string.format("  radius = %g  yaw = %g", cur.radius, cur.yaw))
    end, nil, "Показать текущий пресет камеры активной модели")

    concommand.Add("zcity_skins_set", function(_, _, args)
        local p   = getActive(); if not p then chatErr("Меню не открыто.") return end
        local key = string.lower(args[1] or "")
        local val = tonumber(args[2])
        if not KEY_MAP[key] or not val then
            chatErr("Использование: zcity_skins_set <cx|cy|cz|radius|yaw> <число>")
            return
        end
        local cur = getCurrent(); cur[key] = val
        applyToPanel(p, cur)
        chatOk(string.format("%s = %g", key, val))
    end, nil, "Установить параметр пресета")

    concommand.Add("zcity_skins_adj", function(_, _, args)
        local p   = getActive(); if not p then chatErr("Меню не открыто.") return end
        local key = string.lower(args[1] or "")
        local d   = tonumber(args[2])
        if not KEY_MAP[key] or not d then
            chatErr("Использование: zcity_skins_adj <cx|cy|cz|radius|yaw> <дельта>")
            return
        end
        local cur = getCurrent(); cur[key] = cur[key] + d
        applyToPanel(p, cur)
        chatOk(string.format("%s: %+g → %g", key, d, cur[key]))
    end, nil, "Изменить параметр на дельту")

    concommand.Add("zcity_skins_edit", function(_, _, args)
        local p = getActive(); if not p then chatErr("Меню не открыто.") return end
        if #args < 5 then
            chatErr("Использование: zcity_skins_edit <cx> <cy> <cz> <radius> <yaw>")
            return
        end
        local cur = getCurrent()
        cur.cx     = tonumber(args[1]) or 0
        cur.cy     = tonumber(args[2]) or 0
        cur.cz     = tonumber(args[3]) or 0
        cur.radius = tonumber(args[4]) or cur.radius
        cur.yaw    = tonumber(args[5]) or cur.yaw
        applyToPanel(p, cur)
        chatOk(string.format("center=(%g, %g, %g) r=%g yaw=%g",
            cur.cx, cur.cy, cur.cz, cur.radius, cur.yaw))
    end, nil, "Установить все параметры за раз")

    concommand.Add("zcity_skins_reset", function()
        local p = getActive(); if not p then chatErr("Меню не открыто.") return end
        local path = p:GetModel() or ""
        ZCITY_SKINS.CameraPresets[path] = nil
        p:SetModel(path)
        chatOk("Пресет удалён, авто-AABB восстановлен (закрой/открой меню если не пересчиталось)")
    end, nil, "Удалить пресет активной модели")

    local function saveToDataFile(name, payload)
        file.CreateDir("zcity_skins")
        file.Write("zcity_skins/" .. name, payload)
    end

    concommand.Add("zcity_skins_save", function()
        local cur = getCurrent()
        if not cur then chatErr("Меню не открыто.") return end
        local line = presetLuaLine(cur.path, cur)
        local body = "-- ZCity skins: пресет камеры (одна модель)\n" ..
                     "-- Скопируй строку ниже в ZCITY_SKINS.CameraPresets в sh_config.lua\n" ..
                     line .. "\n"
        saveToDataFile("camera_preset.lua", body)
        SetClipboardText(line)
        chatOk("Сохранено: garrysmod/data/zcity_skins/camera_preset.lua")
        chatInfo("Lua-строка скопирована в буфер обмена — Ctrl+V в sh_config.lua")
        print("[skins] " .. line)
    end, nil, "Сохранить пресет активной модели в data + буфер")

    concommand.Add("zcity_skins_save_all", function()
        local presets = ZCITY_SKINS.CameraPresets or {}
        local lines = {}
        for path, pr in pairs(presets) do
            local c = pr.center or Vector(0, 0, 0)
            lines[#lines + 1] = string.format(
                '    [%q] = { center = Vector(%g, %g, %g), radius = %g, yaw = %g },',
                path, c.x, c.y, c.z, pr.radius or 50, pr.yaw or 145)
        end
        table.sort(lines)
        local body = "-- ZCity skins: все пресеты камеры\n" ..
                     "-- Замени блок ZCITY_SKINS.CameraPresets в sh_config.lua на:\n" ..
                     "ZCITY_SKINS.CameraPresets = {\n" ..
                     table.concat(lines, "\n") .. "\n}\n"
        saveToDataFile("camera_presets.lua", body)
        SetClipboardText(body)
        chatOk(string.format("Сохранено %d пресетов: data/zcity_skins/camera_presets.lua", #lines))
        chatInfo("Полный блок скопирован в буфер обмена")
    end, nil, "Сохранить ВСЕ пресеты в data + буфер")

    concommand.Add("zcity_skins_cam_dump", function() RunConsoleCommand("zcity_skins_show") end)
end
-- Игровая палитра — глубокий blue/black базис с тёплыми акцентами
local clrBg      = Color(10, 12, 18, 250)
local clrBgGrad  = Color(28, 18, 36, 250)
local clrPanel   = Color(22, 25, 33, 245)
local clrPanel2  = Color(32, 36, 46, 240)
local clrCard    = Color(28, 31, 40)
local clrCardHov = Color(46, 52, 66)
local clrAccent  = Color(235, 70, 88)         -- основной красный
local clrAccent2 = Color(255, 175, 70)        -- золотой/огненный
local clrAccent3 = Color(110, 200, 255)       -- холодный голубой для контраста
local clrText    = Color(238, 240, 245)
local clrSub     = Color(150, 156, 172)
local clrVip     = Color(255, 215, 90)
local clrLine    = Color(255, 255, 255, 10)
local clrDivider = Color(255, 255, 255, 22)
local clrShadow  = Color(0, 0, 0, 120)

local rarityColor = {
    common    = Color(130, 190, 230),
    rare      = Color(190, 130, 245),
    legendary = Color(255, 175, 70),
}
local rarityGlow = {
    common    = Color(80, 140, 200, 80),
    rare      = Color(150, 90, 220, 110),
    legendary = Color(255, 150, 50, 130),
}
local rarityName = {
    common    = "обычный",
    rare      = "редкий",
    legendary = "легендарный",
}

surface.CreateFont("ZCSkins_Brand",  { font = "Bahnschrift", size = 38, weight = 900, antialias = true })
surface.CreateFont("ZCSkins_Title",  { font = "Bahnschrift", size = 30, weight = 800, antialias = true })
surface.CreateFont("ZCSkins_H1",     { font = "Bahnschrift", size = 22, weight = 700, antialias = true })
surface.CreateFont("ZCSkins_H2",     { font = "Bahnschrift", size = 19, weight = 700, antialias = true })
surface.CreateFont("ZCSkins_Body",   { font = "Bahnschrift", size = 17, weight = 600, antialias = true })
surface.CreateFont("ZCSkins_BodyB",  { font = "Bahnschrift", size = 18, weight = 800, antialias = true })
surface.CreateFont("ZCSkins_BtnBig", { font = "Bahnschrift", size = 22, weight = 900, antialias = true })
surface.CreateFont("ZCSkins_Small",  { font = "Bahnschrift", size = 13, weight = 500, antialias = true })
surface.CreateFont("ZCSkins_Tiny",   { font = "Bahnschrift", size = 11, weight = 700, antialias = true })

local function LerpColor(t, a, b)
    return Color(
        math.Round(Lerp(t, a.r, b.r)),
        math.Round(Lerp(t, a.g, b.g)),
        math.Round(Lerp(t, a.b, b.b)),
        math.Round(Lerp(t, a.a or 255, b.a or 255))
    )
end

local function applySkin(weaponClass, skinId)
    net.Start("zcity_skins_apply")
    net.WriteString(weaponClass)
    net.WriteString(skinId)
    net.SendToServer()
end

local function findSkin(id)
    for _, s in ipairs(ZCITY_SKINS.List) do
        if s.id == id then return s end
    end
end

local MAX_SUBMATERIALS = 31 -- Source поддерживает до 32 sub-материалов

local function applySkinToEnt(ent, skin)
    if not IsValid(ent) then return end
    -- Снимаем старые subs (модели бывают с большим числом материалов)
    for i = 0, MAX_SUBMATERIALS do ent:SetSubMaterial(i) end
    if not skin or not skin.material or skin.isClear then return end
    -- Если submat не задан — применяем скин ко ВСЕМ sub-материалам модели.
    -- ArcCW c_ud_m16 имеет материалы вплоть до slot 24 (приклад) — раньше тут
    -- было 0..15 и приклад/прицел оставались в дефолте.
    if not skin.submat then
        for i = 0, MAX_SUBMATERIALS do ent:SetSubMaterial(i, skin.material) end
        return
    end
    if isnumber(skin.submat) then ent:SetSubMaterial(skin.submat, skin.material) return end
    for _, idx in ipairs(skin.submat) do ent:SetSubMaterial(idx, skin.material) end
end

local PANEL = {}

function PANEL:Init()
    -- 1) Сначала помечаем что layout пока выполнять нельзя
    self._ready = false

    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetDraggable(false)

    -- 2) Создаём ВСЕ дочерние панели заранее
    self.LeftPanel    = vgui.Create("DPanel", self)
    self.PreviewPanel = vgui.Create("DPanel", self)
    self.RightPanel   = vgui.Create("DPanel", self)

    self.LeftPanel.Paint  = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, clrPanel)
        surface.SetDrawColor(clrDivider)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    self.RightPanel.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, clrPanel)
        surface.SetDrawColor(clrDivider)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    -- Preview-панель красится в стиле «сцены»: тёмный фон + rarity-glow по краям
    self.PreviewPanel.Paint = function(s, w, h)
        draw.RoundedBox(10, 0, 0, w, h, clrPanel)

        -- Подбираем rarity активного скина для свечения
        local skinObj = findSkin(self.SelectedSkin)
        local rkey = (skinObj and skinObj.rarity) or "common"
        local glow = rarityGlow[rkey] or rarityGlow.common
        -- Радиальное свечение из центра-снизу (имитация подсветки «сцены»)
        local cx, cy = w / 2, h * 0.78
        for i = 1, 8 do
            local rad = 80 + i * 22
            local a   = math.floor(glow.a * (1 - i / 9))
            if a > 1 then
                draw.RoundedBox(rad, cx - rad, cy - rad, rad * 2, rad * 2,
                    Color(glow.r, glow.g, glow.b, a))
            end
        end
        -- «Сцена» — тёмный пол снизу
        draw.RoundedBoxEx(10, 0, h - 90, w, 90, Color(0, 0, 0, 90), false, false, true, true)
        -- Верхний градиент-затемнитель (легче видеть оружие)
        surface.SetDrawColor(0, 0, 0, 50)
        surface.DrawRect(0, 0, w, 24)
        -- Обводка
        surface.SetDrawColor(clrDivider)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        -- Тонкая полоса rarity сверху
        local rcol = rarityColor[rkey] or rarityColor.common
        draw.RoundedBoxEx(10, 0, 0, w, 2, rcol, true, true, false, false)
    end

    -- закрытие
    local closeBtn = vgui.Create("DButton", self)
    closeBtn:SetText("")
    closeBtn:SetSize(40, 40)
    closeBtn.PerformLayout = function(s) s:SetPos(self:GetWide() - 52, 20) end
    closeBtn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        s.HoverLerp = Lerp(FrameTime() * 12, s.HoverLerp or 0, hov and 1 or 0)
        local col = LerpColor(s.HoverLerp, Color(40, 44, 56, 230), Color(230, 70, 88, 240))
        draw.RoundedBox(8, 0, 0, w, h, col)
        -- Внутренняя обводка
        surface.SetDrawColor(255, 255, 255, 30 + s.HoverLerp * 40)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("✕", "ZCSkins_H1", w / 2, h / 2 - 1, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() self:Close() end
    self.CloseBtn = closeBtn

    -- 3) Текущий выбор
    self.SelectedWeapon = ZCITY_SKINS.WeaponTabs[1].class
    self.SelectedSkin   = "default"

    -- 4) Размер ПОСЛЕ создания панелей
    local W, H = math.min(ScrW() * 0.8, 1280), math.min(ScrH() * 0.82, 800)
    self:SetSize(W, H)
    self:Center()
    self:MakePopup()

    -- 5) Заполняем содержимое
    self._ready = true
    self:BuildLeft()
    self:BuildRight()
    self:BuildPreview()

    -- Открывающая анимация
    self:SetAlpha(0)
    self:AlphaTo(255, 0.2, 0)
end

function PANEL:Close()
    self:AlphaTo(0, 0.18, 0, function() self:Remove() end)
end

function PANEL:OnKeyCodePressed(k)
    if k == KEY_ESCAPE then self:Close() end
end

function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.startTime or SysTime())
    self.startTime = self.startTime or SysTime()

    -- База фона
    draw.RoundedBox(12, 0, 0, w, h, clrBg)

    -- Диагональный градиент: красный угол сверху-слева → фиолетовый снизу-справа
    surface.SetDrawColor(clrBgGrad.r, clrBgGrad.g, clrBgGrad.b, 110)
    surface.DrawRect(0, 0, w, h)
    -- Радиальная "виньетка"-засветка из верхнего-левого угла (имитация прожектора)
    for i = 0, 6 do
        local a = 22 - i * 3
        if a > 0 then
            draw.RoundedBox(12, -40 + i * 8, -40 + i * 8, math.floor(w * 0.55) - i * 16, math.floor(h * 0.55) - i * 16,
                Color(clrAccent.r, clrAccent.g, clrAccent.b, a))
        end
    end

    -- Сетка из тонких горизонтальных линий (декор)
    surface.SetDrawColor(clrLine)
    for i = 70, h - 8, 38 do surface.DrawLine(20, i, w - 20, i) end

    -- Верхний акцентный «бар» из двух полосок
    surface.SetDrawColor(clrAccent)
    surface.DrawRect(0, 0, w, 3)
    surface.SetDrawColor(clrAccent2.r, clrAccent2.g, clrAccent2.b, 180)
    surface.DrawRect(0, 3, math.floor(w * 0.35), 1)

    -- Шапка: блок с тёмной подложкой
    local headerH = 64
    draw.RoundedBoxEx(10, 14, 8, w - 28, headerH, Color(0, 0, 0, 60), true, true, false, false)

    -- Брендовый заголовок (с тенью)
    draw.SimpleText("СКИНЫ ОРУЖИЯ", "ZCSkins_Brand", 31, 35, clrShadow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("СКИНЫ ОРУЖИЯ", "ZCSkins_Brand", 28, 32, clrText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Декоративная диагональная "плашка" возле заголовка
    surface.SetDrawColor(clrAccent)
    surface.DrawRect(28, 56, 36, 2)
    surface.SetDrawColor(clrAccent2.r, clrAccent2.g, clrAccent2.b, 200)
    surface.DrawRect(68, 56, 12, 2)

    -- Подзаголовок: справа от бренда
    local isVip = ZCITY_SKINS.IsVip(LocalPlayer())
    local sub = isVip
        and "VIP-доступ открыт — применяй любой скин"
        or  "Просмотр для всех. Применять кастом-скины — VIP."
    surface.SetFont("ZCSkins_Body")
    local _, _ = surface.GetTextSize("СКИНЫ ОРУЖИЯ")

    -- Бэйдж VIP/STATUS справа от заголовка
    local badgeW, badgeH = 110, 26
    local badgeX = 280
    local badgeY = 24
    local badgeCol = isVip and clrVip or Color(80, 86, 100)
    draw.RoundedBox(4, badgeX, badgeY, badgeW, badgeH, Color(badgeCol.r, badgeCol.g, badgeCol.b, 40))
    draw.RoundedBox(4, badgeX, badgeY, 3, badgeH, badgeCol)
    draw.SimpleText(isVip and "VIP АКТИВЕН" or "ОБЫЧНЫЙ", "ZCSkins_Tiny",
        badgeX + 14, badgeY + badgeH / 2, badgeCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    draw.SimpleText(sub, "ZCSkins_Small", 28, 56, clrSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function PANEL:PerformLayout(w, h)
    if not self._ready then return end
    if not IsValid(self.LeftPanel) or not IsValid(self.PreviewPanel) or not IsValid(self.RightPanel) then return end

    local pad = 16
    local top = 86
    local leftW  = 240
    local rightW = 340

    self.LeftPanel:SetPos(pad, top)
    self.LeftPanel:SetSize(leftW, h - top - pad)

    self.PreviewPanel:SetPos(pad + leftW + pad, top)
    self.PreviewPanel:SetSize(w - leftW - rightW - pad * 4, h - top - pad)

    self.RightPanel:SetPos(w - rightW - pad, top)
    self.RightPanel:SetSize(rightW, h - top - pad)

    if IsValid(self.CloseBtn) then self.CloseBtn:SetPos(w - 52, 20) end
end

-- ─── Левая панель: вкладки оружия ────────────────────────────────────────────
function PANEL:BuildLeft()
    self.LeftPanel:Clear()

    local title = vgui.Create("DLabel", self.LeftPanel)
    title:SetText("АРСЕНАЛ")
    title:SetFont("ZCSkins_H1")
    title:SetTextColor(clrText)
    title:Dock(TOP); title:DockMargin(16, 16, 14, 4); title:SetTall(28)

    local subTitle = vgui.Create("DLabel", self.LeftPanel)
    subTitle:SetText("выбери оружие")
    subTitle:SetFont("ZCSkins_Small")
    subTitle:SetTextColor(clrSub)
    subTitle:Dock(TOP); subTitle:DockMargin(16, 0, 14, 6); subTitle:SetTall(16)

    local divider = vgui.Create("DPanel", self.LeftPanel)
    divider:Dock(TOP); divider:DockMargin(14, 0, 14, 10); divider:SetTall(2)
    divider.Paint = function(_, w, h)
        surface.SetDrawColor(clrAccent)
        surface.DrawRect(0, 0, math.floor(w * 0.45), h)
        surface.SetDrawColor(clrAccent2.r, clrAccent2.g, clrAccent2.b, 180)
        surface.DrawRect(math.floor(w * 0.45), 0, math.floor(w * 0.12), h)
        surface.SetDrawColor(clrDivider)
        surface.DrawRect(math.floor(w * 0.57), 0, w - math.floor(w * 0.57), h)
    end

    for _, tab in ipairs(ZCITY_SKINS.WeaponTabs) do
        local b = vgui.Create("DButton", self.LeftPanel)
        b:Dock(TOP); b:DockMargin(10, 5, 10, 0); b:SetTall(48); b:SetText(""); b.Class = tab.class

        b.HoverLerp = 0
        b.SelLerp   = 0
        b.Paint = function(s, w, h)
            local sel = self.SelectedWeapon == tab.class
            local hov = s:IsHovered()
            s.HoverLerp = Lerp(FrameTime() * 12, s.HoverLerp, hov and 1 or 0)
            s.SelLerp   = Lerp(FrameTime() * 10, s.SelLerp,   sel and 1 or 0)

            -- Тень снизу (только когда выделено/наведено)
            local shA = math.floor(math.max(s.HoverLerp, s.SelLerp) * 80)
            if shA > 0 then
                draw.RoundedBox(8, 0, h - 2, w, 6, Color(0, 0, 0, shA))
            end

            local base = LerpColor(s.HoverLerp, clrCard, clrCardHov)
            local accentMix = LerpColor(s.SelLerp, base, Color(80, 30, 38))
            draw.RoundedBox(8, 0, 0, w, h, accentMix)

            -- Левый акцент (растёт при hover/select)
            local barW = 3 + math.max(s.HoverLerp, s.SelLerp) * 5
            draw.RoundedBoxEx(8, 0, 0, barW, h,
                sel and clrAccent or (hov and clrAccent2 or Color(255, 255, 255, 50)),
                true, false, true, false)

            -- Лёгкий градиент при выделении
            if s.SelLerp > 0 then
                surface.SetDrawColor(clrAccent.r, clrAccent.g, clrAccent.b, math.floor(s.SelLerp * 28))
                surface.DrawRect(barW, 0, w - barW, h)
            end

            draw.SimpleText(tab.title, "ZCSkins_Body", 18 + barW, h / 2 - 7,
                LerpColor(s.SelLerp, clrText, color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            local cnt = #self:GetSkinsFor(tab.class)
            local cntText = cnt .. (cnt == 1 and " скин" or " скинов")
            draw.SimpleText(cntText, "ZCSkins_Small", 18 + barW, h / 2 + 10,
                sel and Color(255, 200, 120) or clrSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- "Индикатор" количества скинов справа
            local dotR = 4
            local dotX = w - 18
            local dotY = h / 2
            local dotColor = cnt > 1 and clrAccent2 or Color(120, 130, 145)
            draw.NoTexture()
            surface.SetDrawColor(dotColor)
            surface.DrawRect(dotX - dotR, dotY - dotR, dotR * 2, dotR * 2)
            if sel then
                surface.SetDrawColor(255, 255, 255, 180)
                surface.DrawOutlinedRect(dotX - dotR - 2, dotY - dotR - 2, dotR * 2 + 4, dotR * 2 + 4, 1)
            end
        end
        b.DoClick = function()
            if self.SelectedWeapon == tab.class then return end
            self.SelectedWeapon = tab.class
            self.SelectedSkin   = "default"
            self:RefreshAfterChange()
            surface.PlaySound("ui/buttonclick.wav")
        end
    end
end

-- Список скинов для оружия с принудительным "Стандартный" во главе
function PANEL:GetSkinsFor(class)
    local list = ZCITY_SKINS.SkinsForWeapon(class) or {}
    -- Гарантируем что в списке есть default (isClear)
    local hasDefault = false
    for _, s in ipairs(list) do if s.isClear or s.id == "default" then hasDefault = true break end end
    if not hasDefault then
        local defSkin = findSkin("default")
        if defSkin then table.insert(list, 1, defSkin) end
    else
        -- Поднимаем default наверх
        for i, s in ipairs(list) do
            if s.id == "default" then
                table.remove(list, i)
                table.insert(list, 1, s)
                break
            end
        end
    end
    return list
end

-- ─── Превью ──────────────────────────────────────────────────────────────────
function PANEL:BuildPreview()
    self.PreviewPanel:Clear()

    local skin = findSkin(self.SelectedSkin)
    -- Подбираем модель: либо из скина, либо из weaponTab
    local model = (skin and skin.model and not skin.isClear) and skin.model or nil
    if not model then
        for _, t in ipairs(ZCITY_SKINS.WeaponTabs) do
            if t.class == self.SelectedWeapon then model = t.model break end
        end
    end

    local mp = vgui.Create("DModelPanel", self.PreviewPanel)
    mp:Dock(FILL); mp:DockMargin(20, 28, 20, 12)
    mp:SetModel(model or "models/error.mdl")
    mp:SetFOV(35)

    -- ★ Заморозка анимации для viewmodel-ов (c_ud_*.mdl у ArcCW)
    -- Без этого у пистолетов/M16 проигрывается idle-анимация: кости двигаются,
    -- руки покачиваются, и визуально модель "крутится вокруг оси". У ножей
    -- (w_*.mdl, tactical_knife_*.mdl) анимаций нет — они и так стоят.
    --
    -- Фикс: SetAnimSpeed(0) + bAnimated=false отключают RunAnimation в базовом
    -- LayoutEntity, а явный SetCycle(0)+SetPlaybackRate(0)+SetIK(false) на
    -- сущности замораживает текущий sequence в нулевом кадре. Дополнительно
    -- то же самое делается каждый кадр в нашем кастомном LayoutEntity (см. ниже),
    -- чтобы перезатирания в Think/Paint engine'a не разморозили анимацию.
    mp:SetAnimSpeed(0)
    mp.bAnimated = false
    if IsValid(mp.Entity) then
        mp.Entity:SetSequence(0)
        mp.Entity:SetCycle(0)
        mp.Entity:SetPlaybackRate(0)
        mp.Entity:SetIK(false)
    end

    -- Подгонка камеры под модель.
    --
    -- Проблема: для viewmodel-ов ArcCW (c_*.mdl) ни один автоматический способ
    -- не работает «из коробки»:
    --   * BoundingRadius() меряет от origin модели (а origin у viewmodel где-то
    --     в области рук игрока, не на оружии) → радиус завышенный, камера
    --     отлетает.
    --   * OBBMins/OBBMaxs у viewmodel-ов часто вырождены (1×1×1).
    --   * util.GetModelMeshes даёт vertices в bind-pose, и AABB включает
    --     ВСЕ меши — в том числе руки игрока, которые сидят далеко от оружия.
    --     Из-за этого центр AABB смещён к рукам, а не к стволу.
    --
    -- Поэтому для известных viewmodel-ов берём ручные пресеты камеры,
    -- а для w_*-моделей (ножи, w_-варианты) считаем mesh-AABB автоматически.
    --
    -- Если нужно подстроить вид — поправь блок ZCITY_SKINS.CameraPresets
    -- в `lua/zcity_skins/sh_config.lua`, либо открой VGUI редактор командой
    -- `zcity_skins_editor` и сохрани оттуда.

    -- Берём пресеты из конфига; fallback — пустая таблица, тогда сработает
    -- авто-AABB. Раньше тут был инлайн-fallback с зашитыми значениями —
    -- удалён, так как перезатирал откалиброванные пресеты из конфига.
    local CAMERA_PRESETS = ZCITY_SKINS.CameraPresets or {}
    ZCITY_SKINS.CameraPresets = CAMERA_PRESETS

    local function computeMeshAABB(modelPath)
        local meshes = util.GetModelMeshes(modelPath)
        if not meshes or #meshes == 0 then return nil end
        local mins = Vector(math.huge, math.huge, math.huge)
        local maxs = Vector(-math.huge, -math.huge, -math.huge)
        local had = false
        for _, m in ipairs(meshes) do
            local tris = m.triangles
            if tris then
                for _, v in ipairs(tris) do
                    local p = v.pos
                    if p then
                        if p.x < mins.x then mins.x = p.x end
                        if p.y < mins.y then mins.y = p.y end
                        if p.z < mins.z then mins.z = p.z end
                        if p.x > maxs.x then maxs.x = p.x end
                        if p.y > maxs.y then maxs.y = p.y end
                        if p.z > maxs.z then maxs.z = p.z end
                        had = true
                    end
                end
            end
        end
        if not had then return nil end
        return mins, maxs
    end

    ZCITY_SKINS._aabbCache = ZCITY_SKINS._aabbCache or {}

    local function getModelAABB(modelPath)
        local c = ZCITY_SKINS._aabbCache[modelPath]
        if c then return c[1], c[2] end
        local mn, mx = computeMeshAABB(modelPath)
        if mn then ZCITY_SKINS._aabbCache[modelPath] = { mn, mx } end
        return mn, mx
    end

    local function reframe(panel)
        local ent = panel.Entity
        if not IsValid(ent) then return end
        local modelPath = ent:GetModel() or ""

        -- 1) Ручной пресет — самое надёжное для проблемных viewmodels
        local preset = CAMERA_PRESETS[modelPath]
        if preset then
            panel._OrbitRadius = preset.radius
            panel._OrbitCenter = preset.center
            panel._StaticYaw   = preset.yaw or 145
            return
        end

        -- Если пресета нет — yaw всегда дефолт 145 (3/4 вид)
        panel._StaticYaw = 145

        -- 2) Авто: mesh AABB (работает для w_*-моделей и компактных моделей)
        local mins, maxs = getModelAABB(modelPath)
        if not mins then
            -- 3) Фолбэк на OBB / BoundingRadius
            mins, maxs = ent:OBBMins(), ent:OBBMaxs()
            if (maxs - mins):Length() < 4 then
                local r = ent:BoundingRadius() or 25
                if r < 1 then r = 25 end
                panel._OrbitRadius = r * 2.2
                panel._OrbitCenter = ent:OBBCenter()
                return
            end
        end
        local diag = (maxs - mins):Length()
        if diag < 2 then diag = 50 end
        panel._OrbitRadius = diag * 1.75
        panel._OrbitCenter = (mins + maxs) / 2
    end
    reframe(mp)
    -- Иногда модель не успевает загрузить bbox в первый кадр — пересчёт через 0.05с
    timer.Simple(0.05, function() if IsValid(mp) then reframe(mp) end end)
    timer.Simple(0.3,  function() if IsValid(mp) then reframe(mp) end end)

    -- ─── Live-редактор пресетов камеры ──────────────────────────────────────
    -- Все команды работают на АКТИВНОЙ модели (которая сейчас открыта в превью).
    -- Изменения применяются мгновенно — `LayoutEntity` читает значения каждый
    -- кадр из `_OrbitCenter`/`_OrbitRadius`/`_StaticYaw`.
    --
    self._activeModelPath = mp:GetModel()

    -- Применяем скин к Entity
    if IsValid(mp.Entity) and skin and not skin.isClear then
        applySkinToEnt(mp.Entity, skin)
    end

    -- ВРАЩЕНИЕ: ОТКЛЮЧЕНО.
    -- Модель стоит абсолютно неподвижно в красивой 3/4-позе. Без ЛКМ-драга,
    -- без авто-оборотов, без idle-анимаций. Камера и модель — обе статика.
    --
    -- Per-model настройка через `ZCITY_SKINS.CameraPresets[<modelPath>]`:
    --   { center = Vector(x,y,z), radius = N, yaw = N }
    -- Редактируется live-командами `zcity_skins_*` (см. ниже).
    function mp:LayoutEntity(ent)
        -- ★ Каждый кадр гасим анимационный цикл — иначе движок продвигает
        -- idle-sequence у viewmodel-ов и модель «плавает» из-за костей.
        ent:SetCycle(0)
        ent:SetPlaybackRate(0)

        local center = self._OrbitCenter or vector_origin
        local radius = self._OrbitRadius or 50
        local yaw    = self._StaticYaw   or 145

        local ang     = Angle(0, yaw, 0)
        local rotated = Vector(center.x, center.y, center.z)
        rotated:Rotate(ang)

        ent:SetAngles(ang)
        ent:SetPos(-rotated)

        self:SetCamPos(Vector(radius, 0, radius * 0.08))
        self:SetLookAt(vector_origin)
    end
    -- Никакой реакции на мышь — модель полностью статична.
    function mp:OnMousePressed() end
    function mp:OnMouseReleased() end

    self.PreviewModel = mp

    -- Низ — детали (бокс с rarity-полосой + бейдж редкости)
    local bottom = vgui.Create("DPanel", self.PreviewPanel)
    bottom._isInfoBar = true
    bottom:Dock(BOTTOM); bottom:SetTall(72); bottom:DockMargin(20, 0, 20, 18)
    bottom.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, clrPanel2)
        if skin and not skin.isClear then
            local rcol = rarityColor[skin.rarity or "common"]
            draw.RoundedBoxEx(8, 0, 0, 5, h, rcol, true, false, true, false)
            -- Бейдж редкости в правом углу
            local rname = (rarityName[skin.rarity or "common"] or "обычный"):upper()
            surface.SetFont("ZCSkins_Tiny")
            local tw, th = surface.GetTextSize(rname)
            local bw, bh = tw + 18, th + 8
            local bx, by = w - bw - 12, 12
            draw.RoundedBox(4, bx, by, bw, bh, Color(rcol.r, rcol.g, rcol.b, 50))
            draw.RoundedBox(4, bx, by, 3, bh, rcol)
            draw.SimpleText(rname, "ZCSkins_Tiny", bx + 10, by + bh / 2, rcol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local titleLbl = vgui.Create("DLabel", bottom)
    titleLbl:SetText(skin and skin.name or "СКИН НЕ ВЫБРАН")
    titleLbl:SetFont("ZCSkins_H1"); titleLbl:SetTextColor(clrText)
    titleLbl:Dock(TOP); titleLbl:DockMargin(16, 10, 16, 0); titleLbl:SetTall(24)

    local desc = vgui.Create("DLabel", bottom)
    desc:SetText(skin and skin.desc or "Выберите скин в правой колонке.")
    desc:SetFont("ZCSkins_Small"); desc:SetTextColor(clrSub)
    desc:SetWrap(true); desc:SetAutoStretchVertical(true)
    desc:Dock(FILL); desc:DockMargin(16, 4, 16, 8)
end

-- ─── Правая панель: карточки скинов ──────────────────────────────────────────
function PANEL:BuildRight()
    self.RightPanel:Clear()

    local title = vgui.Create("DLabel", self.RightPanel)
    title:SetText("КОЛЛЕКЦИЯ")
    title:SetFont("ZCSkins_H1"); title:SetTextColor(clrText)
    title:Dock(TOP); title:DockMargin(16, 16, 14, 4); title:SetTall(28)

    local subTitle = vgui.Create("DLabel", self.RightPanel)
    subTitle:SetText("выбери скин для применения")
    subTitle:SetFont("ZCSkins_Small")
    subTitle:SetTextColor(clrSub)
    subTitle:Dock(TOP); subTitle:DockMargin(16, 0, 14, 6); subTitle:SetTall(16)

    local divider = vgui.Create("DPanel", self.RightPanel)
    divider:Dock(TOP); divider:DockMargin(14, 0, 14, 8); divider:SetTall(2)
    divider.Paint = function(_, w, h)
        surface.SetDrawColor(clrAccent)
        surface.DrawRect(0, 0, math.floor(w * 0.35), h)
        surface.SetDrawColor(clrAccent2.r, clrAccent2.g, clrAccent2.b, 180)
        surface.DrawRect(math.floor(w * 0.35), 0, math.floor(w * 0.12), h)
        surface.SetDrawColor(clrDivider)
        surface.DrawRect(math.floor(w * 0.47), 0, w - math.floor(w * 0.47), h)
    end

    -- Кнопка применить (создаём ДО списка, чтобы Dock(BOTTOM) корректно отвёлся)
    local applyBtn = vgui.Create("DButton", self.RightPanel)
    applyBtn:Dock(BOTTOM); applyBtn:DockMargin(14, 8, 14, 14); applyBtn:SetTall(62); applyBtn:SetText("")
    applyBtn.HoverLerp = 0
    applyBtn.PulseT    = 0
    applyBtn.Paint = function(s, w, h)
        local skinObj = findSkin(self.SelectedSkin)
        local isVip   = ZCITY_SKINS.IsVip(LocalPlayer())
        local clear   = (skinObj and skinObj.isClear) or self.SelectedSkin == "default"
        local can     = isVip or clear
        local hov     = s:IsHovered()
        s.HoverLerp = Lerp(FrameTime() * 12, s.HoverLerp, hov and 1 or 0)
        s.PulseT    = (s.PulseT + FrameTime()) % (math.pi * 2)

        -- Тень
        draw.RoundedBox(10, 2, h - 4, w - 4, 8, Color(0, 0, 0, 90))

        local base, hovCol
        if not can then
            base   = Color(60, 62, 72, 230)
            hovCol = Color(90, 92, 102, 240)
        else
            base   = clrAccent
            hovCol = clrAccent2
        end
        local col = LerpColor(s.HoverLerp, base, hovCol)
        draw.RoundedBox(10, 0, 0, w, h, col)

        -- Внутренний градиент (диагональный «глянец» сверху)
        surface.SetDrawColor(255, 255, 255, 28)
        surface.DrawRect(0, 0, w, math.floor(h * 0.45))

        -- Пульсация для активной кнопки (мягкая «дышащая» обводка)
        if can then
            local pulse = (math.sin(s.PulseT * 2) + 1) * 0.5
            surface.SetDrawColor(255, 255, 255, 50 + math.floor(pulse * 60))
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        else
            surface.SetDrawColor(255, 255, 255, 20)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local label, sub
        if clear then
            label, sub = "СНЯТЬ СКИН", "вернуть стандарт"
        elseif can then
            label, sub = "ПРИМЕНИТЬ", "выдать оружию текущий скин"
        else
            label, sub = "ТОЛЬКО ДЛЯ VIP", "напиши /donate чтобы купить"
        end
        if sub and sub ~= "" then
            draw.SimpleText(label, "ZCSkins_BtnBig", w / 2, h / 2 - 8, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(sub, "ZCSkins_Small", w / 2, h / 2 + 14,
                can and Color(255, 255, 255, 200) or clrVip, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText(label, "ZCSkins_BtnBig", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    applyBtn.DoClick = function()
        local skinObj = findSkin(self.SelectedSkin)
        local clear   = (skinObj and skinObj.isClear) or self.SelectedSkin == "default"
        if not clear and not ZCITY_SKINS.IsVip(LocalPlayer()) then
            chat.AddText(clrAccent, "[Скины] ", clrText, "Только для VIP. Купить можно командой /donate")
            surface.PlaySound("buttons/button10.wav")
            return
        end
        applySkin(self.SelectedWeapon, self.SelectedSkin)
        chat.AddText(clrAccent2, "[Скины] ", clrText, "Применено: ", clrAccent2, (skinObj and skinObj.name) or self.SelectedSkin)
        surface.PlaySound("buttons/button14.wav")
    end

    local list = vgui.Create("DScrollPanel", self.RightPanel)
    list:Dock(FILL); list:DockMargin(8, 0, 8, 0)

    -- Кастомизируем скроллбар
    local sb = list:GetVBar()
    sb:SetWide(4)
    function sb:Paint(w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255,255,255,12)) end
    function sb.btnGrip:Paint(w, h) draw.RoundedBox(2, 0, 0, w, h, clrAccent) end
    function sb.btnUp:Paint() end
    function sb.btnDown:Paint() end

    local skins = self:GetSkinsFor(self.SelectedWeapon)
    for _, s in ipairs(skins) do
        local card = vgui.Create("DButton", list)
        card:Dock(TOP); card:DockMargin(8, 8, 8, 0); card:SetTall(92); card:SetText("")
        card.HoverLerp = 0
        card.SelLerp   = 0

        card.Paint = function(self2, w, h)
            local sel = (self.SelectedSkin == s.id)
            local hov = self2:IsHovered()
            self2.HoverLerp = Lerp(FrameTime() * 12, self2.HoverLerp, hov and 1 or 0)
            self2.SelLerp   = Lerp(FrameTime() * 10, self2.SelLerp,   sel and 1 or 0)

            local rcol = rarityColor[s.rarity or "common"] or rarityColor.common

            -- Тень при наведении/выделении
            local shA = math.floor(math.max(self2.HoverLerp, self2.SelLerp) * 90)
            if shA > 0 then
                draw.RoundedBox(10, 2, h - 4, w - 4, 10, Color(0, 0, 0, shA))
            end

            -- Базовый фон
            local base = LerpColor(self2.HoverLerp, clrCard, clrCardHov)
            -- При выделении подмешиваем rarity-цвет, а не красный — выглядит «коллекционно»
            local selectionCol = Color(
                math.Round(rcol.r * 0.5),
                math.Round(rcol.g * 0.5),
                math.Round(rcol.b * 0.5)
            )
            local col = LerpColor(self2.SelLerp, base, selectionCol)
            draw.RoundedBox(10, 0, 0, w, h, col)

            -- Rarity-градиент по правому краю карточки (мягкая засветка)
            if not s.isClear then
                local gradA = 40 + math.floor(self2.HoverLerp * 30 + self2.SelLerp * 50)
                surface.SetDrawColor(rcol.r, rcol.g, rcol.b, gradA)
                surface.DrawRect(math.floor(w * 0.6), 0, math.ceil(w * 0.4), h)
            end

            -- Левая полоса rarity (растёт при hover/select)
            local barW = 4 + math.max(self2.HoverLerp, self2.SelLerp) * 4
            draw.RoundedBoxEx(10, 0, 0, barW, h,
                sel and clrAccent2 or rcol, true, false, true, false)

            -- Имя
            local nameClr = LerpColor(self2.SelLerp, clrText, color_white)
            draw.SimpleText(s.name or "?", "ZCSkins_BodyB", 18, 16, nameClr, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- Бейдж редкости / стандарт
            if not s.isClear then
                local rname = (rarityName[s.rarity or "common"] or "обычный"):upper()
                surface.SetFont("ZCSkins_Tiny")
                local tw, th = surface.GetTextSize(rname)
                local bw, bh = tw + 16, th + 6
                local bx, by = w - bw - 14, 16
                draw.RoundedBox(4, bx, by, bw, bh, Color(rcol.r, rcol.g, rcol.b, 70))
                draw.RoundedBox(4, bx, by, 2, bh, rcol)
                draw.SimpleText(rname, "ZCSkins_Tiny", bx + 9, by + bh / 2, rcol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText("СТАНДАРТ", "ZCSkins_Tiny", w - 16, 18, clrSub, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end

            -- Описание (две строки максимум, мягкий цвет)
            local desc = s.desc or ""
            if #desc > 76 then desc = desc:sub(1, 76) .. "…" end
            draw.SimpleText(desc, "ZCSkins_Small", 18, 46,
                LerpColor(self2.SelLerp, clrSub, Color(225, 228, 235)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- VIP-замок для не-VIP (не показываем для default/clear)
            if not s.isClear and not ZCITY_SKINS.IsVip(LocalPlayer()) then
                draw.SimpleText("VIP", "ZCSkins_Tiny", w - 14, h - 10,
                    clrVip, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
                -- Иконка-замок (символ)
                draw.SimpleText("⛔", "ZCSkins_Small", w - 38, h - 12,
                    clrVip, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
            end

            -- Чекмарк когда выбран
            if self2.SelLerp > 0.5 then
                local checkA = math.floor((self2.SelLerp - 0.5) * 2 * 255)
                draw.SimpleText("✓", "ZCSkins_H1", w - 16, h - 28,
                    Color(255, 255, 255, checkA), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
        card.DoClick = function()
            if self.SelectedSkin == s.id then return end
            self.SelectedSkin = s.id
            self:RefreshPreviewSmooth()
            surface.PlaySound("ui/buttonrollover.wav")
        end
    end
end

-- При смене скина внутри одного оружия — обновляем только превью без полного rebuild
function PANEL:RefreshPreviewSmooth()
    if not IsValid(self.PreviewModel) or not IsValid(self.PreviewModel.Entity) then
        self:BuildPreview()
        return
    end
    local skin = findSkin(self.SelectedSkin)
    -- Если у скина есть собственная модель — лучше пересобрать
    if skin and skin.model and self.PreviewModel:GetModel() ~= skin.model and not skin.isClear then
        self:BuildPreview()
        return
    end
    applySkinToEnt(self.PreviewModel.Entity, skin)
    -- Обновляем нижнюю плашку (детали) пересборкой нижней части превью
    -- Простой способ — полностью перестроить превью, но плавно (alpha-fade)
    self:RebuildBottomBar()
end

function PANEL:RebuildBottomBar()
    -- Найдём и удалим старую нижнюю плашку, потом создадим заново
    local skin = findSkin(self.SelectedSkin)
    for _, child in ipairs(self.PreviewPanel:GetChildren()) do
        if child._isInfoBar then child:Remove() end
    end
    local bottom = vgui.Create("DPanel", self.PreviewPanel)
    bottom._isInfoBar = true
    bottom:Dock(BOTTOM); bottom:SetTall(72); bottom:DockMargin(20, 0, 20, 18)
    bottom:SetAlpha(0); bottom:AlphaTo(255, 0.18, 0)
    bottom.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, clrPanel2)
        if skin and not skin.isClear then
            local rcol = rarityColor[skin.rarity or "common"]
            draw.RoundedBoxEx(8, 0, 0, 5, h, rcol, true, false, true, false)
            local rname = (rarityName[skin.rarity or "common"] or "обычный"):upper()
            surface.SetFont("ZCSkins_Tiny")
            local tw, th = surface.GetTextSize(rname)
            local bw, bh = tw + 18, th + 8
            local bx, by = w - bw - 12, 12
            draw.RoundedBox(4, bx, by, bw, bh, Color(rcol.r, rcol.g, rcol.b, 50))
            draw.RoundedBox(4, bx, by, 3, bh, rcol)
            draw.SimpleText(rname, "ZCSkins_Tiny", bx + 10, by + bh / 2, rcol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    local titleLbl = vgui.Create("DLabel", bottom)
    titleLbl:SetText(skin and skin.name or "СКИН НЕ ВЫБРАН")
    titleLbl:SetFont("ZCSkins_H1"); titleLbl:SetTextColor(clrText)
    titleLbl:Dock(TOP); titleLbl:DockMargin(16, 10, 16, 0); titleLbl:SetTall(24)
    local desc = vgui.Create("DLabel", bottom)
    desc:SetText(skin and skin.desc or "Выберите скин в правой колонке.")
    desc:SetFont("ZCSkins_Small"); desc:SetTextColor(clrSub)
    desc:SetWrap(true); desc:SetAutoStretchVertical(true)
    desc:Dock(FILL); desc:DockMargin(16, 4, 16, 8)
end

function PANEL:RefreshAfterChange()
    self:BuildLeft()
    self:BuildRight()
    self:BuildPreview()
end

vgui.Register("ZCity_SkinsMenu", PANEL, "DFrame")

concommand.Add("zcity_skins_menu", function()
    if IsValid(PANEL_REF) then PANEL_REF:Remove() end
    PANEL_REF = vgui.Create("ZCity_SkinsMenu")
end)
