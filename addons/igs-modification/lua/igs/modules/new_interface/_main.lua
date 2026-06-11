IGS.sh("utf8.lua")

if SERVER then
    resource.AddWorkshop("2786808725")
    return
end

utf8.len = string.utf8len

-- ─── Менеджер загружаемых текстур товаров ────────────────────────────────────
local texture = {}
do
    local _cache = {} -- uid -> Material | false

    function texture.Create(uid)
        return {
            Download = function(self, url)
                if _cache[uid] ~= nil then return end
                _cache[uid] = false -- идёт загрузка
                http.Fetch(url, function(data, _, _, code)
                    if code ~= 200 or not data or #data == 0 then
                        _cache[uid] = false
                        return
                    end
                    file.CreateDir("igs_textures")
                    local fname = "igs_textures/" .. uid .. ".png"
                    file.Write(fname, data)
                    local mat = Material("data/" .. fname, "smooth noclamp")
                    _cache[uid] = mat
                end, function()
                    _cache[uid] = false
                end)
            end
        }
    end

    function texture.Get(uid)
        local mat = _cache[uid]
        if not mat then return nil end
        return mat
    end
end
-- ─────────────────────────────────────────────────────────────────────────────

local FONT_TAB_ACTIVE      = "igs.20"
local FONT_TAB_INACTIVE    = "igs.18"
local FONT_IGS_CAT         = "igs.40"
local FONT_ITEM_PURCHASED  = "igs.15"
local FONT_ITEM_NAME       = "igs.18"
local FONT_ITEM_PRICE      = "igs.18"
local FONT_INVENTORY_NAME  = "igs.22"
local FONT_INVENTORY_TERM  = "igs.18"
local FONT_INVENTORY_ACTIVATE = "igs.20"
local FONT_INVENTORY_DROP  = "igs.17"
local FONT_INVENTORY_NONE  = "igs.40"
local FONT_CHOOSE_ITEM     = "igs.20"
local FONT_ITEM_PRICE_OLD  = "igs.15"
local FONT_ITEM_SUB        = "igs.15"
local FONT_ITEM_DESC_TITLE = "igs.20"
local FONT_ITEM_DESC       = "igs.17"
local FONT_BAL             = "igs.17"
local FONT_TABLE_COLUMN    = "igs.17"
local FONT_TABLE_ROW       = FONT_TABLE_COLUMN
local FONT_LAST_TOPUP_DATE = "igs.17"
local FONT_LAST_TOPUP_SUM  = "igs.22"
local FONT_PROFILE_NAME    = "igs.18"
local FONT_PROFILE_SID     = "igs.15"
local FONT_TOPUPS_SUM      = "igs.15"
local FONT_SIDE_BUTTONS    = "igs.18"
local FONT_THANKS          = "igs.24"
local FONT_LOG_TEXT        = "igs.18"
local FONT_TOPUP_AMOUNT    = FONT_LOG_TEXT
local FONT_TOPUP_BUTTON    = "igs.18"

local function pX(a)
    return a
end

local function matsmooth(mat)
    return Material(mat, "smooth")
end

local close_mat           = matsmooth("hrp/gui/donate/close.png")
local shop_mat            = matsmooth("hrp/gui/donate/shop.png")
local shop_unactive_mat   = matsmooth("hrp/gui/donate/shop_unactive.png")
local profile_mat         = matsmooth("hrp/gui/donate/profile.png")
local profile_unactive_mat = matsmooth("hrp/gui/donate/profile_unactive.png")
local go_mat              = matsmooth("hrp/gui/donate/go.png")
local grad_mat            = matsmooth("hrp/gui/donate/grad.png")
local buy_mat             = matsmooth("hrp/gui/donate/buy.png")
local heart_mat           = matsmooth("hrp/gui/donate/heart.png")
local coupon_mat          = matsmooth("hrp/gui/donate/coupon.png")

NM = {}

NM.Tabs = {
    ["shop"] = {
        ID = 1,
        Name = "Услуги",
        Mats = { shop_mat, shop_unactive_mat }
    },
    ["profile"] = {
        ID = 2,
        Name = "Профиль",
        Mats = { profile_mat, profile_unactive_mat }
    }
}

if IGS.C.Inv_Enabled then
    NM.Tabs["inventory"] = {
        ID = 3,
        Name = "Инвентарь",
        Mats = { shop_mat, shop_unactive_mat }
    }
end

NM.OpenFirstTab = "shop"

NM.Buttons = {
    ["profile_purchases"] = { ID = 1, Name = "Покупки" },
    ["profile_donate"]    = { ID = 2, Name = "Пополнить баланс" }
}

NM.PathToRefill = { [1] = "profile", [2] = "profile_donate" }

function NM.CreateUI(t, f, p)
    local parent
    if (not isfunction(f)) and (f ~= nil) then
        parent = f
    elseif not isfunction(p) and (p ~= nil) then
        parent = p
    end
    local v = vgui.Create(t, parent)
    if isfunction(f) then
        f(v, parent)
    elseif isfunction(p) then
        p(v, f)
    end
    return v
end

local tabfr

function NM.OpenTab(tab, frame)
    if IsValid(tabfr) then tabfr:Remove() end
    tabfr = NM.CreateUI("nm_" .. tab, function(self)
        self:SetSize(pX(978), pX(530) - pX(54))
        self:SetPos(0, pX(54))
    end, frame)
end

local btnfr

function NM.OpenButton(btn, frame)
    if IsValid(btnfr) then btnfr:Remove() end
    btnfr = NM.CreateUI("nm_" .. btn, function(self)
        self:SetSize(pX(781), pX(530) - pX(54))
        self:SetPos(0, 0)
    end, frame)
end

function NM.GetItems()
    local allcats = {}
    for k, v in pairs(IGS.GetItems()) do
        if k ~= 0 and v.hidden ~= true and not allcats[v.category or "Разное"] then
            allcats[v.category or "Разное"] = true
        end
    end
    return allcats
end

function NM.FancyTerm(item)
    local term = IGS.TermToStr(item)
    if term == "бесконечно" then
        return "Навсегда"
    elseif term == "единоразово" then
        return "Одноразово"
    else
        return "На " .. term
    end
end

-- ───────────────────────────────────────────────────────────────────────────
-- Discord-баннер: рисуется поверх меню через PostRenderVGUI
-- ───────────────────────────────────────────────────────────────────────────

local _donateFrame = nil
local BANNER_H     = 76
local BANNER_GAP   = 5

-- Цвета Discord
local CLR_BG        = Color(22, 25, 42, 254)
local CLR_BG2       = Color(28, 32, 52, 252)
local CLR_BORDER    = Color(50, 56, 90, 180)
local CLR_BLURPLE   = Color(88, 101, 242)
local CLR_BLURPLE2  = Color(66, 75, 196)
local CLR_TEXT_MAIN = Color(215, 218, 238, 245)
local CLR_TEXT_SUB  = Color(130, 138, 178, 220)
local CLR_USERNAME  = Color(114, 137, 218, 255)
local CLR_WHITE     = Color(255, 255, 255, 255)

