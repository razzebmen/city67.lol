--[[---------------------------------------------------------------------------
ZCity Skins — VGUI редактор пресетов камеры
---------------------------------------------------------------------------
Открывается командой `zcity_skins_editor`.

Окно:
* Слева:  список моделей из ZCITY_SKINS.WeaponTabs (+ те, что есть в CameraPresets)
* Центр:  3D превью DModelPanel — ЛКМ-драг крутит yaw, колесо мыши = radius
* Справа: ползунки cx / cy / cz / radius / yaw + цифровые поля
* Низ:    кнопки [Сохранить эту] [Сохранить все] [Сбросить] [Закрыть]

Сохранение пишет:
* data/zcity_skins/camera_preset.lua    — одна строка для активной модели
* data/zcity_skins/camera_presets.lua   — все пресеты разом
* В буфер обмена кладётся готовый Lua-блок (Ctrl+V в sh_config.lua).

Команды редактирования (`zcity_skins_set/adj/...`) тоже работают — ползунки
и команды двунаправлены: ползунок двигает значение, и наоборот.
---------------------------------------------------------------------------]]
if not CLIENT then return end

ZCITY_SKINS = ZCITY_SKINS or {}
ZCITY_SKINS.CameraPresets = ZCITY_SKINS.CameraPresets or {}

-- ─── Палитра (синхронно с основным меню) ─────────────────────────────────────
local clrBg      = Color(10, 12, 18, 250)
local clrPanel   = Color(22, 25, 33, 245)
local clrPanel2  = Color(32, 36, 46, 240)
local clrCard    = Color(28, 31, 40)
local clrCardHov = Color(46, 52, 66)
local clrAccent  = Color(235, 70, 88)
local clrAccent2 = Color(255, 175, 70)
local clrText    = Color(238, 240, 245)
local clrSub     = Color(150, 156, 172)
local clrDivider = Color(255, 255, 255, 22)

surface.CreateFont("ZCSkinsEd_H1",   { font = "Bahnschrift", size = 22, weight = 700, antialias = true })
surface.CreateFont("ZCSkinsEd_Body", { font = "Bahnschrift", size = 16, weight = 600, antialias = true })
surface.CreateFont("ZCSkinsEd_Sml",  { font = "Bahnschrift", size = 13, weight = 500, antialias = true })

