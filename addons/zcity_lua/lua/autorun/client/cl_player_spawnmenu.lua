--[[ СПАВН МЕНЮ ДЛЯ ИГРОКОВ - ОТКЛЮЧЕНО

-- Кастомное ограниченное спавн-меню для обычных игроков в roleplay

local propCategories = {
    {
        name = "Строительство",
        icon = "icon16/brick.png",
        props = {
            "models/hunter/plates/plate.mdl",
            "models/hunter/plates/plate1x1.mdl",
            "models/hunter/plates/plate1x2.mdl",
            "models/hunter/plates/plate2x2.mdl",
            "models/hunter/plates/plate2x4.mdl",
            "models/hunter/plates/plate4x4.mdl",
            "models/hunter/blocks/cube025x025x025.mdl",
            "models/hunter/blocks/cube05x05x05.mdl",
            "models/hunter/blocks/cube1x1x1.mdl",
            "models/hunter/blocks/cube2x2x2.mdl",
            "models/hunter/misc/cylinder1x1.mdl",
            "models/hunter/misc/cone1x1.mdl",
            "models/hunter/misc/sphere1x1.mdl",
        }
    },
    {
        name = "Мебель",
        icon = "icon16/house.png",
        props = {
            "models/props_c17/FurnitureCouch001a.mdl",
            "models/props_c17/FurnitureTable001a.mdl",
            "models/props_c17/FurnitureChair001a.mdl",
            "models/props_c17/FurnitureDresser001a.mdl",
            "models/props_c17/FurnitureBed001a.mdl",
            "models/props_c17/FurnitureBookcase001a.mdl",
        }
    },
    {
        name = "Техника",
        icon = "icon16/monitor.png",
        props = {
            "models/props_c17/FurnitureFridge001a.mdl",
            "models/props_c17/FurnitureStove001a.mdl",
            "models/props_c17/FurnitureMicrowave001a.mdl",
            "models/props_c17/FurnitureTV001a.mdl",
            "models/props_c17/tv_monitor01.mdl",
            "models/props_c17/computer01_keyboard.mdl",
        }
    },
    {
        name = "Ванная",
        icon = "icon16/cup.png",
        props = {
            "models/props_c17/FurnitureBathtub001a.mdl",
            "models/props_c17/FurnitureToilet001a.mdl",
            "models/props_c17/FurnitureSink001a.mdl",
        }
    },
    {
        name = "Освещение",
        icon = "icon16/lightbulb.png",
        props = {
            "models/props_c17/FurnitureLamp001a.mdl",
            "models/props_c17/FurnitureLamp002a.mdl",
        }
    },
    {
        name = "Контейнеры",
        icon = "icon16/box.png",
        props = {
            "models/props_junk/wood_crate001a.mdl",
            "models/props_junk/wood_crate002a.mdl",
            "models/props_c17/lockers001a.mdl",
            "models/props_junk/garbage_bag001a.mdl",
        }
    },
}

local toolList = {
    { name = "Material",    tool = "material",  desc = "Изменить материал пропа" },
    { name = "Color",       tool = "color",     desc = "Изменить цвет пропа" },
    { name = "Light",       tool = "light",     desc = "Источник света" },
    { name = "Keypad",      tool = "keypad",    desc = "Кейпад" },
    { name = "3D2D Text",   tool = "2dtext",    desc = "2D текст в 3D пространстве" },
    { name = "Weld",        tool = "weld",      desc = "Сварить пропы" },
    { name = "Rope",        tool = "rope",      desc = "Верёвка" },
    { name = "No Collide",  tool = "nocollide", desc = "Убрать коллизию" },
    { name = "Remover",     tool = "remover",   desc = "Удалить проп" },
}

local menuOpen = false
local menuPanel = nil

local function OpenRestrictedSpawnMenu()
    if IsValid(menuPanel) then
        menuPanel:Remove()
        menuPanel = nil
        menuOpen = false
        return
    end

    menuOpen = true

    local scrW, scrH = ScrW(), ScrH()
    local W, H = 600, scrH * 0.8

    menuPanel = vgui.Create("DFrame")
    menuPanel:SetSize(W, H)
    menuPanel:SetPos(scrW * 0.5 - W * 0.5, scrH * 0.5 - H * 0.5)
    menuPanel:SetTitle("")
    menuPanel:SetDraggable(true)
    menuPanel:ShowCloseButton(false)
    menuPanel:MakePopup()

    menuPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 20, 28, 250))
        surface.SetDrawColor(80, 20, 20, 200)
        surface.DrawRect(0, 0, w, 4)
        draw.SimpleText("Строительное меню", "DermaLarge", w / 2, 20, Color(220, 220, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    menuPanel.OnRemove = function()
        menuOpen = false
        menuPanel = nil
    end

    -- Кнопка закрытия
    local closeBtn = vgui.Create("DButton", menuPanel)
    closeBtn:SetPos(W - 40, 8)
    closeBtn:SetSize(30, 30)
    closeBtn:SetText("X")
    closeBtn:SetTextColor(color_white)
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(200, 50, 50) or Color(80, 20, 20))
    end
    closeBtn.DoClick = function()
        menuPanel:Remove()
    end

    -- Вкладки
    local tabs = vgui.Create("DPropertySheet", menuPanel)
    tabs:SetPos(5, 40)
    tabs:SetSize(W - 10, H - 50)
    tabs.Paint = function() end

    -- Вкладка пропов
    local propPanel = vgui.Create("DPanel")
    propPanel.Paint = nil

    -- Левая панель категорий
    local catPanel = vgui.Create("DPanel", propPanel)
    catPanel:Dock(LEFT)
    catPanel:SetWide(150)
    catPanel:DockMargin(0, 0, 4, 0)
    catPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(15, 15, 22, 200))
    end

    local catScroll = vgui.Create("DScrollPanel", catPanel)
    catScroll:Dock(FILL)
    local csbar = catScroll:GetVBar()
    csbar:SetHideButtons(true)
    csbar.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 40)) end
    csbar.btnGrip.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(80, 20, 20)) end

    -- Правая панель пропов
    local propRight = vgui.Create("DPanel", propPanel)
    propRight:Dock(FILL)
    propRight.Paint = nil

    local activeCat = nil
    local propScroll = nil

    local function ShowCategory(cat)
        if IsValid(propScroll) then propScroll:Remove() end

        propScroll = vgui.Create("DScrollPanel", propRight)
        propScroll:Dock(FILL)

        local sbar = propScroll:GetVBar()
        sbar:SetHideButtons(true)
        sbar.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 40)) end
        sbar.btnGrip.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(80, 20, 20)) end

        local iconSize = 80
        local layout = vgui.Create("DTileLayout", propScroll)
        layout:Dock(FILL)
        layout:SetBaseSize(iconSize)
        layout:SetBorder(4)
        layout:SetSpaceX(4)
        layout:SetSpaceY(4)

        for _, mdl in ipairs(cat.props) do
            local icon = vgui.Create("SpawnIcon", layout)
            icon:SetSize(iconSize, iconSize)
            icon:SetModel(mdl)
            icon:SetTooltip(mdl)
            icon.DoClick = function()
                net.Start("zb_player_spawn_prop")
                net.WriteString(mdl)
                net.SendToServer()
            end
        end
    end

    for i, cat in ipairs(propCategories) do
        local btn = vgui.Create("DButton", catScroll)
        btn:SetText(cat.name)
        btn:SetTextColor(color_white)
        btn:Dock(TOP)
        btn:DockMargin(2, 2, 2, 0)
        btn:SetTall(35)
        local thisCat = cat
        btn.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, (activeCat == thisCat) and Color(80, 20, 20) or (self:IsHovered() and Color(50, 15, 15) or Color(30, 30, 42)))
        end
        btn.DoClick = function()
            activeCat = thisCat
            ShowCategory(thisCat)
        end

        if i == 1 then
            activeCat = cat
            timer.Simple(0, function() if IsValid(propRight) then ShowCategory(cat) end end)
        end
    end

    tabs:AddSheet("Пропы", propPanel, "icon16/brick.png")

    -- Вкладка инструментов
    local toolPanel = vgui.Create("DScrollPanel")
    toolPanel:SetSize(W - 10, H - 80)

    local sbar2 = toolPanel:GetVBar()
    sbar2:SetHideButtons(true)
    sbar2.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 40)) end
    sbar2.btnGrip.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(80, 20, 20)) end

    for _, t in ipairs(toolList) do
        local btn = vgui.Create("DButton", toolPanel)
        btn:SetText("")
        btn:Dock(TOP)
        btn:DockMargin(5, 5, 5, 0)
        btn:SetTall(50)
        btn.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and Color(80, 20, 20) or Color(30, 30, 42))
            draw.SimpleText(t.name, "DermaLarge", 15, h / 2 - 8, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(t.desc, "DermaDefault", 15, h / 2 + 8, Color(160, 160, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            RunConsoleCommand("gmod_tool", t.tool)
            menuPanel:Remove()
        end
    end

    tabs:AddSheet("Инструменты", toolPanel, "icon16/wrench.png")
end

-- Открываем по F1 только в roleplay
local f1WasDown = false
hook.Add("Think", "RestrictedSpawnMenuThink", function()
    if not CurrentRound or not CurrentRound() then return end
    if CurrentRound().name ~= "roleplay" then
        if IsValid(menuPanel) then menuPanel:Remove() end
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:IsAdmin() then return end

    local f1Down = input.IsKeyDown(KEY_F1)
    if f1Down and not f1WasDown then
        OpenRestrictedSpawnMenu()
    end
    f1WasDown = f1Down
end)

hook.Add("PlayerBindPress", "RestrictedSpawnMenuBind", function(ply, bind, pressed)
    if not pressed then return end
    if bind ~= "+menu" and bind ~= "gm_showspare1" then return end

    if not CurrentRound or not CurrentRound() then return end
    if CurrentRound().name ~= "roleplay" then return end

    local lply = LocalPlayer()
    if not IsValid(lply) then return end
    if lply:IsAdmin() then return end

    OpenRestrictedSpawnMenu()
    return true -- блокируем стандартное меню
end)

]]
