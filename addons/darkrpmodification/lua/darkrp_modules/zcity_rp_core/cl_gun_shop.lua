-- [ZCITY_PORT] Файл автоматически мигрирован из gamemodes/zcity/.../modes/roleplay/cl_gun_shop.lua
-- Источник: _backup_20260522_182916/zcity/gamemode/modes/roleplay/
-- Все обращения к CurrentRound()/MODE/round заменены на ZCity_RP.
-- ZCity_RP — это таблица-обёртка, имитирующая старый MODE-namespace,
--           содержит Jobs, AddMoney, TakeMoney, GetMoney, CityTaxRate и т.д.
-- Реализация в darkrp_modules/zcity_rp_core/sh_zcity_rp_namespace.lua

-- Клиентское меню магазина оружия (zb_gun_shop)
-- Открывается по E на энтити, доступно всем игрокам в RP режиме

local BlurBackground = BlurBackground or hg.DrawBlur

-- Возвращает цену с учётом текущего налога
local function GetTaxedPrice(basePrice)
    local taxRate = GetGlobalInt("CityTaxRate", 0)
    return basePrice + math.floor(basePrice * (taxRate / 100))
end

-- Переменная для открытого меню
local GunShopMenu = nil

local function OpenGunShopMenu(shopEnt)
    if IsValid(GunShopMenu) then
        GunShopMenu:Remove()
        GunShopMenu = nil
        return
    end

    -- Берём список товаров из TDM режима
    local tdmMode = zb.modes and zb.modes["tdm"]
    if not tdmMode or not tdmMode.BuyItems then
        chat.AddText(Color(255, 100, 100), "[Roleplay] ", Color(255, 255, 255), "Список товаров недоступен")
        return
    end
    local BuyItems = tdmMode.BuyItems

    GunShopMenu = vgui.Create("ZFrame")
    local Frame = GunShopMenu
    Frame:SetSize(ScrW() * 0.35, ScrH() * 0.85)
    Frame:Center()
    Frame:MakePopup()
    Frame:SetTitle("Магазин оружия")
    Frame.Paint = function(self, w, h)
        BlurBackground(self)
        surface.SetDrawColor(255, 0, 0, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
    end

    -- Закрываем если отошли от магазина
    Frame.Think = function(self)
        if not IsValid(shopEnt) then self:Remove() return end
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then self:Remove() return end
        if ply:GetPos():Distance(shopEnt:GetPos()) > 250 then self:Remove() end
    end

    local function PaintPanel(self, w, h)
        surface.SetDrawColor(0, 0, 0, 155)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(255, 0, 0, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
    end

    local gradient_l = Material("vgui/gradient-l")
    local function PaintPanel1(self, w, h)
        surface.SetDrawColor(0, 0, 0, 155)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(255, 0, 0, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
        draw.RoundedBox(0, 2.5, 2.5, w - 5, h - 5, Color(0, 0, 0, 140))
        surface.SetDrawColor(155, 0, 0, 55)
        surface.SetMaterial(gradient_l)
        surface.DrawTexturedRect(0, 0, w / 1.5, h)
    end

    local function PaintPanel2(self, w, h)
        surface.SetDrawColor(55, 155, 55, 25)
        surface.SetMaterial(gradient_l)
        surface.DrawTexturedRect(0, 0, w * 1.2, h)
    end

    local rtabFunc = function(self)
        local ExtraInset = 10
        if self.Image then ExtraInset = ExtraInset + self.Image:GetWide() end
        self:SetTextInset(ExtraInset, 2)
        local w, h = self:GetContentSize()
        h = self:GetTabHeight()
        self:SetSize(w + 10, h + 7)
        DLabel.ApplySchemeSettings(self)
    end

    local Sheet = vgui.Create("DPropertySheet", Frame)
    Sheet:Dock(FILL)
    Sheet:SetTextInset(50)
    Sheet.Paint = function() end
    Sheet.tabScroller:SetOverlap(0)
    Sheet.tabScroller:DockMargin(8, 0, 8, 0)
    Sheet:SetFadeTime(0.1)

    for k, category in SortedPairsByMemberValue(BuyItems, "Priority") do
        local CategoryPanel = vgui.Create("DScrollPanel", Sheet)
        CategoryPanel.Paint = function() end

        for n, Item in pairs(category) do
            if n == "Priority" then continue end

            local weapon = weapons.GetStored(Item.ItemClass)
            local ent    = scripted_ents.GetStored(Item.ItemClass)

            local ItemPanel = vgui.Create("DPanel", CategoryPanel)
            ItemPanel:SetSize(0, ScrH() * 0.1)
            ItemPanel:Dock(TOP)
            ItemPanel:DockMargin(0, 8, 0, 0)
            ItemPanel.Paint = PaintPanel1

            if (weapon ~= nil and ((weapon.WepSelectIcon2 and weapon.WepSelectIcon2:GetName()) or weapon.IconOverride)) or (ent and ent.t.IconOverride) then
                local ItemButton = vgui.Create("DImage", ItemPanel)
                local bBox = (ent and ent.t.IconOverride) or (weapon ~= nil and weapon.WepSelectIcon2box)
                ItemButton:SetSize(ScrH() * ((bBox and 0.1) or 0.17), ScrH() * 0.1)
                ItemButton:Dock(LEFT)
                local boxed = ScrH() * 0.07 / 2
                ItemButton:DockMargin(5 + (bBox and boxed or 0), 5, 5 + (bBox and boxed or 0), 5)
                ItemButton:SetImage((weapon ~= nil and ((weapon.WepSelectIcon2 and weapon.WepSelectIcon2:GetName() .. ".png") or weapon.IconOverride)) or (ent and ent.t.IconOverride) or "none")
            end

            local ItemButton = vgui.Create("DPanel", ItemPanel)
            ItemButton:Dock(FILL)
            ItemButton:DockMargin(0, 5, 0, 0)
            ItemButton.Paint = function() end

            local lbl = vgui.Create("DLabel", ItemButton)
            lbl:SetText(n)
            lbl:DockMargin(10, 0, 5, 0)
            lbl:Dock(TOP)
            lbl:SetFont("ZB_TDM_MENU")
            lbl:SetSize(ScrW() * 0.5, ScrH() * 0.04)

            local lbl = vgui.Create("DLabel", ItemButton)
            lbl:SetText("Price: $" .. GetTaxedPrice(Item.Price))
            lbl:DockMargin(10, 0, 5, 0)
            lbl:Dock(TOP)
            lbl:SetTextColor(Color(155, 200, 155))
            lbl:SetFont("ZB_TDM_DESC")
            lbl:SetSize(ScrW() * 0.5, ScrH() * 0.02)
            -- Обновляем цену при изменении налога
            function lbl:Think()
                self:SetText("Price: $" .. GetTaxedPrice(Item.Price))
            end

            local BuyBtn = vgui.Create("DButton", ItemButton)
            BuyBtn:DockMargin(10, 5, 10, 10)
            BuyBtn:Dock(LEFT)
            BuyBtn:SetText("Buy")
            BuyBtn:SetTextColor(Color(200, 200, 200))
            BuyBtn:SetFont("ZB_TDM_DESC")
            BuyBtn:SetHeight(ScrH() * 0.025)
            BuyBtn.Paint = PaintPanel
            BuyBtn.Item = {k, n}

            function BuyBtn:DoClick()
                net.Start("zb_gun_shop_buy")
                net.WriteEntity(shopEnt)
                net.WriteTable(self.Item)
                net.SendToServer()
            end

            if weapon then
                local ammo = weapon.Primary.Ammo ~= "none" and weapon.Primary.Ammo
                    or weapon.Ammo
                    or (weapons.GetStored(weapon.Base) and weapons.GetStored(weapon.Base).Primary.Ammo)
                if hg.ammotypeshuy[ammo] then
                    local amm = vgui.Create("DButton", ItemButton)
                    amm:DockMargin(10, 5, 10, 10)
                    amm:Dock(LEFT)
                    amm:SetText(ammo)
                    amm:SetTextColor(Color(200, 200, 200))
                    amm:SetFont("ZB_TDM_DESCSMALL")
                    surface.SetFont("ZB_TDM_DESCSMALL")
                    local w, h = surface.GetTextSize(ammo)
                    amm:SetHeight(ScrH() * 0.025)
                    amm:SetWidth(w + 7)
                    local ammo2 = "ent_ammo_" .. hg.ammotypeshuy[ammo].name
                    local name
                    for name2, ammoItem in pairs(BuyItems["Ammo"] or {}) do
                        if not istable(ammoItem) then continue end
                        if ammoItem.ItemClass == ammo2 then name = name2 end
                    end
                    amm.huy = {"Ammo", name}
                    function amm:DoClick()
                        net.Start("zb_gun_shop_buy")
                        net.WriteEntity(shopEnt)
                        net.WriteTable(amm.huy)
                        net.SendToServer()
                    end
                    amm.Paint = PaintPanel
                end
            end

            if Item.Attachments and #Item.Attachments > 0 then
                local ItemAtt = vgui.Create("DGrid", ItemPanel)
                local ItemIcon = math.ceil(ScrH() * 0.06)
                ItemAtt:Dock(RIGHT)
                ItemAtt:DockMargin(0, 5, 0, 0)
                ItemAtt:SetCols(4)
                ItemAtt:SetColWide(ItemIcon)
                ItemAtt:SetRowHeight(ItemIcon)
                ItemAtt.Paint = function() end
                for id, AttachN in pairs(Item.Attachments) do
                    local ico = hg.attachmentsIcons[AttachN]
                    local Attach = vgui.Create("DImageButton")
                    Attach:SetImage(ico)
                    Attach:SetSize(ItemIcon - 5, ItemIcon - 5)
                    Attach.Attachment = {k, n, AttachN}
                    function Attach:DoClick()
                        net.Start("zb_gun_shop_buy")
                        net.WriteEntity(shopEnt)
                        net.WriteTable(self.Attachment)
                        net.SendToServer()
                    end
                    Attach.Paint = PaintPanel2
                    ItemAtt:AddItem(Attach)
                end
            end
        end

        local tab = Sheet:AddSheet(k, CategoryPanel)
        local rTab = tab["Tab"]
        rTab.Paint = PaintPanel
        rTab:SetFont("ZB_TDM_CATEGORY")
        rTab.ApplySchemeSettings = rtabFunc
    end

    -- Баланс RP
    local lbl = vgui.Create("DLabel", Frame)
    lbl:SetText("Cash: $" .. GetRoleplayMoney())
    lbl:DockMargin(10, 5, 10, 5)
    lbl:Dock(BOTTOM)
    lbl:SetTextColor(Color(61, 173, 61))
    lbl:SetFont("ZB_TDM_DESC")
    lbl:SetSize(0, ScrH() * 0.02)
    function lbl:Think()
        self:SetText("Cash: $" .. GetRoleplayMoney())
    end
end

-- Получаем сигнал от сервера (из ENT:Use)
net.Receive("zb_gun_shop_open", function()
    local shopEnt = net.ReadEntity()
    if not IsValid(shopEnt) then return end

    local round = ZCity_RP -- [ZCITY_PORT]

    OpenGunShopMenu(shopEnt)
end)