-- ─── Модельный список ────────────────────────────────────────────────────────
local function collectModels()
    local seen, list = {}, {}
    -- 1) Из вкладок основного меню (включая w_*-модели ножей)
    for _, t in ipairs(ZCITY_SKINS.WeaponTabs or {}) do
        if t.model and not seen[t.model] then
            seen[t.model] = true
            list[#list + 1] = { path = t.model, title = t.title or t.model }
        end
    end
    -- 2) Из существующих пресетов (на случай, если кто-то добавит вручную)
    for path in pairs(ZCITY_SKINS.CameraPresets) do
        if not seen[path] then
            seen[path] = true
            list[#list + 1] = { path = path, title = path }
        end
    end
    table.sort(list, function(a, b) return a.title < b.title end)
    return list
end

-- ─── AABB (упрощённая копия из основного меню) ───────────────────────────────
local function computeMeshAABB(modelPath)
    local meshes = util.GetModelMeshes(modelPath)
    if not meshes or #meshes == 0 then return nil end
    local mn = Vector(math.huge, math.huge, math.huge)
    local mx = Vector(-math.huge, -math.huge, -math.huge)
    local had = false
    for _, m in ipairs(meshes) do
        local tris = m.triangles
        if tris then
            for _, v in ipairs(tris) do
                local p = v.pos
                if p then
                    if p.x < mn.x then mn.x = p.x end
                    if p.y < mn.y then mn.y = p.y end
                    if p.z < mn.z then mn.z = p.z end
                    if p.x > mx.x then mx.x = p.x end
                    if p.y > mx.y then mx.y = p.y end
                    if p.z > mx.z then mx.z = p.z end
                    had = true
                end
            end
        end
    end
    if not had then return nil end
    return mn, mx
end

local function computeDefaults(modelPath)
    local pr = ZCITY_SKINS.CameraPresets[modelPath]
    if pr then
        return {
            cx     = pr.center.x, cy = pr.center.y, cz = pr.center.z,
            radius = pr.radius,   yaw = pr.yaw or 145,
        }
    end
    local mn, mx = computeMeshAABB(modelPath)
    if not mn then
        return { cx = 0, cy = 0, cz = 0, radius = 50, yaw = 145 }
    end
    local diag = (mx - mn):Length()
    if diag < 2 then diag = 50 end
    local c = (mn + mx) / 2
    return { cx = c.x, cy = c.y, cz = c.z, radius = diag * 1.75, yaw = 145 }
end

-- ─── Окно редактора ──────────────────────────────────────────────────────────
local EDITOR

local function presetLine(path, s)
    return string.format(
        '    [%q] = { center = Vector(%g, %g, %g), radius = %g, yaw = %g },',
        path, s.cx, s.cy, s.cz, s.radius, s.yaw)
end

local function saveDataFile(name, payload)
    file.CreateDir("zcity_skins")
    file.Write("zcity_skins/" .. name, payload)
end

local PANEL = {}

function PANEL:Init()
    self.Models  = collectModels()
    self.Active  = nil  -- индекс модели в self.Models
    self.State   = nil  -- {cx, cy, cz, radius, yaw}

    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetDraggable(true)
    self:SetSizable(false)

    local W, H = math.min(ScrW() * 0.7, 1100), math.min(ScrH() * 0.75, 720)
    self:SetSize(W, H)
    self:Center()
    self:MakePopup()

    self:BuildHeader()
    self:BuildLeft()
    self:BuildPreview()
    self:BuildRight()
    self:BuildFooter()

    if self.Models[1] then self:SelectModel(1) end
end

function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.startTime or SysTime())
    self.startTime = self.startTime or SysTime()
    draw.RoundedBox(10, 0, 0, w, h, clrBg)
    draw.RoundedBoxEx(10, 0, 0, w, 50, Color(80, 20, 20, 220), true, true, false, false)
    draw.SimpleText("РЕДАКТОР ПРЕСЕТОВ КАМЕРЫ", "ZCSkinsEd_H1", 18, 25,
        clrText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("ЛКМ + перетаскивание = поворот · колёсико = масштаб",
        "ZCSkinsEd_Sml", w - 18, 25, clrSub, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

function PANEL:OnKeyCodePressed(k)
    if k == KEY_ESCAPE then self:Close() end
end

function PANEL:Close()
    self:Remove()
    if EDITOR == self then EDITOR = nil end
end

-- ─── Шапка: кнопка закрыть ───────────────────────────────────────────────────
function PANEL:BuildHeader()
    local btn = vgui.Create("DButton", self)
    btn:SetText("✕")
    btn:SetFont("ZCSkinsEd_H1")
    btn:SetTextColor(clrText)
    btn:SetSize(36, 36)
    btn.PerformLayout = function(s) s:SetPos(self:GetWide() - 44, 8) end
    btn.Paint = function(s, w, h)
        local hov = s:IsHovered()
        draw.RoundedBox(6, 0, 0, w, h, hov and clrAccent or Color(40, 44, 56, 200))
    end
    btn.DoClick = function() self:Close() end
end

-- ─── Левая панель: список моделей ────────────────────────────────────────────
function PANEL:BuildLeft()
    local p = vgui.Create("DPanel", self)
    p.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, clrPanel)
        surface.SetDrawColor(clrDivider)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    self.Left = p

    local title = vgui.Create("DLabel", p)
    title:SetText("МОДЕЛИ")
    title:SetFont("ZCSkinsEd_H1")
    title:SetTextColor(clrText)
    title:Dock(TOP); title:DockMargin(14, 12, 14, 8); title:SetTall(26)

    for i, m in ipairs(self.Models) do
        local b = vgui.Create("DButton", p)
        b:SetText("")
        b:Dock(TOP); b:DockMargin(8, 4, 8, 0); b:SetTall(38)
        b.Paint = function(s, w, h)
            local sel = self.Active == i
            local hov = s:IsHovered()
            local col = sel and Color(80, 30, 38) or (hov and clrCardHov or clrCard)
            draw.RoundedBox(6, 0, 0, w, h, col)
            if sel then
                surface.SetDrawColor(clrAccent)
                surface.DrawRect(0, 0, 3, h)
            end
            draw.SimpleText(m.title, "ZCSkinsEd_Body", 14, h / 2,
                clrText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function() self:SelectModel(i) end
    end
end

-- ─── Центр: 3D превью ────────────────────────────────────────────────────────
function PANEL:BuildPreview()
    local p = vgui.Create("DPanel", self)
    p.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, clrPanel)
        surface.SetDrawColor(clrDivider)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    self.Mid = p

    local mp = vgui.Create("DModelPanel", p)
    mp:Dock(FILL); mp:DockMargin(12, 12, 12, 12)
    mp:SetFOV(35)
    mp:SetAnimSpeed(0)
    mp.bAnimated = false

    -- Управление мышью
    function mp:OnMousePressed(code)
        if code == MOUSE_LEFT then
            self.Drag    = true
            self.PressX  = gui.MouseX()
            self.PressYaw = (EDITOR and EDITOR.State and EDITOR.State.yaw) or 145
        end
    end
    function mp:OnMouseReleased() self.Drag = false end
    function mp:Think()
        if not EDITOR or not EDITOR.State then return end
        if self.Drag then
            local s = EDITOR.State
            s.yaw = (self.PressYaw or 0) + (gui.MouseX() - (self.PressX or 0)) * 0.4
            EDITOR:SyncControls("yaw")
        end
    end
    function mp:OnMouseWheeled(delta)
        if not EDITOR or not EDITOR.State then return end
        local s = EDITOR.State
        s.radius = math.max(5, (s.radius or 50) - delta * 2)
        EDITOR:SyncControls("radius")
    end

    function mp:LayoutEntity(ent)
        ent:SetCycle(0)
        ent:SetPlaybackRate(0)
        if not EDITOR or not EDITOR.State then return end
        local s = EDITOR.State
        local ang = Angle(0, s.yaw or 0, 0)
        local rotated = Vector(s.cx or 0, s.cy or 0, s.cz or 0)
        rotated:Rotate(ang)
        ent:SetAngles(ang)
        ent:SetPos(-rotated)
        self:SetCamPos(Vector(s.radius or 50, 0, (s.radius or 50) * 0.08))
        self:SetLookAt(Vector(0, 0, 0))
    end

    self.Preview = mp
end

-- ─── Правая панель: ползунки ─────────────────────────────────────────────────
function PANEL:BuildRight()
    local p = vgui.Create("DPanel", self)
    p.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, clrPanel)
        surface.SetDrawColor(clrDivider)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    self.Right = p

    local title = vgui.Create("DLabel", p)
    title:SetText("ПАРАМЕТРЫ")
    title:SetFont("ZCSkinsEd_H1")
    title:SetTextColor(clrText)
    title:Dock(TOP); title:DockMargin(14, 12, 14, 8); title:SetTall(26)

    self.Sliders = {}

    local function makeSlider(key, label, min, max, decimals)
        local row = vgui.Create("DPanel", p)
        row:Dock(TOP); row:DockMargin(12, 6, 12, 0); row:SetTall(54)
        row.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, clrPanel2) end

        local lbl = vgui.Create("DLabel", row)
        lbl:SetText(label); lbl:SetFont("ZCSkinsEd_Body"); lbl:SetTextColor(clrText)
        lbl:Dock(TOP); lbl:DockMargin(10, 6, 10, 0); lbl:SetTall(18)

        local sl = vgui.Create("DNumSlider", row)
        sl:Dock(FILL); sl:DockMargin(8, 0, 8, 4)
        sl:SetMin(min); sl:SetMax(max); sl:SetDecimals(decimals or 2)
        sl:SetText("")
        sl.Label:SetText("")
        sl.OnValueChanged = function(_, v)
            if not self.State or self._suppressSync then return end
            self.State[key] = v
        end
        self.Sliders[key] = sl
    end

    makeSlider("cx",     "Center X",  -200, 200, 2)
    makeSlider("cy",     "Center Y",  -200, 200, 2)
    makeSlider("cz",     "Center Z",  -200, 200, 2)
    makeSlider("radius", "Radius",    5,    300, 1)
    makeSlider("yaw",    "Yaw (°)",   -360, 720, 1)