hook.Add("PostRenderVGUI", "NM_DiscordBanner", function()
    if not IsValid(_donateFrame) or not _donateFrame:IsVisible() then return end

    local fw = _donateFrame:GetWide()
    local fx, fy = _donateFrame:GetPos()
    local bx = fx
    local by = fy - BANNER_H - BANNER_GAP

    if by < 2 then return end

    -- Тень / обводка
    draw.RoundedBox(12, bx - 1, by - 1, fw + 2, BANNER_H + 2, CLR_BORDER)
    -- Основной фон
    draw.RoundedBox(11, bx, by, fw, BANNER_H, CLR_BG)
    draw.RoundedBox(11, bx + 1, by + 1, fw - 2, BANNER_H - 2, CLR_BG2)

    -- Левая вертикальная полоска (blurple)
    draw.RoundedBox(3, bx + 7, by + 12, 4, BANNER_H - 24, CLR_BLURPLE)

    -- Круглая иконка Discord (фон + буква D)
    local ic_cx = bx + 34
    local ic_cy = by + BANNER_H / 2
    draw.RoundedBox(22, ic_cx - 20, ic_cy - 20, 40, 40, CLR_BLURPLE2)
    draw.RoundedBox(22, ic_cx - 19, ic_cy - 19, 38, 38, CLR_BLURPLE)
    draw.SimpleText("D", "igs.22", ic_cx, ic_cy, CLR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Бейдж «-15%»
    local bx2 = bx + 64
    local by2 = by + BANNER_H / 2 - 15
    draw.RoundedBox(6, bx2, by2, 60, 30, CLR_BLURPLE2)
    draw.RoundedBox(6, bx2 + 1, by2 + 1, 58, 28, CLR_BLURPLE)
    draw.SimpleText("-15%", "igs.20", bx2 + 30, by + BANNER_H / 2, CLR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Тонкий разделитель
    draw.RoundedBox(0, bx + 136, by + 14, 1, BANNER_H - 28, Color(55, 62, 100, 180))

    -- Основной текст
    local tx = bx + 148
    local ty = by + BANNER_H / 2
    draw.SimpleText(
        "Купи привилегию дешевле напрямую через Discord!",
        "igs.18", tx, ty - 12, CLR_TEXT_MAIN,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )
    draw.SimpleText(
        "Пиши напрямую:",
        "igs.17", tx, ty + 9, CLR_TEXT_SUB,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )

    -- Ник — выделен blurple в мини-таблетке
    local ux = tx + 116
    local uw = 102
    draw.RoundedBox(4, ux - 5, ty + 2, uw, 18, Color(38, 44, 75, 200))
    draw.SimpleText("paich9045", "igs.17", ux, ty + 11, CLR_USERNAME, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end)

-- ───────────────────────────────────────────────────────────────────────────
-- Главное меню
-- ───────────────────────────────────────────────────────────────────────────

local fr

function NM.Menu()
    if IsValid(fr) then
        fr:Close()
        return
    end

    local w, h = pX(978), pX(530)

    fr = NM.CreateUI("DFrame", function(self)
        self.lblTitle:SetText("")
        self:SetSize(w, h)
        self:MakePopup()
        self:Center()
        self.btnMaxim:SetVisible(false)
        self.btnMinim:SetVisible(false)

        function self:Paint(pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, Color(31, 31, 31))
            draw.RoundedBoxEx(8, 0, self:GetTitleHeight(), pX(781), pX(476), Color(47, 47, 47), false, false, true)
            draw.RoundedBoxEx(8, pw - pX(85), self:GetTitleHeight() / 2 - pX(11), pX(22), pX(22), Color(35, 108, 0), false, true, false, true)
            draw.SimpleText("+", FONT_BAL, pw - pX(74), self:GetTitleHeight() / 2, Color(255, 255, 255), 1, 1)
            draw.RoundedBoxEx(8, pw - pX(185), self:GetTitleHeight() / 2 - pX(11), pX(100), pX(22), Color(55, 55, 55), true, false, true, false)
            draw.SimpleText(IGS.SignPrice(LocalPlayer():IGSFunds()), FONT_BAL, pw - pX(92), self:GetTitleHeight() / 2 - pX(1), Color(255, 255, 255), TEXT_ALIGN_RIGHT, 1)
            draw.RoundedBox(0, 0, self:GetTitleHeight(), pw, 1, Color(47, 47, 47))
        end

        function self:GetTitleHeight()
            return pX(54)
        end

        local cbtn = pX(17)

        function self.btnClose:Paint(cw, ch)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(close_mat)
            surface.DrawTexturedRect(0, 0, cbtn, cbtn)
        end

        function self:PerformLayout()
            self.btnClose:SetPos(self:GetWide() - pX(28) - cbtn, self:GetTitleHeight() / 2 - cbtn / 2)
            self.btnClose:SetSize(cbtn, cbtn)
        end

        function self:SwitchTab(tab)
            self.ActiveTab = NM.Tabs[tab]
            self.OpenedTab = NM.OpenTab(tab, self)
        end

        self:SwitchTab(NM.OpenFirstTab)
    end)

    -- Активируем Discord-баннер
    _donateFrame = fr

    local origClose = fr.Close
    function fr:Close()
        _donateFrame = nil
        origClose(self)
    end

    -- Кнопка пополнения баланса (зелёный «+»)
    NM.CreateUI("DButton", function(self)
        self:SetText("")
        self:SetSize(pX(22), pX(22))
        self:SetPos(w - pX(85), fr:GetTitleHeight() / 2 - pX(11))
        self.DoClick = function()
            fr:SwitchTab(NM.PathToRefill[1])
            tabfr:SwitchButton(NM.PathToRefill[2])
        end
        self.Paint = function() end
    end, fr)

    local textx, texty = pX(54), fr:GetTitleHeight() / 2
    local iconx, iconwh, iconwhun = pX(16), pX(26), pX(22)

    for k, v in pairs(NM.Tabs) do
        NM.CreateUI("DButton", function(self)
            self:SetText("")
            self:SetSize(pX(223), fr:GetTitleHeight())
            self:SetPos(pX(29) + pX(237 * (v.ID - 1)), 0)
            self.Tab = k

            self.DoClick = function(s)
                if fr.ActiveTab == NM.Tabs[s.Tab] then return end
                fr:SwitchTab(s.Tab)
            end

            function self:Paint(bw, bh)
                if fr.ActiveTab == NM.Tabs[self.Tab] then
                    draw.RoundedBoxEx(8, 0, 0, bw, bh, Color(62, 62, 62), true, true)
                    draw.SimpleText(v.Name, FONT_TAB_ACTIVE, textx, texty, Color(200, 200, 200), 0, 1)
                    surface.SetDrawColor(255, 255, 255)
                    surface.SetMaterial(v.Mats[1])
                    surface.DrawTexturedRect(iconx, texty - iconwh / 2, iconwh, iconwh)
                else
                    draw.RoundedBoxEx(8, 0, bh * .17, bw, bh * .83, Color(55, 55, 55), true, true)
                    draw.SimpleText(v.Name, FONT_TAB_INACTIVE, textx - pX(4), texty + bh * .085, Color(105, 105, 105), 0, 1)
                    surface.SetDrawColor(255, 255, 255)
                    surface.SetMaterial(v.Mats[2])
                    surface.DrawTexturedRect(iconx, texty - iconwhun / 2 + bh * .085, iconwhun, iconwhun)
                end
            end
        end, fr)
    end

    return fr
end

-- ───────────────────────────────────────────────────────────────────────────
-- VGUI: кастомный скроллбар
-- ───────────────────────────────────────────────────────────────────────────

local PANEL = {}

function PANEL:Init()
    self.parent = self:GetParent()
    self.scrollButton = vgui.Create("Panel", self)

    self.scrollButton.OnMousePressed = function(s, mb)
        if mb == MOUSE_LEFT and not self:GetParent().ShouldHideScrollbar then
            local _, my = s:CursorPos()
            s.scrolling = true
            s.mouseOffset = my
        end
    end

    self.scrollButton.OnMouseReleased = function(s, mb)
        if mb == MOUSE_LEFT then
            s.scrolling = false
            s.mouseOffset = nil
        end
    end

    self.height = 0
end

function PANEL:Think()
    if self.scrollButton.scrolling then
        if not input.IsMouseDown(MOUSE_LEFT) then
            self.scrollButton:OnMouseReleased(MOUSE_LEFT)
            return
        end
        local _, my = self.scrollButton:CursorPos()
        local diff = my - self.scrollButton.mouseOffset
        local maxOffset = self.parent:GetCanvas():GetTall() - self.parent:GetTall()
        local perc = (self.scrollButton.y + diff) / (self:GetTall() - self.height)
        self.parent.yOffset = math.Clamp(perc * maxOffset, 0, maxOffset)
        self.parent:InvalidateLayout()
    end
end

function PANEL:PerformLayout()
    local maxOffset = self.parent:GetCanvas():GetTall() - self.parent:GetTall()
    self:SetSize(2, self.parent:GetTall())
    self:SetPos(self.parent:GetWide() - self:GetWide(), 0)
    self.heightRatio = self.parent:GetTall() / self.parent:GetCanvas():GetTall()
    self.height = math.Clamp(math.ceil(self.heightRatio * self.parent:GetTall()), 20, math.huge)
    self.scrollButton:SetSize(self:GetWide(), self.height)
    self.scrollButton:SetPos(0, math.Clamp(self.parent.yOffset / maxOffset, 0, 1) * (self:GetTall() - self.height))
end

function PANEL:Paint(w, h)
    if self:GetParent().ShouldHideScrollbar then return end
    derma.SkinHook("Paint", "UIScrollBar", self, w, h)
end

function PANEL:OnMouseWheeled(delta)
    self.parent:OnMouseWheeled(delta)
end

vgui.Register("nm_scrollbar", PANEL, "Panel")

-- ───────────────────────────────────────────────────────────────────────────
-- VGUI: скролл-панель
-- ───────────────────────────────────────────────────────────────────────────

PANEL = {}

function PANEL:Init()
    self.contentContainer = vgui.Create("Panel", self)
    self.scrollBar = vgui.Create("nm_scrollbar", self)
    self.yOffset = 0
    self.ySpeed = 0
    self.scrollSize = 4
    self.SpaceTop = 0
    self.Padding = 0

    function self.contentContainer:OnChildRemoved()
        self:GetParent():PerformLayout()
    end
end

function PANEL:Reset()
    self:GetCanvas():Clear(true)
    self.yOffset = 0
    self.ySpeed = 0
    self.scrollSize = 1
    self:PerformLayout()
end

function PANEL:AddItem(child)
    child:SetParent(self:GetCanvas())
    self:PerformLayout()
end

function PANEL:SetSpacing(i) self.SpaceTop = i end
function PANEL:SetPadding(i) self.Padding = i end
function PANEL:GetCanvas() return self.contentContainer end
function PANEL:SetScrollSize(int) self.scrollSize = int end

function PANEL:ScrollTo(y)
    self.yOffset = y
    self:InvalidateLayout()
end

function PANEL:OnMouseWheeled(delta)
    if (delta > 0 and self.ySpeed < 0) or (delta < 0 and self.ySpeed > 0) then
        self.ySpeed = 0
    else
        self.ySpeed = self.ySpeed + (delta * self.scrollSize)
    end
    self:PerformLayout()
end

function PANEL:SetOffset(offSet)
    local maxOffset = self:GetCanvas():GetTall() - self:GetTall()
    if maxOffset < 0 then maxOffset = 0 end
    self.yOffset = math.Clamp(offSet, 0, maxOffset)
    self:PerformLayout()
    if self.yOffset == 0 or self.yOffset == maxOffset then return true end
end

function PANEL:Think()
    if self.ySpeed ~= 0 then
        if self:SetOffset(self.yOffset - self.ySpeed) then
            self.ySpeed = 0
        else
            if self.ySpeed < 0 then
                self.ySpeed = math.Clamp(self.ySpeed + (FrameTime() * self.scrollSize * 4), self.ySpeed, 0)
            else
                self.ySpeed = math.Clamp(self.ySpeed - (FrameTime() * self.scrollSize * 4), 0, self.ySpeed)
            end
        end
    end
end

function PANEL:PerformLayout()
    local canvas = self:GetCanvas()
    if canvas:GetWide() ~= self:GetWide() then canvas:SetWide(self:GetWide()) end

    local y = 0
    local lastChild

    for _, v in ipairs(canvas:GetChildren()) do
        local childY = y + self.SpaceTop
        if v.x ~= self.Padding or v.y ~= childY then
            v:SetPos(math.max(0, self.Padding), y + self.SpaceTop)
        end
        if v:GetWide() ~= self:GetWide() - self.Padding * 2 then
            v:SetWide(math.min(self:GetWide(), self:GetWide() - self.Padding * 2))
        end
        y = v.y + v:GetTall() + self.SpaceTop + self.Padding
        lastChild = v
    end

    y = lastChild and lastChild.y + lastChild:GetTall() or y
    if canvas:GetTall() ~= y then canvas:SetTall(y) end

    if canvas:GetTall() <= self:GetTall() and self.scrollBar:IsVisible() then
        canvas:SetTall(self:GetTall())
        self.scrollBar:SetVisible(false)
    elseif canvas:GetTall() > self:GetTall() and not self.scrollBar:IsVisible() then
        self.scrollBar:SetVisible(true)
    end

    local maxOffset = self:GetCanvas():GetTall() - self:GetTall()
    if self.yOffset > maxOffset then self.yOffset = maxOffset end
    if self.yOffset < 0 then self.yOffset = 0 end

    if canvas.x ~= 0 or canvas.y ~= -self.yOffset then
        canvas:SetPos(0, -self.yOffset)
        self.scrollBar:InvalidateLayout()
    end
end

function PANEL:IsAtMaxOffset()
    local maxOffset = math.Clamp(self:GetCanvas():GetTall() - self:GetTall(), 0, math.huge)
    return self.yOffset == maxOffset
end

function PANEL:Paint() end

function PANEL:HideScrollbar(bool)
    self.ShouldHideScrollbar = bool
end

function PANEL:DockToFrame()
    local p = self:GetParent()
    local x, y = p:GetDockPos()
    self:SetPos(x, y)
    self:SetSize(p:GetWide() - 10, p:GetTall() - (y + 5))
end

vgui.Register("nm_scrollpanel", PANEL, "Panel")

-- ───────────────────────────────────────────────────────────────────────────
-- VGUI: список
-- ───────────────────────────────────────────────────────────────────────────

PANEL = {}

function PANEL:Init()
    self.Rows = {}
    self.HideInvisible = true
    self.RowHeight = 25
    self:SetPadding(-1)

    self.scrollBar.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, s.scrollButton.y, w, s.height, Color(255, 255, 255))
    end
end

function PANEL:SetRowHeight(height) self.RowHeight = height end

function PANEL:AddCustomRow(row)
    self:AddItem(row)
    self.Rows[#self.Rows + 1] = row
    return row
end

function PANEL:AddRow(value, disabled)
    local row = NM.CreateUI("DButton", function(s)
        s:SetText("")
        s:SetTall(self.RowHeight)
        if disabled == true then s:SetDisabled(true) end
        s.Paint = function(rs, w, h)
            draw.SimpleText(tostring(value), FONT_IGS_CAT, pX(29), h / 2, Color(255, 255, 255, 255), 0, 1)
        end
    end)
    self:AddItem(row)
    self.Rows[#self.Rows + 1] = row
    row.DoClick = function()
        row.Active = true
        if IsValid(self.Selected) then self.Selected.Active = false end
        self.Selected = row
    end
    return row
end

function PANEL:AddSpacer(value) return self:AddRow(value, true) end
function PANEL:GetSelected() return self.Selected end

vgui.Register("nm_listview", PANEL, "nm_scrollpanel")

-- ───────────────────────────────────────────────────────────────────────────
-- VGUI: карточка товара в магазине
-- ───────────────────────────────────────────────────────────────────────────

PANEL = {}

function PANEL:Init()
    self:SetText("")
    self.ButtonBuy = NM.CreateUI("DButton", self)
    self.ModelIcon = NM.CreateUI("DModelPanel", self)
end

function PANEL:PerformLayout()
    local btnwh = pX(25)
    self.ButtonBuy:SetPos(self:GetWide() - pX(12) - btnwh, self:GetTall() - btnwh - pX(12))
    self.ButtonBuy:SetSize(btnwh, btnwh)
    self.ButtonBuy:SetText("")
    self.ButtonBuy.Paint = function(s, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(buy_mat)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    local iconwh = pX(80)
    self.ModelIcon:SetPos(self:GetWide() / 2 - iconwh / 2, pX(6))
    self.ModelIcon:SetSize(iconwh, iconwh)
end

function PANEL:Paint(w, h)
    draw.RoundedBox(8, 0, 0, w, h, self.MainFrame.ActiveItem == self.Item and Color(223, 223, 223) or Color(68, 68, 68))
    draw.RoundedBox(8, 1, 1, w - 2, h - 2, Color(55, 55, 55))
    local item = IGS.GetItem(self.Item)
    local name = item.name
    if utf8.len(name) > 16 then name = utf8.sub(name, 0, 14) .. "..." end
    draw.SimpleText(name, FONT_ITEM_NAME, pX(16), h - pX(60), item.highlight or Color(255, 255, 255), 0, 4)
    local tw, th = draw.SimpleText("Подробнее", FONT_ITEM_SUB, pX(16), h - pX(45), Color(105, 105, 105), 0, 4)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(go_mat)
    surface.DrawTexturedRect(pX(16) + tw + pX(10), h - pX(45) - th / 2 - pX(1), pX(4), pX(6))
    if item.discounted_from then
        tw, th = draw.SimpleText(IGS.SignPrice(item.discounted_from), FONT_ITEM_PRICE_OLD, pX(16), h - pX(30), Color(105, 105, 105), 0, 4)
        local liney = h - pX(34)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawLine(pX(16), liney - th * .5, pX(16) + tw, liney)
    end
    draw.SimpleText(IGS.SignPrice(item.price), FONT_ITEM_PRICE, pX(16), h - pX(16), Color(255, 255, 255), 0, 4)
    if item.icon and not item.icon.isModel then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(texture.Get(item.uid) or close_mat)
        local iconwh = pX(80)
        surface.DrawTexturedRect(w / 2 - iconwh / 2, pX(6), iconwh, iconwh)
        surface.SetDrawColor(255, 255, 255, 180)
        surface.SetMaterial(grad_mat)
        surface.DrawTexturedRect(pX(1), pX(12), w - pX(2), iconwh)
    end
end

function PANEL:SetInfo(uid, frame)
    self.Item = uid
    self.MainFrame = frame
    local item = IGS.GetItem(self.Item)

    self.DoClick = function()
        frame:OpenItem(uid)
    end

    self.ButtonBuy.DoClick = function()
        IGS.BoolRequest("Подтверждение покупки", "Вы действительно хотите купить " .. item.name .. "?", function(a)
            if a then frame:BuyItem(uid) end
        end)
    end

    self.ModelIcon.DoClick = function()
        frame:OpenItem(uid)
    end

    if item.icon and not item.icon.isModel then
        texture.Create(item.uid):Download(item.icon.icon)
        self.ModelIcon:SetVisible(false)
    elseif item.icon and item.icon.isModel then
        self.ModelIcon:SetVisible(true)
        self.ModelIcon:SetModel(item.icon.icon)
        local mn, mx = self.ModelIcon.Entity:GetRenderBounds()
        local size = 0
        size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
        size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
        size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
        self.ModelIcon:SetFOV(30)
        self.ModelIcon:SetCamPos(Vector(size, size, size))
        self.ModelIcon:SetLookAt((mn + mx) * 0.5)
    end

    self:SetToolTip(item.name)
end

vgui.Register("nm_shop_button", PANEL, "DButton")

-- ───────────────────────────────────────────────────────────────────────────
-- VGUI: категория товаров
-- ───────────────────────────────────────────────────────────────────────────

PANEL = {}

local btnwh = pX(168)

function PANEL:PerformLayout()
    local c = 0
    local o = 0
    for k, v in ipairs(self:GetChildren()) do
        v:SetPos(pX(29) + (o * (btnwh + pX(20))), c * (btnwh + pX(20)))
        v:SetSize(btnwh, btnwh)
        if     k % 4 == 1 then o = 1
        elseif k % 4 == 2 then o = 2
        elseif k % 4 == 3 then o = 3
        elseif k % 4 == 0 then c = c + 1; o = 0
        end
    end
end

function PANEL:AddItem(uid, frame)
    local btn = NM.CreateUI("nm_shop_button", self)
    btn:SetInfo(uid, frame)
    self:SetTall(math.ceil(#self:GetChildren() * (1 / 4)) * btnwh + math.ceil(#self:GetChildren() * (pX(20) / 4)))
end

vgui.Register("nm_shop_category", PANEL, "Panel")

-- ───────────────────────────────────────────────────────────────────────────
-- VGUI: вкладка магазина
-- ───────────────────────────────────────────────────────────────────────────

PANEL = {}

function PANEL:Init()
    self.Paint = function()
        if not IsValid(self.OpenedItem) then
            draw.SimpleText("Выберите предмет!", FONT_CHOOSE_ITEM, pX(877), pX(20), color_white, 1, 1)
        end
    end

    self.Cats = {}
    self.List = NM.CreateUI("nm_listview", self)
    self.List.Paint = function() end

    -- city67: приоритетные категории всегда сверху списка магазина.
    -- pairs() не даёт стабильного порядка → раньше «Хиты продаж» прыгали
    -- то наверх, то вниз каждое открытие меню.
    local CATEGORY_PRIORITY = {
        "[★] Хиты продаж",
        "Статусы",
        "Донат-персонал",
        "Валюта",
    }
    local rank = {}
    for i, name in ipairs(CATEGORY_PRIORITY) do rank[name] = i end

    local sortedCats = {}
    for catitem in pairs(NM.GetItems()) do table.insert(sortedCats, catitem) end
    table.sort(sortedCats, function(a, b)
        local ra, rb = rank[a] or 9999, rank[b] or 9999
        if ra ~= rb then return ra < rb end
        return a < b
    end)

    for _, catitem in ipairs(sortedCats) do
        self.List:AddSpacer(catitem):SetTall(pX(72))
        local cat = NM.CreateUI("nm_shop_category")
        for k, v in pairs(IGS.GetItems()) do
            v.category = v.category or "Разное"
            if k ~= 0 and v.hidden ~= true and v.category == catitem then
                cat:AddItem(k, self)
            end
        end
        self.List:AddItem(cat)
    end
end

function PANEL:PerformLayout()
    self.List:SetPos(0, 0)
    self.List:SetSize(self:GetWide() - pX(197), self:GetTall())
end

function PANEL:OpenItem(uid)
    if self.ActiveItem == uid then return end
    self.ActiveItem = uid

    if IsValid(self.OpenedItem) then
        self.OpenedItem:Remove()
        self.OpenedItemInfo:Remove()
        self.OpenedItemInfo.Scroll:Remove()
    end

    self.OpenedItem = NM.CreateUI("nm_shop_button", self)
    self.OpenedItem:SetInfo(uid, self)
    self.OpenedItem:SetPos(pX(978) - pX(14) - btnwh, pX(14))
    self.OpenedItem:SetSize(btnwh, btnwh)

    local item = IGS.GetItem(uid)
    self:SetToolTip(item.name)

    self.OpenedItem.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(68, 68, 68))
        draw.RoundedBox(8, 1, 1, w - 2, h - 2, Color(55, 55, 55))
        local name = item.name
        if utf8.len(name) > 16 then name = utf8.sub(name, 0, 14) .. "..." end
        if s.Purchased then
            draw.SimpleText("Куплено: " .. s.Purchased, FONT_ITEM_PURCHASED, w / 2, h - pX(160), Color(255, 255, 255), 1, 1)
        end
        draw.SimpleText(name, FONT_ITEM_NAME, pX(16), h - pX(60), item.highlight or Color(255, 255, 255), 0, 4)
        draw.SimpleText(NM.FancyTerm(item:Term()), FONT_ITEM_SUB, pX(16), h - pX(45), Color(105, 105, 105), 0, 4)
        if item.discounted_from then
            local tw, th = draw.SimpleText(IGS.SignPrice(item.discounted_from), FONT_ITEM_PRICE_OLD, pX(16), h - pX(30), Color(105, 105, 105), 0, 4)
            local liney = h - pX(34)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawLine(pX(16), liney - th * .5, pX(16) + tw, liney)
        end
        draw.SimpleText(IGS.SignPrice(item.price), FONT_ITEM_PRICE, pX(16), h - pX(16), Color(255, 255, 255), 0, 4)
        if item.icon and not item.icon.isModel then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(texture.Get(item.uid) or close_mat)
            local iconwh = pX(80)
            surface.DrawTexturedRect(w / 2 - iconwh / 2, pX(6), iconwh, iconwh)
            surface.SetDrawColor(255, 255, 255, 180)
            surface.SetMaterial(grad_mat)
            surface.DrawTexturedRect(pX(1), pX(12), w - pX(2), iconwh)
        end
    end

    self.OpenedItemInfo = NM.CreateUI("DPanel", self)
    self.OpenedItemInfo:SetText("")
    local oifw, oifh = pX(197), pX(280)
    self.OpenedItemInfo:SetPos(pX(978) - oifw, pX(530) - pX(54) - oifh)
    self.OpenedItemInfo:SetSize(oifw, oifh)

    self.OpenedItemInfo.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 1, w, 1, Color(58, 58, 58))
        draw.SimpleText("Описание", FONT_ITEM_DESC_TITLE, pX(14), pX(14), Color(134, 134, 134))
    end

    self.OpenedItemInfo.Scroll = NM.CreateUI("nm_listview", self)
    self.OpenedItemInfo.Scroll:SetPos(pX(978) - oifw + pX(14), pX(530) - pX(10) - oifh)
    self.OpenedItemInfo.Scroll:SetSize(oifw - pX(28), oifh - pX(60))
    self.OpenedItemInfo.Scroll.Paint = function() end

    local txt = string.Wrap(FONT_ITEM_DESC, item.description, self.OpenedItemInfo.Scroll:GetWide())
    for _, line in ipairs(txt) do
        local lbl = NM.CreateUI("DLabel", function(s)
            s:SetText(line)
            s:SetFont(FONT_ITEM_DESC)
            s:SizeToContents()
        end)
        self.OpenedItemInfo.Scroll:AddItem(lbl)
    end

    if item.swep and LocalPlayer():HasPurchase(item:UID()) then
        self.OpenedItemInfo.CheckBox = NM.CreateUI("DCheckBox", self.OpenedItem)
        self.OpenedItemInfo.CheckBox:Dock(TOP)
        self.OpenedItemInfo.CheckBox:DockMargin(0, 5, 0, 0)
        self.OpenedItemInfo.CheckBox:SetTall(pX(20))
        local should_give = LocalPlayer():GetNWBool("igs.gos." .. item:ID())
        self.OpenedItemInfo.CheckBox:SetValue(should_give)
        self.OpenedItemInfo.CheckBox:SetText("")
        self.OpenedItemInfo.CheckBox.OnChange = function(s, give)
            net.Start("IGS.GiveOnSpawnWep")
            net.WriteIGSItem(item)
            net.WriteBool(give)
            net.SendToServer()
        end
    end
end

local function purchase(ITEM, msg)
    IGS.Purchase(ITEM:UID(), function(errMsg, dbID)
        if errMsg then
            IGS.ShowNotify(errMsg, "Ошибка покупки")
            surface.PlaySound("ambient/voices/citizen_beaten1.wav")
            return
        end
        msg.Purchased = msg.Purchased or 0
        msg.Purchased = msg.Purchased + 1
        if not ITEM:IsStackable() then
            if not IGS.C.Inv_Enabled then
                IGS.ShowNotify("Спасибо за покупку!", "Успешная покупка")
                return
            end
            IGS.BoolRequest("Успешная покупка", "Покупка в вашем /donate инвентаре.\n\nАктивировать сейчас?", function(yes)
                if not yes then return end
                IGS.ProcessActivate(dbID)
            end)
        end
        surface.PlaySound("ambient/office/coinslot1.wav")
    end)
end

function PANEL:BuyItem(uid)
    if self.ActiveItem ~= uid then self:OpenItem(uid) end
    purchase(IGS.GetItem(uid), self.OpenedItem)
end

vgui.Register("nm_shop", PANEL, "Panel")

-- ───────────────────────────────────────────────────────────────────────────
-- VGUI: вкладка профиля
-- ───────────────────────────────────────────────────────────────────────────

PANEL = {}

function PANEL:Init()
    self.Avatar = NM.CreateUI("AvatarImage", function(s)
        local size = pX(76)
        s:SetSize(size, size)
        s:SetPos(pX(844), pX(28))
        s:SetPlayer(LocalPlayer(), size)
    end, self)

    for k, v in pairs(NM.Buttons) do
        NM.CreateUI("DButton", function(s)
            s:SetText("")
            s:SetSize(pX(167), pX(43))
            s:SetPos(pX(796), pX(215) + pX(53 * (v.ID - 1)))
            s.Button = k

            s.DoClick = function(btn)
                if self.ActiveButton == NM.Buttons[btn.Button] then return end
                self:SwitchButton(btn.Button)
            end

            s.Paint = function(btn, w, h)
                if self.ActiveButton == NM.Buttons[btn.Button] then
                    draw.RoundedBox(8, 0, 0, w, h, Color(255, 255, 255))
                    draw.SimpleText(v.Name, FONT_SIDE_BUTTONS, w / 2, h / 2, Color(31, 31, 31), 1, 1)
                else
                    draw.RoundedBox(8, 0, 0, w, h, Color(255, 255, 255))
                    draw.RoundedBox(8, pX(1), pX(1), w - pX(2), h - pX(2), Color(31, 31, 31))
                    draw.SimpleText(v.Name, FONT_SIDE_BUTTONS, w / 2, h / 2, Color(255, 255, 255), 1, 1)
                end
            end
        end, self)
    end

    local tab = next(NM.Buttons)
    self:SwitchButton(tab)
end

local box1, box2 = pX(167), pX(86)

function PANEL:Paint(w, h)
    local box1pos = w - box1 - pX(15)
    draw.RoundedBox(8, box1pos, pX(18), box1, box1, Color(47, 47, 47))
    draw.RoundedBox(8, box1pos + box2 / 2, pX(23), box2, box2, Color(31, 31, 31))
    local lp = LocalPlayer()
    local textx = w - pX(197) / 2
    local texty = pX(18) + box2
    local name = lp:GetName()
    if utf8.len(name) > 18 then name = utf8.sub(name, 1, 14) .. "..." end
    draw.SimpleText(name, FONT_PROFILE_NAME, textx, texty + pX(10), Color(255, 255, 255), 1, 3)
    local linew = pX(86)
    draw.RoundedBox(0, textx - linew / 2, texty + pX(28), linew, 1, Color(58, 58, 58))
    draw.SimpleText(lp:SteamID(), FONT_PROFILE_SID, textx, texty + pX(30), Color(131, 131, 131), 1, 3)
    draw.RoundedBox(0, textx - linew / 2, texty + pX(48), linew, 1, Color(58, 58, 58))
    draw.SimpleText("Задоначено: " .. IGS.SignPrice(IGS.TotalTransaction(lp)), FONT_TOPUPS_SUM, textx, texty + pX(56), Color(255, 255, 255), 1, 3)
end

function PANEL:SwitchButton(tab)
    self.ActiveButton = NM.Buttons[tab]
    self.OpenedButton = NM.OpenButton(tab, self, true)
end

vgui.Register("nm_profile", PANEL, "Panel")

-- ───────────────────────────────────────────────────────────────────────────
-- VGUI: история покупок
-- ───────────────────────────────────────────────────────────────────────────

PANEL = {}

function PANEL:Init()
    self.List = NM.CreateUI("nm_listview", self)
    self.PanelList = NM.CreateUI("DPanel", self)
    self.LastTransactions = {}

    local function drw(txt, x, y)
        draw.SimpleText(txt, FONT_TABLE_COLUMN, x, y, Color(105, 105, 105))
    end

    self.PanelList.Paint = function(s, w, h)
        draw.RoundedBoxEx(8, 0, 0, pX(703), pX(34), Color(31, 31, 31), true, true)
        drw("Сервер", pX(30), pX(10))
        drw("Предмет", pX(185), pX(10))
        drw("Куплен", pX(355), pX(10))
        drw("Истечет", pX(455), pX(10))
        drw("Сумма", pX(555), pX(10))
        drw("Баланс", pX(635), pX(10))
        draw.RoundedBoxEx(8, 0, h - pX(17), pX(703), pX(17), Color(31, 31, 31), false, false, true, true)
    end

    self.PanelList:SetMouseInputEnabled(false)

    self.List.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(31, 31, 31))
    end

    self.List:AddSpacer(""):SetTall(pX(37))

    self.List.scrollBar.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, s.scrollButton.y, 2, s.height, Color(255, 255, 255))
    end

    local mybal = LocalPlayer():IGSFunds()

    IGS.GetMyTransactions(function(dat)
        if not IsValid(self.List) then return end
        for i, v in ipairs(dat) do
            v.note = v.note or "-"
            if i == #dat then
                self.List:AddSpacer(""):SetTall(pX(20))
            end
            if v.note:StartWith("A: ") or v.note:StartWith("C: ") then
                self.LastTransactions[#self.LastTransactions + 1] = v
                continue
            end
            if not v.note:StartWith("P: ") then continue end
            mybal = mybal - v.sum
            local sv_name = IGS.ServerName(v.server)

            -- РАНЬШЕ тут был двойной вызов: name_or_uid возвращал ИМЯ предмета
            -- (например "VIP"), которое потом ПОВТОРНО шло в IGS.GetItemByUID.
            -- Второй вызов искал UID "VIP" (которого не существует) и получал
            -- null-item — поэтому sName выпадал в raw-UID ("vip_perma"), а
            -- termin = 0 → «Истечет: Никогда» вместо реальной даты.
            local uid  = v.note:sub(4) -- срезаем префикс "P: "
            local ITEM = IGS.GetItemByUID(uid)
            local sName = ITEM.isnull and uid or ITEM:Name()
            -- Срок в днях. Для null-item — fallback на 0 → "Никогда".
            local termDays = (not ITEM.isnull and (ITEM.termin or 0)) or 0

            local panel = NM.CreateUI("DPanel")
            panel:SetPos(0, pX(22) * i)
            panel:SetSize(pX(725), pX(20))

            local function drwRow(txt, x, y)
                draw.SimpleText(txt, FONT_TABLE_ROW, x, y, color_white, 1)
            end

            local _sv_name = sv_name
            local _sName = sName
            local _v = v
            local _mybal = mybal
            local _term = termDays

            panel.Paint = function(ps, w, h)
                drwRow(_sv_name, pX(52), 0)
                drwRow(_sName, pX(218), 0)
                drwRow(IGS.TimestampToDate(_v.date) or "Никогда", pX(380), 0)
                drwRow(_term > 0 and IGS.TimestampToDate(_v.date + _term * 86400) or "Никогда", pX(480), 0)
                drwRow(IGS.SignPrice(_v.sum), pX(576), 0)
                drwRow(IGS.SignPrice(_mybal), pX(660), 0)
            end

            self.List:AddItem(panel)
        end
    end)
end

function PANEL:PerformLayout()
    self.List:SetSize(pX(725), pX(244))
    self.List:SetPos(pX(28), pX(63))
    self.PanelList:SetSize(pX(725), pX(244))
    self.PanelList:SetPos(pX(28), pX(63))
end

function PANEL:Paint(w, h)
    draw.SimpleText("Последние покупки", FONT_IGS_CAT, pX(29), pX(36), Color(255, 255, 255), 0, 1)
    draw.RoundedBox(0, 0, h - pX(150), w, 1, Color(58, 58, 58))
    draw.SimpleText("Ваши последние пополнения", FONT_IGS_CAT, pX(29), h - pX(125), Color(255, 255, 255), 0, 1)
    if self.LastTransactions[1] then
        for k = 1, #self.LastTransactions do
            local v = self.LastTransactions[k]
            local x = pX(29) + ((k - 1) * pX(188))
            draw.RoundedBox(8, x, h - pX(100), pX(160), pX(70), Color(31, 31, 31))
            draw.RoundedBox(0, x + pX(28), h - pX(64), pX(100), pX(1), Color(49, 49, 49))
            draw.SimpleText(IGS.TimestampToDate(v.date), FONT_LAST_TOPUP_DATE, x + pX(80), h - pX(80), Color(255, 255, 255), 1, 1)
            draw.SimpleText(IGS.SignPrice(v.sum), FONT_LAST_TOPUP_SUM, x + pX(80), h - pX(48), Color(255, 255, 255), 1, 1)
        end
    else
        draw.SimpleText("Вы ещё не пополняли счёт, или делали это давно!", FONT_IGS_CAT, w / 2, h - pX(70), Color(105, 105, 105), 1, 1)
    end
end

vgui.Register("nm_profile_purchases", PANEL, "Panel")

-- ───────────────────────────────────────────────────────────────────────────
-- VGUI: пополнение баланса
-- ───────────────────────────────────────────────────────────────────────────

PANEL = {}

local function niceSum(i, iFallback)
    return math.Truncate(tonumber(i) or iFallback, 2)
end

function PANEL:Init()
    self.Purchase = NM.CreateUI("DButton", function(s)
        s:SetText("")
        s.Text = "Пополнить баланс на ? ₽"
        s:SetDisabled(true)
        s:SetSize(pX(277), pX(43))
        s:SetPos(pX(29), pX(236))

        s.DoClick = function()
            local want_money = niceSum(self.EntrySum:GetValue())
            if not want_money then
                self.LogPanel:AddRecord("Указана некорректная сумма", false)
                return
            elseif want_money < IGS.GetMinCharge() then
                self.LogPanel:AddRecord("Минимальная сумма: " .. PL_MONEY(IGS.GetMinCharge()), false)
                return
            end
            self.LogPanel:AddRecord("Запрос цифровой подписи...")
            IGS.GetPaymentURL(want_money, function(url)
                IGS.OpenURL(url, "Пополнение счёта")
                if not IsValid(self) then return end
                self.LogPanel:AddRecord("Подпись получена, начинаем оплату")
                timer.Simple(.7, function()
                    self.LogPanel:AddRecord("Счёт пополнится моментально или после перезахода")
                end)
            end)
        end

        s.Paint = function(btn, w, h)
            draw.RoundedBox(4, 0, 0, w, h, btn:GetDisabled() and Color(105, 105, 105) or Color(255, 255, 255))
            draw.SimpleText(btn.Text, FONT_TOPUP_BUTTON, w / 2, h / 2, Color(0, 0, 0), 1, 1)
        end
    end, self)

    NM.CreateUI("DButton", function(s)
        s:SetText("")
        s:SetSize(pX(43), pX(43))
        s:SetPos(pX(318), pX(236))
        s.DoClick = function() IGS.WIN.ActivateCoupon() end
        local matsize = pX(22)
        s.Paint = function(btn, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255))
            draw.RoundedBox(4, pX(1), pX(1), w - pX(2), h - pX(2), Color(47, 47, 47))
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(coupon_mat)
            surface.DrawTexturedRect(w / 2 - matsize / 2, h / 2 - matsize / 2, matsize, matsize)
        end
    end, self)

    self.EntrySum = NM.CreateUI("DTextEntry", function(s)
        s:SetSize(pX(332), pX(43))
        s:SetPos(pX(29), pX(185))
        s:SetNumeric(true)
        s.Paint = function(entry, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255))
            draw.RoundedBox(4, pX(1), pX(1), w - pX(2), h - pX(2), Color(47, 47, 47))
            local val = entry:GetValue()
            draw.SimpleText(
                val == "" and "Сумма доната (₽)" or val,
                FONT_TOPUP_AMOUNT, pX(20), h / 2,
                val == "" and Color(140, 140, 140) or Color(255, 255, 255), 0, 1
            )
        end
        s.Think = function(entry)
            local rub = tonumber(entry:GetValue())
            self.Purchase.Text = "Пополнить баланс на " .. (rub and PL_MONEY(rub) or "?") .. " ₽"
            self.Purchase:SetDisabled(not rub)
        end
    end, self)

    self.LogPanel = NM.CreateUI("nm_listview", function(log)
        log:SetSize(pX(330), pX(138))
        log:SetPos(pX(419), pX(170))
        log.Paint = function() end

        function log:AddRecord(text, pay)
            local col = (pay == true and IGS.col.LOG_SUCCESS) or (pay == false and IGS.col.LOG_ERROR) or IGS.col.LOG_NORMAL
            text = "> " .. os.date("%H:%M:%S") .. "\n" .. text
            local y = pX(2)
            for i, line in ipairs(string.Wrap(FONT_LOG_TEXT, text, log:GetWide())) do
                log:AddItem(NM.CreateUI("DLabel", function(l)
                    l:SetPos(0, y)
                    l:SetText(line)
                    l:SetFont(FONT_LOG_TEXT)
                    l:SizeToContents()
                    l:SetTextColor(i == 1 and IGS.col.HIGHLIGHTING or col)
                    y = y + l:GetTall()
                end, log))
            end
            log:ScrollTo(log:GetCanvas():GetTall())
        end
    end, self)

    local function log(delay, text, status)
        timer.Simple(delay, function()
            if not IsValid(self.LogPanel) then return end
            self.LogPanel:AddRecord(text, status)
        end)
    end

    log(0, "Открыт диалог пополнения счёта", nil)
    log(math.random(3), "Соединение установлено!", true)
    log(math.random(20, 40), "Деньги зачислятся мгновенно и автоматически", nil)
    self.LastTransactions = {}

    IGS.GetMyTransactions(function(dat)
        for _, v in ipairs(dat) do
            v.note = v.note or "-"
            if v.note:StartWith("A: ") or v.note:StartWith("C: ") then
                self.LastTransactions[#self.LastTransactions + 1] = v
            end
        end
    end)
end

function PANEL:Paint(w, h)
    draw.RoundedBox(8, pX(29), pX(13), w - pX(58), pX(80), Color(31, 31, 31))
    local heartsize = pX(27)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(heart_mat)
    surface.DrawTexturedRect(pX(36), pX(24), heartsize, heartsize)
    local txt = string.Wrap(FONT_THANKS, "На эти средства мы оплатим работу разработчиков и рекламу для развития проекта", w - pX(58) - pX(40))
    for k, v in ipairs(txt) do
        draw.SimpleText(v, FONT_THANKS, pX(66), pX(25) + pX(25 * (k - 1)), Color(255, 255, 255))
    end
    draw.SimpleText("Пополнение баланса", FONT_IGS_CAT, pX(29), pX(145), Color(255, 255, 255), 0, 1)
    draw.RoundedBox(0, w / 2, h / 2 - pX(90), 1, pX(160), Color(58, 58, 58))
    draw.SimpleText("Лог операций", FONT_IGS_CAT, pX(419), pX(145), Color(255, 255, 255), 0, 1)
    draw.RoundedBox(0, 0, h - pX(150), w, 1, Color(58, 58, 58))
    draw.SimpleText("Ваши последние пополнения", FONT_IGS_CAT, pX(29), h - pX(125), Color(255, 255, 255), 0, 1)
    if self.LastTransactions[1] then
        for k = 1, #self.LastTransactions do
            local v = self.LastTransactions[k]
            local x = pX(29) + ((k - 1) * pX(188))
            draw.RoundedBox(8, x, h - pX(100), pX(160), pX(70), Color(31, 31, 31))
            draw.RoundedBox(0, x + pX(28), h - pX(64), pX(100), pX(1), Color(49, 49, 49))
            draw.SimpleText(IGS.TimestampToDate(v.date, true), FONT_LAST_TOPUP_DATE, x + pX(80), h - pX(80), Color(255, 255, 255), 1, 1)
            draw.SimpleText(IGS.SignPrice(v.sum), FONT_LAST_TOPUP_SUM, x + pX(80), h - pX(48), Color(255, 255, 255), 1, 1)
        end
    else
        draw.SimpleText("Вы ещё не пополняли счёт, или делали это давно!", FONT_IGS_CAT, w / 2, h - pX(70), Color(105, 105, 105), 1, 1)
    end
end

vgui.Register("nm_profile_donate", PANEL, "Panel")

-- ───────────────────────────────────────────────────────────────────────────
-- VGUI: карточка инвентаря
-- ───────────────────────────────────────────────────────────────────────────

PANEL = {}

function PANEL:Init()
    self:SetText("")
    self.ModelIcon = NM.CreateUI("DModelPanel", self)
    self.ActivationButton = NM.CreateUI("DButton", self)
    self.DropButton = NM.CreateUI("DButton", self)

    local function clearframe()
        local frame = self.MainFrame
        if IsValid(frame.OpenedItem) then
            frame.OpenedItem:Remove()
            frame.OpenedItemInfo:Remove()
            frame.OpenedItemInfo.Scroll:Remove()
        end
    end

    self.ActivationButton.DoClick = function()
        clearframe()
        IGS.ProcessActivate(self.ItemInv.id, function(ok)
            if not ok then return end
            self:Remove()
        end)
    end

    self.DropButton.DoClick = function()
        clearframe()
        IGS.DropItem(self.ItemInv.id, function() self:Remove() end)
    end
end

function PANEL:PerformLayout()
    self.ActivationButton:SetPos(pX(600), pX(15))
    self.ActivationButton:SetSize(pX(140), pX(40))
    self.ActivationButton:SetText("")
    self.ActivationButton.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, self.MainFrame.ActiveItem == self.Item and Color(223, 223, 223) or Color(68, 68, 68))
        draw.RoundedBox(8, 1, 1, w - 2, h - 2, Color(55, 55, 55))
        draw.SimpleText("Активировать", FONT_INVENTORY_ACTIVATE, w / 2, h / 2, color_white, 1, 1)
    end
    self.DropButton:SetPos(pX(600), pX(60))
    self.DropButton:SetSize(pX(140), pX(20))
    self.DropButton:SetText("")
    self.DropButton.Paint = function(s, w, h)
        draw.SimpleText("Бросить на пол", FONT_INVENTORY_DROP, w / 2, h / 2, Color(105, 105, 105), 1, 1)
    end
    local iconwh = pX(70)
    self.ModelIcon:SetPos(pX(20), self:GetTall() / 2 - iconwh / 2)
    self.ModelIcon:SetSize(iconwh, iconwh)
end

function PANEL:Paint(w, h)
    draw.RoundedBox(8, pX(5), pX(5), w - pX(10), h - pX(10), Color(68, 68, 68))
    draw.RoundedBox(8, 1 + pX(5), 1 + pX(5), w - pX(10) - 2, h - pX(10) - 2, Color(55, 55, 55))
    draw.RoundedBox(8, pX(15), h / 2 - pX(40), pX(80), pX(80), Color(47, 47, 47))
    local item = IGS.GetItem(self.Item)
    draw.SimpleText(item.name, FONT_INVENTORY_NAME, pX(110), pX(50), item.highlight or Color(255, 255, 255), 0, 4)
    draw.SimpleText("Действует " .. IGS.TermToStr(item:Term()), FONT_INVENTORY_TERM, pX(110), pX(70), Color(105, 105, 105), 0, 4)
    if item.icon and not item.icon.isModel then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(texture.Get(item.uid) or close_mat)
        local iconwh = pX(70)
        surface.DrawTexturedRect(pX(20), h / 2 - iconwh / 2, iconwh, iconwh)
    end
end

function PANEL:SetInfo(inv, uid, frame)
    self.Item = uid
    self.ItemInv = inv
    self.MainFrame = frame
    self.DoClick = function() frame:OpenItem(uid) end
    local item = IGS.GetItem(self.Item)
    self.ModelIcon.DoClick = function() frame:OpenItem(uid) end
    if item.icon and not item.icon.isModel then
        texture.Create(item.uid):Download(item.icon.icon)
        self.ModelIcon:SetVisible(false)
    elseif item.icon and item.icon.isModel then
        self.ModelIcon:SetVisible(true)
        self.ModelIcon:SetModel(item.icon.icon)
        local mn, mx = self.ModelIcon.Entity:GetRenderBounds()
        local size = 0
        size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
        size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
        size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
        self.ModelIcon:SetFOV(30)
        self.ModelIcon:SetCamPos(Vector(size, size, size))
        self.ModelIcon:SetLookAt((mn + mx) * 0.5)
    end
end

vgui.Register("nm_inventory_button", PANEL, "DButton")

-- ───────────────────────────────────────────────────────────────────────────
-- VGUI: вкладка инвентаря
-- ───────────────────────────────────────────────────────────────────────────

PANEL = {}

function PANEL:Init()
    self.Paint = function()
        if not IsValid(self.OpenedItem) then
            draw.SimpleText("Выберите предмет!", FONT_CHOOSE_ITEM, pX(877), pX(20), color_white, 1, 1)
        end
    end

    self.Cats = {}
    self.List = NM.CreateUI("nm_listview", self)
    self.List.Paint = function(s, w, h)
        if not IsValid(self.List:GetCanvas():GetChild(0)) then
            draw.SimpleText("Инвентарь пуст!", FONT_INVENTORY_NONE, w / 2, h / 2, Color(105, 105, 105), 1, 1)
        end
    end

    IGS.GetInventory(function(items)
        for _, v in pairs(items) do
            local btn = NM.CreateUI("nm_inventory_button")
            btn:SetSize(0, pX(100))
            btn:SetInfo(v, v.item.uid, self)
            self.List:AddItem(btn)
        end
    end)
end

function PANEL:PerformLayout()
    self.List:SetPos(0, 0)
    self.List:SetSize(self:GetWide() - pX(197), self:GetTall())
end

function PANEL:OpenItem(uid)
    if self.ActiveItem == uid then return end
    self.ActiveItem = uid

    if IsValid(self.OpenedItem) then
        self.OpenedItem:Remove()
        self.OpenedItemInfo:Remove()
        self.OpenedItemInfo.Scroll:Remove()
    end

    self.OpenedItem = NM.CreateUI("nm_shop_button", self)
    self.OpenedItem:SetInfo(uid, self)
    self.OpenedItem:SetPos(pX(978) - pX(14) - btnwh, pX(14))
    self.OpenedItem:SetSize(btnwh, btnwh)
    self.OpenedItem.ButtonBuy:SetVisible(false)

    local item = IGS.GetItem(uid)
    self:SetToolTip(item.name)

    self.OpenedItem.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(68, 68, 68))
        draw.RoundedBox(8, 1, 1, w - 2, h - 2, Color(55, 55, 55))
        local name = item.name
        if utf8.len(name) > 16 then name = utf8.sub(name, 0, 14) .. "..." end
        draw.SimpleText(name, FONT_ITEM_NAME, pX(16), h - pX(60), item.highlight or Color(255, 255, 255), 0, 4)
        draw.SimpleText(NM.FancyTerm(item:Term()), FONT_ITEM_SUB, pX(16), h - pX(45), Color(105, 105, 105), 0, 4)
        if item.discounted_from then
            local tw, th = draw.SimpleText(IGS.SignPrice(item.discounted_from), FONT_ITEM_PRICE_OLD, pX(16), h - pX(30), Color(105, 105, 105), 0, 4)
            local liney = h - pX(34)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawLine(pX(16), liney - th * .5, pX(16) + tw, liney)
        end
        draw.SimpleText(IGS.SignPrice(item.price), FONT_ITEM_PRICE, pX(16), h - pX(16), Color(255, 255, 255), 0, 4)
        if item.icon and not item.icon.isModel then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(texture.Get(item.uid) or close_mat)
            local iconwh = pX(80)
            surface.DrawTexturedRect(w / 2 - iconwh / 2, pX(6), iconwh, iconwh)
            surface.SetDrawColor(255, 255, 255, 180)
            surface.SetMaterial(grad_mat)
            surface.DrawTexturedRect(pX(1), pX(12), w - pX(2), iconwh)
        end
    end

    self.OpenedItemInfo = NM.CreateUI("DPanel", self)
    self.OpenedItemInfo:SetText("")
    local oifw, oifh = pX(197), pX(280)
    self.OpenedItemInfo:SetPos(pX(978) - oifw, pX(530) - pX(54) - oifh)
    self.OpenedItemInfo:SetSize(oifw, oifh)

    self.OpenedItemInfo.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 1, w, 1, Color(58, 58, 58))
        draw.SimpleText("Описание", FONT_ITEM_DESC_TITLE, pX(14), pX(14), Color(134, 134, 134))
    end

    self.OpenedItemInfo.Scroll = NM.CreateUI("nm_listview", self)
    self.OpenedItemInfo.Scroll:SetPos(pX(978) - oifw + pX(14), pX(530) - pX(10) - oifh)
    self.OpenedItemInfo.Scroll:SetSize(oifw - pX(28), oifh - pX(60))
    self.OpenedItemInfo.Scroll.Paint = function() end

    local txt = string.Wrap(FONT_ITEM_DESC, item.description, self.OpenedItemInfo.Scroll:GetWide())
    for _, line in ipairs(txt) do
        local lbl = NM.CreateUI("DLabel", function(s)
            s:SetText(line)
            s:SetFont(FONT_ITEM_DESC)
            s:SizeToContents()
        end)
        self.OpenedItemInfo.Scroll:AddItem(lbl)
    end
end

vgui.Register("nm_inventory", PANEL, "Panel")

-- ───────────────────────────────────────────────────────────────────────────
-- Консольные команды
-- ───────────────────────────────────────────────────────────────────────────

concommand.Add("donate_menu", function()
    NM.Menu()
end)

concommand.Add("donate_menu_old", function()
    -- Открывает оригинальный интерфейс IGS (резервный)
    if IGS._OriginalUI then IGS._OriginalUI() end
end)

-- Перенаправляем стандартный IGS.UI на наш редизайн.
-- Это гарантирует, что MENUBUTTON (F2) и COMMANDS IGS открывают именно NM.Menu()
IGS._OriginalUI = IGS.UI
IGS.UI = NM.Menu