end

-- ─── Низ: кнопки ─────────────────────────────────────────────────────────────
function PANEL:BuildFooter()
    local f = vgui.Create("DPanel", self)
    f.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, clrPanel)
        surface.SetDrawColor(clrDivider)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    self.Footer = f

    local function btn(text, color, onClick)
        local b = vgui.Create("DButton", f)
        b:SetText("")
        b:Dock(LEFT); b:DockMargin(8, 8, 0, 8); b:SetWide(180)
        b.Paint = function(s, w, h)
            local hov = s:IsHovered()
            local c = hov and Color(color.r + 20, color.g + 20, color.b + 20, color.a or 255) or color
            draw.RoundedBox(6, 0, 0, w, h, c)
            draw.SimpleText(text, "ZCSkinsEd_Body", w / 2, h / 2,
                color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = onClick
        return b
    end

    btn("СОХРАНИТЬ ЭТУ", clrAccent, function() self:SaveOne() end)
    btn("СОХРАНИТЬ ВСЕ", Color(80, 130, 200), function() self:SaveAll() end)
    btn("СБРОС AABB",   Color(110, 110, 130), function() self:ResetAuto() end)
    btn("ЗАКРЫТЬ",       Color(80, 84, 96),    function() self:Close() end)
end

-- ─── Layout ──────────────────────────────────────────────────────────────────
function PANEL:PerformLayout(w, h)
    if not self.Left then return end
    local pad   = 12
    local top   = 58
    local bot   = 58
    local leftW, rightW = 230, 280
    self.Left:SetPos(pad, top); self.Left:SetSize(leftW, h - top - bot - pad)
    self.Mid:SetPos(pad + leftW + pad, top)
    self.Mid:SetSize(w - leftW - rightW - pad * 4, h - top - bot - pad)
    self.Right:SetPos(w - rightW - pad, top); self.Right:SetSize(rightW, h - top - bot - pad)
    self.Footer:SetPos(pad, h - bot); self.Footer:SetSize(w - pad * 2, bot - pad)
end

-- ─── Логика ──────────────────────────────────────────────────────────────────
function PANEL:SelectModel(idx)
    local m = self.Models[idx]; if not m then return end
    self.Active = idx
    self.State = computeDefaults(m.path)
    if IsValid(self.Preview) then self.Preview:SetModel(m.path) end
    self:SyncControls()
end

function PANEL:SyncControls(onlyKey)
    if not self.State then return end
    self._suppressSync = true
    for k, sl in pairs(self.Sliders) do
        if not onlyKey or onlyKey == k then
            sl:SetValue(self.State[k] or 0)
        end
    end
    self._suppressSync = false
end

function PANEL:CurrentModel()
    return self.Models[self.Active or 0]
end

function PANEL:CommitToPresets()
    local m = self:CurrentModel(); if not m then return end
    local s = self.State; if not s then return end
    ZCITY_SKINS.CameraPresets[m.path] = {
        center = Vector(s.cx, s.cy, s.cz),
        radius = s.radius,
        yaw    = s.yaw,
    }
end

function PANEL:SaveOne()
    self:CommitToPresets()
    local m = self:CurrentModel(); if not m then return end
    local line = presetLine(m.path, self.State)
    local body = "-- ZCity skins: пресет камеры (одна модель)\n" ..
                 "-- Скопируй строку ниже в ZCITY_SKINS.CameraPresets в sh_config.lua\n" ..
                 line .. "\n"
    saveDataFile("camera_preset.lua", body)
    SetClipboardText(line)
    chat.AddText(Color(120,220,120), "[skins] ", color_white,
        "Сохранено: data/zcity_skins/camera_preset.lua (строка в буфере)")
    print("[skins] " .. line)
end

function PANEL:SaveAll()
    self:CommitToPresets()
    local lines = {}
    for path, pr in pairs(ZCITY_SKINS.CameraPresets) do
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
    saveDataFile("camera_presets.lua", body)
    SetClipboardText(body)
    chat.AddText(Color(120,220,120), "[skins] ", color_white,
        string.format("Сохранено %d пресетов: data/zcity_skins/camera_presets.lua (блок в буфере)", #lines))
end

function PANEL:ResetAuto()
    local m = self:CurrentModel(); if not m then return end
    ZCITY_SKINS.CameraPresets[m.path] = nil
    self.State = computeDefaults(m.path)  -- возьмёт AABB
    self:SyncControls()
    chat.AddText(Color(255,200,80), "[skins] ", color_white,
        "Авто-AABB восстановлен для " .. m.path)
end

vgui.Register("ZCity_SkinsEditor", PANEL, "DFrame")

concommand.Add("zcity_skins_editor", function()
    if IsValid(EDITOR) then EDITOR:Remove() end
    EDITOR = vgui.Create("ZCity_SkinsEditor")
end, nil, "Открыть VGUI редактор пресетов камеры скин-меню")
