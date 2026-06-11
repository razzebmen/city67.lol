-- [ZCITY_PORT] Файл автоматически мигрирован из gamemodes/zcity/.../modes/roleplay/cl_roleplay.lua
-- Источник: _backup_20260522_182916/zcity/gamemode/modes/roleplay/
-- Все обращения к CurrentRound()/MODE/round заменены на ZCity_RP.
-- ZCity_RP — это таблица-обёртка, имитирующая старый MODE-namespace,
--           содержит Jobs, AddMoney, TakeMoney, GetMoney, CityTaxRate и т.д.
-- Реализация в darkrp_modules/zcity_rp_core/sh_zcity_rp_namespace.lua

-- Клиентская часть режима Roleplay

-- Таблица для хранения количества игроков по профессиям
local JobCounts = {}

-- Баланс игрока
local PlayerMoney = 5000

-- Получение сетевых сообщений
net.Receive("roleplay_start", function()
    chat.AddText(Color(100, 255, 100), "[Roleplay] ", Color(255, 255, 255), "Режим Roleplay начался! Наслаждайтесь бесконечной игрой!")
end)

-- Получение ошибок выбора профессии
net.Receive("roleplay_job_error", function()
    local errorMsg = net.ReadString()
    chat.AddText(Color(220, 100, 80), "[Roleplay] ", Color(255, 255, 255), errorMsg)
end)

-- Получение успешного выбора профессии
net.Receive("roleplay_job_success", function()
    local jobName = net.ReadString()
    chat.AddText(Color(100, 255, 100), "[Roleplay] ", Color(255, 255, 255), "Вы выбрали профессию: ", Color(220, 220, 230), jobName)
    -- Запрашиваем свежие счётчики — Paint карточек обновится автоматически
    net.Start("roleplay_request_job_counts")
    net.SendToServer()
end)

-- Получение количества игроков по профессиям
net.Receive("roleplay_job_counts", function()
    JobCounts = net.ReadTable()
end)

-- Синхронизация денег с сервером
net.Receive("roleplay_sync_money", function()
    PlayerMoney = net.ReadInt(32)
end)

-- Цветные сообщения о передаче денег
net.Receive("roleplay_money_message", function()
    local isSender = net.ReadBool()
    local otherPlayerName = net.ReadString()
    local amount = net.ReadInt(32)
    
    if isSender then
        -- Сообщение для отправителя
        chat.AddText(
            Color(100, 255, 100), "[Roleplay] ",
            Color(255, 255, 255), "Вы передали ",
            Color(255, 200, 100), amount .. "$",
            Color(255, 255, 255), " игроку ",
            Color(100, 200, 255), otherPlayerName
        )
    else
        -- Сообщение для получателя
        chat.AddText(
            Color(100, 255, 100), "[Roleplay] ",
            Color(255, 255, 255), "Вы получили ",
            Color(100, 255, 100), amount .. "$",
            Color(255, 255, 255), " от игрока ",
            Color(100, 200, 255), otherPlayerName
        )
    end
end)

-- Функция для получения баланса (для использования в других местах)
function GetRoleplayMoney()
    return PlayerMoney
end

-- Меню передачи денег (по аналогии с меню патронов)
local function GiveMoneyMenu()
    local ply = LocalPlayer()
    if not ply:Alive() then return end
    
    -- Находим ближайших игроков в радиусе 5 метров
    local nearbyPlayers = {}
    local myPos = ply:GetPos()
    
    for _, target in player.Iterator() do
        if target ~= ply and target:Alive() and myPos:Distance(target:GetPos()) <= 500 then -- 500 единиц = ~5 метров
            table.insert(nearbyPlayers, target)
        end
    end
    
    if #nearbyPlayers == 0 then
        chat.AddText(Color(220, 100, 80), "[Roleplay] ", Color(255, 255, 255), "Рядом нет игроков")
        return
    end
    
    local moneyToGive = 0
    
    local Frame = vgui.Create("DFrame")
    Frame:SetTitle("")
    Frame:SetSize(250, 350)
    Frame:Center()
    Frame:MakePopup()
    Frame:ShowCloseButton(true)
    
    Frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 42, 245))
        surface.SetDrawColor(80, 20, 20, 200)
        surface.DrawRect(0, 0, w, 4)
        
        -- Заголовок
        draw.SimpleText("Передать деньги", "DermaDefault", w / 2, 15, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    local DPanel = vgui.Create("DScrollPanel", Frame)
    DPanel:SetPos(5, 30)
    DPanel:SetSize(240, 240)
    DPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 28, 200))
    end
    
    -- Поле для ввода суммы
    local TextEntry = vgui.Create("DTextEntry", Frame)
    TextEntry:SetPos(70, 278)
    TextEntry:SetSize(170, 25)
    TextEntry:SetPlaceholderText("Введите сумму")
    TextEntry:SetNumeric(true)
    TextEntry.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 28, 200))
        surface.SetDrawColor(80, 20, 20, 150)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(Color(255, 255, 255), Color(80, 20, 20), Color(255, 255, 255))
    end
    
    TextEntry.OnChange = function(self)
        local value = tonumber(self:GetValue()) or 0
        moneyToGive = math.max(0, math.min(value, PlayerMoney))
    end
    
    -- Добавляем кнопки для каждого ближайшего игрока
    for _, target in ipairs(nearbyPlayers) do
        local DermaButton = vgui.Create("DButton", DPanel)
        DermaButton:SetText(target:GetPlayerName())
        DermaButton:SetTextColor(Color(255, 255, 255))
        DermaButton:SetFont("DermaDefault")
        DermaButton:SetPos(0, 0)
        DermaButton:Dock(TOP)
        DermaButton:DockMargin(2, 2.5, 2, 0)
        DermaButton:SetSize(220, 30)
        
        DermaButton.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(80, 20, 20, 200) or Color(60, 15, 15, 150)
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
        end
        
        DermaButton.DoClick = function()
            if moneyToGive > 0 and moneyToGive <= PlayerMoney then
                net.Start("roleplay_give_money")
                net.WriteEntity(target)
                net.WriteInt(moneyToGive, 32)
                net.SendToServer()
                Frame:Close()
            else
                chat.AddText(Color(220, 100, 80), "[Roleplay] ", Color(255, 255, 255), "Укажите корректную сумму")
            end
        end
    end
    
    local DLabel = vgui.Create("DLabel", Frame)
    DLabel:SetPos(10, 305)
    DLabel:SetTextColor(color_white)
    DLabel:SetText("Выберите игрока")
    DLabel:SetFont("DermaDefault")
    DLabel:SizeToContents()
    
    local DLabel2 = vgui.Create("DLabel", Frame)
    DLabel2:SetPos(10, 282)
    DLabel2:SetTextColor(color_white)
    DLabel2:SetText("Сумма: ")
    DLabel2:SetFont("DermaDefault")
    DLabel2:SizeToContents()
    
    local DLabel3 = vgui.Create("DLabel", Frame)
    DLabel3:SetPos(10, 320)
    DLabel3:SetTextColor(Color(100, 220, 100))
    DLabel3:SetText("Баланс: " .. PlayerMoney .. "$")
    DLabel3:SetFont("DermaDefault")
    DLabel3:SizeToContents()
end

concommand.Add("roleplay_givemoney_menu", function()
    GiveMoneyMenu()
end)

-- Добавляем опцию в радиальное меню
hook.Add("radialOptions", "roleplay_givemoney", function()
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    
    local ply = LocalPlayer()
    if not ply:Alive() then return end
    
    hg.radialOptions[#hg.radialOptions + 1] = {
        function()
            RunConsoleCommand("roleplay_givemoney_menu")
            return 0
        end,
        "Give Money"
    }
end)

-- Добавляем опции для дверей в радиальное меню
hook.Add("radialOptions", "roleplay_doors", function()
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    
    local ply = LocalPlayer()
    if not ply:Alive() then return end
    
    local trace = ply:GetEyeTrace()
    local ent = trace.Entity
    
    if not IsValid(ent) then return end
    
    -- Проверяем, является ли это дверью
    local class = ent:GetClass()
    if class ~= "prop_door_rotating" and class ~= "func_door" and class ~= "func_door_rotating" then return end
    
    local entIndex = ent:EntIndex()
    local doorData = zb.ClDoors[entIndex]
    
    if not doorData then return end
    
    -- Проверяем расстояние
    local doorPos = ent:LocalToWorld(ent:OBBCenter())
    local distance = ply:GetPos():Distance(doorPos)
    
    if distance > 150 then return end
    
    -- Проверяем права на дверь
    local canUse = false
    local jobName = ply:GetNWString("RoleplayJob", "Гражданский")
    
    -- Владелец может использовать свою дверь
    if doorData.type == "buyable" and doorData.owner == ply:SteamID() then
        canUse = true
    end
    
    -- Полиция, спецназ и глава полиции могут использовать полицейские двери и двери мэрии
    if doorData.type == "police" and (jobName == "Полицейский" or jobName == "Спецназ" or jobName == "Глава Полиции") then
        canUse = true
    end
    
    if doorData.type == "mayor" and (jobName == "Полицейский" or jobName == "Спецназ" or jobName == "Глава Полиции") then
        canUse = true
    end
    
    -- Мэр может использовать двери мэрии и полицейские двери
    if doorData.type == "mayor" and jobName == "Мэр" then
        canUse = true
    end
    
    if doorData.type == "police" and jobName == "Мэр" then
        canUse = true
    end
    
    -- ЦАХАЛ может использовать двери игила
    if doorData.type == "isis" and (jobName == "Солдат ЦАХАЛ" or jobName == "Глава ЦАХАЛ") then
        canUse = true
    end
    
    if canUse then
        -- Определяем РЕАЛЬНОЕ состояние замка двери, а не только сохранённый
        -- кеш doorData.locked. Кеш может расходиться с физическим состоянием
        -- (после сноса/восстановления, после ручных Fire Lock/Unlock в карте,
        -- после смены раунда и т.п.). Источник правды — m_bLocked entity.
        local actuallyLocked
        if IsValid(ent) then
            local mb = ent:GetInternalVariable("m_bLocked")
            if mb ~= nil then
                actuallyLocked = mb
            end
        end
        if actuallyLocked == nil then
            actuallyLocked = doorData.locked or false
        end

        if actuallyLocked then
            -- Дверь заблокирована - показываем "Open Door"
            hg.radialOptions[#hg.radialOptions + 1] = {
                function()
                    net.Start("zb_door_lock")
                    net.WriteEntity(ent)
                    net.SendToServer()
                    return 0
                end,
                "Open Door"
            }
        else
            -- Дверь разблокирована - показываем "Close Door"
            hg.radialOptions[#hg.radialOptions + 1] = {
                function()
                    net.Start("zb_door_lock")
                    net.WriteEntity(ent)
                    net.SendToServer()
                    return 0
                end,
                "Close Door"
            }
        end
        
        -- Если это владелец покупаемой двери - добавляем кнопку продажи
        if doorData.type == "buyable" and doorData.owner == ply:SteamID() then
            hg.radialOptions[#hg.radialOptions + 1] = {
                function()
                    net.Start("zb_door_sell")
                    net.WriteEntity(ent)
                    net.SendToServer()
                    return 0
                end,
                "Sell Door 100$"
            }
        end
    end
end)

-- Таймер респавна
local RespawnTime = 0

-- Получение таймера респавна от сервера
net.Receive("roleplay_respawn_timer", function()
    local time = net.ReadFloat()
    RespawnTime = CurTime() + time
end)

-- Сообщение о респавне
hook.Add("PlayerDeath", "RoleplayDeathMessage", function(victim, inflictor, attacker)
    if not CurrentRound then return end
    local round = ZCity_RP -- [ZCITY_PORT]
    
    if victim == LocalPlayer() then
        timer.Simple(1, function()
            chat.AddText(Color(255, 200, 100), "[Roleplay] ", Color(255, 255, 255), "Вы возродитесь через 15 секунд...")
        end)
    end
end)

-- Отображение таймера респавна на экране
hook.Add("HUDPaint", "RoleplayRespawnTimer", function()
    if not CurrentRound then return end
    local round = ZCity_RP -- [ZCITY_PORT]

    local ply = LocalPlayer()
    -- Не показываем живым.
    if not IsValid(ply) or ply:Alive() then return end

    -- Не показываем тем, кто ушёл в спектаторы через таб (TEAM_SPECTATOR):
    -- они мёртвые, но НЕ возрождаются (sv_respawn_delay их пропускает), поэтому
    -- плашка таймера зависала бы навсегда на «Возрождение...». Обычная смерть
    -- команду не меняет (TEAM_SPECTATOR ставит только sv_specmode), так что
    -- нормально умерших игроков это не затрагивает.
    if ply:Team() == TEAM_SPECTATOR then return end

    -- Показываем плашку даже когда время истекло (но игрок ещё не заспавнился) —
    -- даём «Возрождение...» в этот короткий промежуток, чтобы не было «пустого» экрана.
    if RespawnTime <= 0 then return end

    local diff = RespawnTime - CurTime()
    local scrW, scrH = ScrW(), ScrH()

    -- Фон для текста
    draw.RoundedBox(8, scrW / 2 - 200, scrH / 2 - 60, 400, 120, Color(20, 20, 28, 230))
    -- Обводка
    surface.SetDrawColor(80, 20, 20, 200)
    surface.DrawOutlinedRect(scrW / 2 - 200, scrH / 2 - 60, 400, 120, 2)

    if diff > 0 then
        -- math.floor + 1 даёт честный обратный отсчёт 15→14→...→1 без скачка через 0.
        local timeLeft = math.floor(diff) + 1
        if timeLeft > 15 then timeLeft = 15 end

        draw.SimpleText("До респавна:", "DermaLarge", scrW / 2, scrH / 2 - 20, Color(220, 220, 230, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(timeLeft .. " сек", "DermaLarge", scrW / 2, scrH / 2 + 20, Color(220, 100, 80, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        -- Время истекло, ждём подтверждения с сервера (PlayerSpawn)
        draw.SimpleText("Возрождение...", "DermaLarge", scrW / 2, scrH / 2, Color(220, 220, 230, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

-- Сбрасываем таймер на спавне (плашка должна сразу пропасть когда оживили)
hook.Add("PlayerSpawn", "RoleplayRespawnTimerReset", function(ply)
    if ply == LocalPlayer() then
        RespawnTime = 0
    end
end)

-- Меню F4
local RoleplayMenu = nil

local function CreateRoleplayMenu()
    -- Запрашиваем актуальное количество игроков по профессиям
    net.Start("roleplay_request_job_counts")
    net.SendToServer()
    
    if IsValid(RoleplayMenu) then
        RoleplayMenu:Remove()
        RoleplayMenu = nil
        gui.EnableScreenClicker(false)
        return
    end
    
    local scrW, scrH = ScrW(), ScrH()
    
    RoleplayMenu = vgui.Create("DFrame")
    RoleplayMenu:SetSize(1100, 700)
    RoleplayMenu:Center()
    RoleplayMenu:SetTitle("")
    RoleplayMenu:SetVisible(true)
    RoleplayMenu:SetDraggable(false)
    RoleplayMenu:ShowCloseButton(false)
    RoleplayMenu:MakePopup()
    
    RoleplayMenu.Paint = function(self, w, h)
        -- Основной фон с градиентом
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 20, 28, 245))
        
        -- Верхняя полоса с градиентом
        surface.SetDrawColor(80, 20, 20, 200)
        surface.DrawRect(0, 0, w, 4)
        
        -- Тонкая обводка
        surface.SetDrawColor(60, 60, 75, 180)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        -- Заголовок
        draw.SimpleText("Z-CITY ROLEPLAY", "DermaLarge", w / 2, 30, Color(220, 220, 230, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Линия под заголовком
        surface.SetDrawColor(80, 20, 20, 150)
        surface.DrawRect(w / 2 - 150, 50, 300, 2)
    end
    
    RoleplayMenu.OnRemove = function()
        gui.EnableScreenClicker(false)
    end
    
    -- Кнопка закрытия
    local CloseBtn = vgui.Create("DButton", RoleplayMenu)
    CloseBtn:SetPos(RoleplayMenu:GetWide() - 45, 10)
    CloseBtn:SetSize(35, 35)
    CloseBtn:SetText("")
    CloseBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and Color(200, 50, 50, 255) or Color(80, 20, 20, 200)
        draw.RoundedBox(4, 0, 0, w, h, col)
        
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawLine(10, 10, w - 10, h - 10)
        surface.DrawLine(w - 10, 10, 10, h - 10)
    end
    CloseBtn.DoClick = function()
        RoleplayMenu:Remove()
    end
    
    -- Панель вкладок
    local TabPanel = vgui.Create("DPanel", RoleplayMenu)
    TabPanel:Dock(TOP)
    TabPanel:SetTall(70)
    TabPanel:DockMargin(0, 65, 0, 0)
    TabPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(25, 25, 35, 200))
        
        -- Нижняя линия
        surface.SetDrawColor(80, 20, 20, 150)
        surface.DrawRect(0, h - 2, w, 2)
    end
    
    -- Панель контента
    local ContentPanel = vgui.Create("DPanel", RoleplayMenu)
    ContentPanel:Dock(FILL)
    ContentPanel.Paint = nil
    
    local activeTab = nil
    
    local function ClearContent()
        for k, v in pairs(ContentPanel:GetChildren()) do
            v:Remove()
        end
    end
    
    local function CreateTab(text, color, onClick)
        local btn = vgui.Create("DButton", TabPanel)
        btn:Dock(LEFT)
        btn:SetWide(220)
        btn:SetText("")
        btn:DockMargin(15, 12, 5, 12)
        
        btn.Paint = function(self, w, h)
            local isActive = (activeTab == self)
            
            if isActive then
                -- Активная вкладка
                draw.RoundedBox(6, 0, 0, w, h, color)
                
                -- Светящаяся обводка
                surface.SetDrawColor(color.r + 40, color.g + 40, color.b + 40, 200)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
                
                draw.SimpleText(text, "DermaLarge", w / 2, h / 2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                -- Неактивная вкладка
                local bgColor = self:IsHovered() and Color(45, 45, 60, 255) or Color(35, 35, 48, 255)
                draw.RoundedBox(6, 0, 0, w, h, bgColor)
                
                if self:IsHovered() then
                    surface.SetDrawColor(color.r, color.g, color.b, 100)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                end
                
                local textColor = self:IsHovered() and Color(220, 220, 230, 255) or Color(160, 160, 180, 255)
                draw.SimpleText(text, "DermaLarge", w / 2, h / 2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
        
        btn.DoClick = function(self)
            activeTab = self
            onClick()
        end
        
        return btn
    end
    
    -- Вкладка "Профессии"
    local JobsTab = CreateTab("Профессии", Color(80, 140, 220, 255), function()
        ClearContent()
        
        local Scroll = vgui.Create("DScrollPanel", ContentPanel)
        Scroll:Dock(FILL)
        Scroll:DockMargin(25, 20, 25, 25)
        
        -- Стилизация скроллбара
        local sbar = Scroll:GetVBar()
        sbar:SetWide(8)
        sbar:SetHideButtons(true)
        sbar.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 40, 200))
        end
        sbar.btnGrip.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(80, 20, 20, 200))
        end
        
        local jobs = {
            {
                name = "Гражданский",
                desc = "Обычный житель города, занимающийся повседневными делами",
                salary = "100",
                color = Color(80, 180, 100),
                weapons = "Нет оружия",
                limit = 0
            },
            {
                name = "Мэр",
                desc = "Глава города, принимающий важные решения для населения",
                salary = "500",
                color = Color(200, 160, 60),
                weapons = "Охрана",
                limit = 1
            },
            {
                name = "Полицейский",
                desc = "Охрана порядка и патрулирование города",
                salary = "250",
                color = Color(60, 120, 200),
                weapons = "Пистолет, Дубинка, Наручники, Тэйзер",
                limit = 10
            },
            {
                name = "Спецназ",
                desc = "Тактический отряд быстрого реагирования",
                salary = "350",
                color = Color(40, 80, 140),
                weapons = "Штурмовая винтовка, Наручники, Таран",
                limit = 5
            },
            {
                name = "Глава Полиции",
                desc = "Командование всеми силовыми структурами",
                salary = "400",
                color = Color(80, 100, 180),
                weapons = "Пистолет, Наручники",
                limit = 1
            },
            {
                name = "Солдат ЦАХАЛ",
                desc = "Боевик террористической организации",
                salary = "200",
                color = Color(120, 40, 40),
                weapons = "Автомат, Граната",
                limit = 10
            },
            {
                name = "Глава ЦАХАЛ",
                desc = "Лидер террористической группировки, командующий боевиками",
                salary = "400",
                color = Color(100, 20, 20),
                weapons = "Автомат, Граната, Взрывчатка",
                limit = 1
            },
            {
                name = "Бандит",
                desc = "Преступник, живущий вне закона и занимающийся незаконной деятельностью",
                salary = "150",
                color = Color(180, 60, 60),
                weapons = "Пистолет",
                limit = 15
            },
            {
                name = "Продавец Оружия",
                desc = "Торговец оружием и боеприпасами на черном рынке",
                salary = "300",
                color = Color(140, 100, 60),
                weapons = "Пистолет, Товары",
                limit = 2
            },
            {
                name    = "Медик",
                desc    = "Медицинский работник, оказывающий помощь раненым и больным",
                salary  = "200",
                color   = Color(60, 180, 100),
                weapons = "Медикаменты, Бандажи, Адреналин",
                limit   = 5
            },
        }
        
        for _, job in ipairs(jobs) do
            local JobCard = vgui.Create("DPanel", Scroll)
            JobCard:Dock(TOP)
            JobCard:DockMargin(0, 0, 0, 10)
            JobCard:SetTall(120)

            JobCard.Paint = function(self, w, h)
                local active = (job.name == LocalPlayer():GetNWString("RoleplayJob", "Гражданский"))
                draw.RoundedBox(8, 0, 0, w, h, active and Color(20, 50, 25, 255) or Color(30, 30, 42, 255))
                draw.RoundedBox(4, 0, 0, 6, h, job.color)
                if active then
                    surface.SetDrawColor(80, 200, 80, 200)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                elseif self:IsHovered() then
                    draw.RoundedBox(8, 0, 0, w, h, Color(255, 255, 255, 8))
                    surface.SetDrawColor(job.color.r, job.color.g, job.color.b, 100)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                end
            end

            -- Кнопка выбора (dock right, чтобы точно не перекрывала текст)
            local SelectBtn = vgui.Create("DButton", JobCard)
            SelectBtn:SetText("")
            SelectBtn:SetWide(130)
            SelectBtn:Dock(RIGHT)
            SelectBtn:DockMargin(0, 18, 20, 18)

            SelectBtn.Paint = function(self, w, h)
                local active = (job.name == LocalPlayer():GetNWString("RoleplayJob", "Гражданский"))
                if active then
                    draw.RoundedBox(6, 0, 0, w, h, Color(30, 90, 40, 255))
                    surface.SetDrawColor(80, 200, 80, 180)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                    draw.SimpleText("Текущая", "DermaLarge", w / 2, h / 2, Color(100, 255, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                else
                    local bgColor = self:IsHovered() and Color(job.color.r + 20, job.color.g + 20, job.color.b + 20, 255) or job.color
                    draw.RoundedBox(6, 0, 0, w, h, bgColor)
                    if self:IsHovered() then
                        draw.RoundedBox(6, 0, 0, w, h, Color(255, 255, 255, 20))
                    end
                    draw.SimpleText("Выбрать", "DermaLarge", w / 2, h / 2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            SelectBtn.DoClick = function()
                if job.name == LocalPlayer():GetNWString("RoleplayJob", "Гражданский") then return end
                net.Start("roleplay_select_job")
                net.WriteString(job.name)
                net.SendToServer()
            end

            -- Счётчик слотов (dock right, слева от кнопки)
            if job.limit > 0 then
                local jobCount = JobCounts[job.name]
                local LimitLabel = vgui.Create("DLabel", JobCard)
                LimitLabel:SetFont("DermaLarge")
                LimitLabel:SetText((jobCount and jobCount.current or 0) .. "/" .. job.limit)
                LimitLabel:SetTextColor(Color(255, 255, 255))
                LimitLabel:SizeToContents()
                LimitLabel:Dock(RIGHT)
                LimitLabel:DockMargin(0, 0, 10, 0)
            end

            -- Текстовый блок (fill, чтобы занимал оставшееся место)
            local TextPanel = vgui.Create("DPanel", JobCard)
            TextPanel:Dock(FILL)
            TextPanel:DockMargin(18, 0, 8, 0)
            TextPanel.Paint = nil

            local NameLabel = vgui.Create("DLabel", TextPanel)
            NameLabel:SetFont("DermaLarge")
            NameLabel:SetText(job.name)
            NameLabel:SetTextColor(Color(255, 255, 255))
            NameLabel:Dock(TOP)
            NameLabel:DockMargin(0, 6, 0, 4)
            NameLabel:SizeToContents()

            local SalaryLabel = vgui.Create("DLabel", TextPanel)
            SalaryLabel:SetFont("DermaLarge")
            SalaryLabel:SetText("Зарплата: " .. job.salary .. "$")
            SalaryLabel:SetTextColor(Color(100, 220, 100))
            SalaryLabel:Dock(TOP)
            SalaryLabel:DockMargin(0, 0, 0, 2)
            SalaryLabel:SizeToContents()

            local WeaponLabel = vgui.Create("DLabel", TextPanel)
            WeaponLabel:SetFont("DermaLarge")
            WeaponLabel:SetText("Снаряжение: " .. job.weapons)
            WeaponLabel:SetTextColor(Color(200, 200, 210))
            WeaponLabel:Dock(TOP)
            WeaponLabel:SizeToContents()

        end
    end)
    
    -- Вкладка "Правила"
    local RulesTab = CreateTab("Правила", Color(220, 100, 80, 255), function()
        ClearContent()

        -- Правила теперь хранятся в Google Docs — всегда актуальная версия
        -- без рестарта сервера. Здесь просто баннер с кнопкой-ссылкой.
        local RULES_URL =
            "https://docs.google.com/document/d/1eaS_nkPpdgoX6NxUBcG94jPWR2hH7GgDowddrWp6r84/edit?usp=sharing"

        local Wrap = vgui.Create("DPanel", ContentPanel)
        Wrap:Dock(FILL)
        Wrap:DockMargin(25, 20, 25, 25)
        Wrap.Paint = nil

        -- Заголовок
        local Header = vgui.Create("DPanel", Wrap)
        Header:Dock(TOP)
        Header:SetTall(60)
        Header:DockMargin(0, 0, 0, 16)
        Header.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(220, 100, 80, 220))
            draw.SimpleText("ПРАВИЛА СЕРВЕРА", "DermaLarge",
                w / 2, h / 2, Color(255, 255, 255),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Карточка с описанием + кнопкой
        local Card = vgui.Create("DPanel", Wrap)
        Card:Dock(TOP)
        Card:SetTall(260)
        Card.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 42, 255))
        end

        local Title = vgui.Create("DLabel", Card)
        Title:Dock(TOP)
        Title:DockMargin(20, 24, 20, 0)
        Title:SetText("Полный текст правил")
        Title:SetFont("DermaLarge")
        Title:SetTextColor(Color(255, 255, 255))
        Title:SetContentAlignment(5)
        Title:SetTall(32)

        local Desc = vgui.Create("DLabel", Card)
        Desc:Dock(TOP)
        Desc:DockMargin(40, 8, 40, 0)
        Desc:SetText(
            "Актуальная версия правил находится в Google Документе.\n" ..
            "Незнание правил не освобождает от ответственности.")
        Desc:SetFont("DermaLarge")
        Desc:SetTextColor(Color(200, 200, 215))
        Desc:SetContentAlignment(5)
        Desc:SetWrap(true)
        Desc:SetAutoStretchVertical(true)

        local Url = vgui.Create("DLabel", Card)
        Url:Dock(TOP)
        Url:DockMargin(20, 16, 20, 0)
        Url:SetText(RULES_URL)
        Url:SetFont("DermaDefault")
        Url:SetTextColor(Color(120, 130, 145))
        Url:SetContentAlignment(5)
        Url:SetTall(20)

        local OpenBtn = vgui.Create("DButton", Card)
        OpenBtn:Dock(TOP)
        OpenBtn:DockMargin(80, 24, 80, 24)
        OpenBtn:SetTall(50)
        OpenBtn:SetText("")
        OpenBtn.Paint = function(self, w, h)
            local bg = self:IsHovered()
                and Color(240, 130, 110, 255)
                or Color(220, 100, 80, 255)
            draw.RoundedBox(8, 0, 0, w, h, bg)
            draw.SimpleText("ОТКРЫТЬ ПРАВИЛА В БРАУЗЕРЕ", "DermaLarge",
                w / 2, h / 2, Color(255, 255, 255),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        OpenBtn.DoClick = function()
            gui.OpenURL(RULES_URL)
            chat.AddText(Color(220, 100, 80), "[Правила] ",
                Color(255, 255, 255), "Ссылка открыта в браузере.")
        end

        local CopyBtn = vgui.Create("DButton", Card)
        CopyBtn:Dock(TOP)
        CopyBtn:DockMargin(80, 0, 80, 0)
        CopyBtn:SetTall(36)
        CopyBtn:SetText("")
        CopyBtn.Paint = function(self, w, h)
            local bg = self:IsHovered()
                and Color(60, 60, 75, 255)
                or Color(45, 45, 58, 255)
            draw.RoundedBox(6, 0, 0, w, h, bg)
            draw.SimpleText("Скопировать ссылку", "DermaDefaultBold",
                w / 2, h / 2, Color(220, 220, 230),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        CopyBtn.DoClick = function()
            SetClipboardText(RULES_URL)
            chat.AddText(Color(220, 100, 80), "[Правила] ",
                Color(255, 255, 255), "Ссылка скопирована в буфер обмена.")
        end
    end)

    
    -- Вкладка "Магазин"
    local ShopTab = CreateTab("Магазин", Color(100, 200, 100, 255), function()
        ClearContent()
        
        local Scroll = vgui.Create("DScrollPanel", ContentPanel)
        Scroll:Dock(FILL)
        Scroll:DockMargin(25, 20, 25, 25)
        
        -- Стилизация скроллбара
        local sbar = Scroll:GetVBar()
        sbar:SetWide(8)
        sbar:SetHideButtons(true)
        sbar.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 40, 200))
        end
        sbar.btnGrip.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(80, 20, 20, 200))
        end
        
        -- Заголовок "Принтеры"
        local HeaderPanel = vgui.Create("DPanel", Scroll)
        HeaderPanel:Dock(TOP)
        HeaderPanel:DockMargin(0, 0, 0, 15)
        HeaderPanel:SetTall(50)
        
        HeaderPanel.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(100, 200, 100, 200))
            draw.SimpleText("ПРИНТЕРЫ", "DermaLarge", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        
        local printers = {
            {
                type = "basic",
                name = "Обычный принтер",
                desc = "Базовая модель для начинающих предпринимателей",
                income = "10$ каждые 10 секунд",
                price = 500,
                color = Color(100, 100, 100)
            },
            {
                type = "medium",
                name = "Средний принтер",
                desc = "Улучшенная модель с повышенной производительностью",
                income = "25$ каждые 10 секунд",
                price = 1000,
                color = Color(100, 150, 255)
            },
            {
                type = "advanced",
                name = "Улучшенный принтер",
                desc = "Топовая модель для серьезного бизнеса",
                income = "50$ каждые 10 секунд",
                price = 1500,
                color = Color(255, 200, 100)
            }
        }
        
        -- Функция создания карточки принтера
        local function CreatePrinterCard(parent, printer, width)
            local PrinterCard = vgui.Create("DPanel", parent)
            PrinterCard:SetSize(width, 220)
            
            PrinterCard.Paint = function(self, w, h)
                -- Основной фон карточки
                draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 42, 255))
                
                -- Цветная полоса сверху
                draw.RoundedBox(4, 0, 0, w, 6, printer.color)
                
                -- Эффект при наведении
                if self:IsHovered() then
                    draw.RoundedBox(8, 0, 0, w, h, Color(255, 255, 255, 8))
                    surface.SetDrawColor(printer.color.r, printer.color.g, printer.color.b, 100)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                end
            end
            
            -- Название принтера
            local NameLabel = vgui.Create("DLabel", PrinterCard)
            NameLabel:Dock(TOP)
            NameLabel:DockMargin(10, 25, 10, 10)
            NameLabel:SetFont("DermaLarge")
            NameLabel:SetText(printer.name)
            NameLabel:SetTextColor(printer.color)
            NameLabel:SetContentAlignment(5)
            NameLabel:SetTall(25)
            
            -- Доход
            local IncomeLabel = vgui.Create("DLabel", PrinterCard)
            IncomeLabel:Dock(TOP)
            IncomeLabel:DockMargin(10, 15, 10, 5)
            IncomeLabel:SetFont("DermaLarge")
            IncomeLabel:SetText("Доход: " .. printer.income)
            IncomeLabel:SetTextColor(Color(100, 220, 100))
            IncomeLabel:SetContentAlignment(5)
            IncomeLabel:SetTall(25)
            
            -- Цена
            local PriceLabel = vgui.Create("DLabel", PrinterCard)
            PriceLabel:Dock(TOP)
            PriceLabel:DockMargin(10, 5, 10, 15)
            PriceLabel:SetFont("DermaLarge")
            PriceLabel:SetText("Цена: " .. printer.price .. "$")
            PriceLabel:SetTextColor(Color(255, 200, 100))
            PriceLabel:SetContentAlignment(5)
            PriceLabel:SetTall(25)
            
            -- Кнопка покупки
            local BuyBtn = vgui.Create("DButton", PrinterCard)
            BuyBtn:Dock(TOP)
            BuyBtn:DockMargin(40, 10, 40, 20)
            BuyBtn:SetTall(45)
            BuyBtn:SetText("")
            
            BuyBtn.Paint = function(self, w, h)
                local bgColor = self:IsHovered() and Color(printer.color.r + 20, printer.color.g + 20, printer.color.b + 20, 255) or printer.color
                draw.RoundedBox(6, 0, 0, w, h, bgColor)
                
                if self:IsHovered() then
                    draw.RoundedBox(6, 0, 0, w, h, Color(255, 255, 255, 20))
                end
                
                draw.SimpleText("Купить", "DermaLarge", w / 2, h / 2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            
            BuyBtn.DoClick = function()
                net.Start("roleplay_buy_printer")
                net.WriteString(printer.type)
                net.SendToServer()
                
                -- Закрываем меню после покупки
                RoleplayMenu:Remove()
            end
            
            return PrinterCard
        end
        
        -- Первая строка (2 принтера)
        local Row1 = vgui.Create("DPanel", Scroll)
        Row1:Dock(TOP)
        Row1:DockMargin(0, 0, 0, 15)
        Row1:SetTall(220)
        Row1.Paint = nil
        
        Row1.PerformLayout = function(self, w, h)
            local cardWidth = (w - 15) / 2
            
            if IsValid(self.Card1) then
                self.Card1:SetSize(cardWidth, 220)
                self.Card1:SetPos(0, 0)
            end
            
            if IsValid(self.Card2) then
                self.Card2:SetSize(cardWidth, 220)
                self.Card2:SetPos(cardWidth + 15, 0)
            end
        end
        
        Row1.Card1 = CreatePrinterCard(Row1, printers[1], 500)
        Row1.Card2 = CreatePrinterCard(Row1, printers[2], 500)
        
        -- Вторая строка (1 принтер по центру)
        local Row2 = vgui.Create("DPanel", Scroll)
        Row2:Dock(TOP)
        Row2:DockMargin(0, 0, 0, 15)
        Row2:SetTall(220)
        Row2.Paint = nil
        
        Row2.PerformLayout = function(self, w, h)
            local cardWidth = (w - 15) / 2
            
            if IsValid(self.Card3) then
                self.Card3:SetSize(cardWidth, 220)
                self.Card3:SetPos((w - cardWidth) / 2, 0)
            end
        end
        
        Row2.Card3 = CreatePrinterCard(Row2, printers[3], 500)

        -- Заголовок и карточка "Магазин оружия" — только для Продавца Оружия
        if LocalPlayer():GetNWString("RoleplayJob", "Гражданский") == "Продавец Оружия" then

        -- Заголовок "Магазин оружия"
        local GunShopHeader = vgui.Create("DPanel", Scroll)
        GunShopHeader:Dock(TOP)
        GunShopHeader:DockMargin(0, 20, 0, 15)
        GunShopHeader:SetTall(50)
        GunShopHeader.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(140, 100, 60, 200))
            draw.SimpleText("МАГАЗИН ОРУЖИЯ", "DermaLarge", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Карточка "Магазин оружия"
        local GunShopCard = vgui.Create("DPanel", Scroll)
        GunShopCard:Dock(TOP)
        GunShopCard:DockMargin(0, 0, 0, 15)
        GunShopCard:SetTall(220)

        GunShopCard.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 42, 255))
            draw.RoundedBox(4, 0, 0, w, 6, Color(140, 100, 60))
            if self:IsHovered() then
                draw.RoundedBox(8, 0, 0, w, h, Color(255, 255, 255, 8))
                surface.SetDrawColor(140, 100, 60, 100)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
            end
        end

        local GunShopName = vgui.Create("DLabel", GunShopCard)
        GunShopName:Dock(TOP)
        GunShopName:DockMargin(10, 25, 10, 10)
        GunShopName:SetFont("DermaLarge")
        GunShopName:SetText("Магазин оружия")
        GunShopName:SetTextColor(Color(255, 200, 80))
        GunShopName:SetContentAlignment(5)
        GunShopName:SetTall(25)

        local GunShopDesc = vgui.Create("DLabel", GunShopCard)
        GunShopDesc:Dock(TOP)
        GunShopDesc:DockMargin(10, 5, 10, 5)
        GunShopDesc:SetFont("DermaLarge")
        GunShopDesc:SetText("Проп-автомат для продажи оружия. Любой игрок может нажать E и купить оружие. Вы получаете 20% с каждой продажи.")
        GunShopDesc:SetTextColor(Color(180, 180, 195))
        GunShopDesc:SetWrap(true)
        GunShopDesc:SetAutoStretchVertical(true)
        GunShopDesc:SetTall(50)

        local GunShopPrice = vgui.Create("DLabel", GunShopCard)
        GunShopPrice:Dock(TOP)
        GunShopPrice:DockMargin(10, 5, 10, 5)
        GunShopPrice:SetFont("DermaLarge")
        GunShopPrice:SetText("Цена: 15000$")
        GunShopPrice:SetTextColor(Color(255, 200, 100))
        GunShopPrice:SetContentAlignment(5)
        GunShopPrice:SetTall(25)

        local GunShopBuyBtn = vgui.Create("DButton", GunShopCard)
        GunShopBuyBtn:Dock(TOP)
        GunShopBuyBtn:DockMargin(40, 10, 40, 20)
        GunShopBuyBtn:SetTall(45)
        GunShopBuyBtn:SetText("")

        GunShopBuyBtn.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(170, 130, 90, 255) or Color(140, 100, 60, 255)
            draw.RoundedBox(6, 0, 0, w, h, bgColor)
            if self:IsHovered() then
                draw.RoundedBox(6, 0, 0, w, h, Color(255, 255, 255, 20))
            end
            draw.SimpleText("Купить", "DermaLarge", w / 2, h / 2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        GunShopBuyBtn.DoClick = function()
            -- Только Продавец Оружия может купить
            local jobName = LocalPlayer():GetNWString("RoleplayJob", "Гражданский")
            if jobName ~= "Продавец Оружия" then
                chat.AddText(Color(255, 100, 100), "[Roleplay] ", Color(255, 255, 255), "Только Продавец Оружия может купить этот предмет")
                return
            end
            net.Start("roleplay_buy_gun_shop")
            net.SendToServer()
            RoleplayMenu:Remove()
        end

        end -- конец if "Продавец Оружия"
    end)
    
    -- Вкладка "Жалобы" (FrePorts)
    -- Встроенная форма подачи жалобы прямо в F4
    local ReportTab = CreateTab("Жалобы", Color(200, 140, 255, 255), function()
        ClearContent()

        local wrap = vgui.Create("DPanel", ContentPanel)
        wrap:Dock(FILL)
        wrap:DockMargin(40, 30, 40, 30)
        wrap.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(25, 25, 35, 235))
            surface.SetDrawColor(120, 80, 200, 80)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local title = vgui.Create("DLabel", wrap)
        title:Dock(TOP)
        title:DockMargin(20, 20, 20, 5)
        title:SetTall(40)
        title:SetFont("DermaLarge")
        title:SetText("Подать жалобу администрации")
        title:SetTextColor(Color(220, 180, 255))

        local hint = vgui.Create("DLabel", wrap)
        hint:Dock(TOP)
        hint:DockMargin(20, 0, 20, 15)
        hint:SetTall(40)
        hint:SetWrap(true)
        hint:SetAutoStretchVertical(true)
        hint:SetFont("DermaDefault")
        hint:SetTextColor(Color(180, 180, 200))
        hint:SetText("Опишите ситуацию подробно. Можно также через чат: @ <причина>. После подачи откроется окно чата с админом.")

        local entry = vgui.Create("DTextEntry", wrap)
        entry:Dock(TOP)
        entry:DockMargin(20, 10, 20, 10)
        entry:SetTall(120)
        entry:SetMultiline(true)
        entry:SetFont("DermaDefault")
        entry:SetPlaceholderText("Введите причину жалобы...")
        entry:SetUpdateOnType(true)

        local btn = vgui.Create("DButton", wrap)
        btn:Dock(TOP)
        btn:DockMargin(20, 0, 20, 20)
        btn:SetTall(45)
        btn:SetText("")
        btn.Paint = function(self, w, h)
            local col = self:IsHovered() and Color(160, 90, 220) or Color(120, 60, 180)
            draw.RoundedBox(6, 0, 0, w, h, col)
            draw.SimpleText("Отправить жалобу", "DermaLarge", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            local reason = string.Trim(entry:GetValue() or "")
            if #reason < 3 then
                chat.AddText(Color(255, 100, 100), "[Жалобы] ", Color(255, 255, 255), "Опишите причину подробнее (минимум 3 символа).")
                return
            end
            -- FrePorts слушает чат: "@ <причина>". Эмулируем отправку в чат —
            -- серверный PlayerSay-хук создаст жалобу и скроет сообщение из общего чата.
            local cmd = (freports and freports.config and freports.config.command) or "@"
            -- Чистим кавычки и переносы строк, иначе консольная команда say оборвётся
            local safe = reason:gsub('"', "'"):gsub("[\r\n]+", " ")
            LocalPlayer():ConCommand('say "' .. cmd .. ' ' .. safe .. '"')
            if IsValid(RoleplayMenu) then RoleplayMenu:Remove() end
        end

        -- Кнопка статистики администрации (FrePorts: концоманда reps_stats)
        local menuBtn = vgui.Create("DButton", wrap)
        menuBtn:Dock(TOP)
        menuBtn:DockMargin(20, 0, 20, 20)
        menuBtn:SetTall(35)
        menuBtn:SetText("")
        menuBtn.Paint = function(self, w, h)
            local col = self:IsHovered() and Color(70, 70, 95) or Color(50, 50, 70)
            draw.RoundedBox(6, 0, 0, w, h, col)
            draw.SimpleText("Статистика администрации", "DermaDefaultBold", w/2, h/2, Color(220, 220, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        menuBtn.DoClick = function()
            if IsValid(RoleplayMenu) then RoleplayMenu:Remove() end
            RunConsoleCommand((freports and freports.config and freports.config.reps_stats_cmd) or "reps_stats")
        end
    end)

    -- Открываем профессии по умолчанию
    activeTab = JobsTab
    JobsTab:DoClick()
end

-- Хук на нажатие F4
local nextF4Press = 0

hook.Add("Think", "RoleplayF4MenuCheck", function()
    if not CurrentRound then return end
    local round = ZCity_RP -- [ZCITY_PORT]
    
    if input.IsKeyDown(KEY_F4) and CurTime() >= nextF4Press then
        nextF4Press = CurTime() + 0.3
        CreateRoleplayMenu()
    end
end)

-- ============================================
-- СИСТЕМА ДВЕРЕЙ - КЛИЕНТСКАЯ ЧАСТЬ
-- ============================================

-- Отрисовка информации о дверях в 3D
hook.Add("PostDrawTranslucentRenderables", "RoleplayDrawDoorInfo3D", function()
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    -- Отрисовываем информацию на всех дверях
    for entIndex, doorData in pairs(zb.ClDoors or {}) do
        local ent = Entity(entIndex)
        if not IsValid(ent) then continue end
        
        -- Не рисуем текст если дверь выбита
        if ent:GetNoDraw() then continue end
        
        local doorPos = ent:LocalToWorld(ent:OBBCenter())
        local distance = ply:GetPos():Distance(doorPos)
        
        -- Не рисуем слишком далекие двери
        if distance > 1024 then continue end
        
        -- Получаем углы двери
        local doorAng = ent:GetAngles()
        
        -- Определяем, что показывать
        local lines = {}
        
        if doorData.type == "buyable" then
            if doorData.owner then
                -- Дверь занята
                table.insert(lines, {text = "Занято", color = Color(255, 100, 100)})
                table.insert(lines, {text = doorData.ownerName or "Неизвестно", color = Color(255, 255, 255)})
            else
                -- Дверь свободна
                table.insert(lines, {text = "Свободно!", color = Color(255, 255, 255)})
                table.insert(lines, {text = "200$", color = Color(100, 255, 100)})
                table.insert(lines, {text = "Купить - F2", color = Color(200, 200, 200)})
            end
        elseif doorData.type == "police" then
            table.insert(lines, {text = "Принадлежит:", color = Color(200, 200, 200)})
            table.insert(lines, {text = "Полиция", color = Color(100, 150, 255)})
        elseif doorData.type == "mayor" then
            table.insert(lines, {text = "Принадлежит:", color = Color(200, 200, 200)})
            table.insert(lines, {text = "Мэрия", color = Color(255, 200, 100)})
        elseif doorData.type == "isis" then
            table.insert(lines, {text = "Принадлежит:", color = Color(200, 200, 200)})
            table.insert(lines, {text = "ЦАХАЛ", color = Color(255, 100, 100)})
        end
        
        -- Рисуем текст с обеих сторон двери
        -- Используем только yaw угол двери для правильной ориентации
        local doorAng = ent:GetAngles()
        
        -- Создаем углы для текста на плоскости двери
        local ang1 = Angle(0, doorAng.y + 90, 90)
        local ang2 = Angle(0, doorAng.y - 90, 90)
        
        -- Смещаем позицию текста от центра двери наружу
        local offset = 2
        local forward = doorAng:Forward()
        local pos1 = doorPos + forward * offset
        local pos2 = doorPos - forward * offset
        
        -- Рисуем с обеих сторон (уменьшенный масштаб 0.2)
        cam.Start3D2D(pos1, ang1, 0.2)
            local yOffset = -15 * #lines
            
            for i, line in ipairs(lines) do
                -- Тень
                draw.SimpleText(
                    line.text,
                    "DermaLarge",
                    2,
                    yOffset + 2,
                    Color(0, 0, 0, 200),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
                
                -- Основной текст
                draw.SimpleText(
                    line.text,
                    "DermaLarge",
                    0,
                    yOffset,
                    line.color,
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
                
                yOffset = yOffset + 30
            end
        cam.End3D2D()
        
        cam.Start3D2D(pos2, ang2, 0.2)
            local yOffset = -15 * #lines
            
            for i, line in ipairs(lines) do
                -- Тень
                draw.SimpleText(
                    line.text,
                    "DermaLarge",
                    2,
                    yOffset + 2,
                    Color(0, 0, 0, 200),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
                
                -- Основной текст
                draw.SimpleText(
                    line.text,
                    "DermaLarge",
                    0,
                    yOffset,
                    line.color,
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
                
                yOffset = yOffset + 30
            end
        cam.End3D2D()
    end
end)

-- Отрисовка подсказок при наведении на дверь
hook.Add("HUDPaint", "RoleplayDrawDoorHints", function()
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    
    local trace = ply:GetEyeTrace()
    local ent = trace.Entity
    
    if not IsValid(ent) then return end
    
    -- Проверяем, является ли это дверью
    local class = ent:GetClass()
    if class ~= "prop_door_rotating" and class ~= "func_door" and class ~= "func_door_rotating" then return end
    
    local entIndex = ent:EntIndex()
    local doorData = zb.ClDoors[entIndex]
    
    if not doorData then return end
    
    -- Проверяем расстояние
    local doorPos = ent:LocalToWorld(ent:OBBCenter())
    local distance = ply:GetPos():Distance(doorPos)
    
    if distance > 150 then return end
    
    -- Определяем подсказки
    local hints = {}
    
    -- Подсказки больше не нужны, так как информация отображается на двери
    
    -- Отрисовываем подсказки
    if #hints > 0 then
        local scrW, scrH = ScrW(), ScrH()
        local x = scrW / 2
        local y = scrH / 2 + 100
        
        for i, hint in ipairs(hints) do
            draw.SimpleTextOutlined(
                hint,
                "DermaDefault",
                x,
                y + (i - 1) * 20,
                Color(200, 200, 200),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER,
                1,
                Color(0, 0, 0, 200)
            )
        end
    end
end)

-- Обработка нажатий клавиш для взаимодействия с дверями (только F2 для покупки)
local lastDoorBuyTime = 0
hook.Add("PlayerButtonDown", "RoleplayDoorInteraction", function(ply, button)
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    if not IsValid(ply) or not ply:Alive() then return end
    
    -- Обработка кнопки F2 - только покупка двери
    if button == KEY_F2 then
        -- Защита от спама (не чаще раза в секунду)
        if CurTime() - lastDoorBuyTime < 1 then return end
        
        local trace = ply:GetEyeTrace()
        local ent = trace.Entity
        
        if not IsValid(ent) then return end
        
        -- Проверяем, является ли это дверью
        local class = ent:GetClass()
        if class ~= "prop_door_rotating" and class ~= "func_door" and class ~= "func_door_rotating" then return end
        
        local entIndex = ent:EntIndex()
        local doorData = zb.ClDoors[entIndex]
        
        if not doorData then return end
        
        -- Проверяем расстояние
        local doorPos = ent:LocalToWorld(ent:OBBCenter())
        local distance = ply:GetPos():Distance(doorPos)
        
        if distance > 150 then return end
        
        if doorData.type == "buyable" and not doorData.owner then
            -- Покупка двери
            lastDoorBuyTime = CurTime()
            net.Start("zb_door_buy")
            net.WriteEntity(ent)
            net.SendToServer()
        end
    end
end)

-- Получение цветных сообщений о дверях
local lastDoorMessage = 0
net.Receive("roleplay_door_message", function()
    -- Защита от дублирования сообщений
    if CurTime() - lastDoorMessage < 0.1 then return end
    lastDoorMessage = CurTime()
    
    local msgType = net.ReadString()
    
    if msgType == "buy" then
        local price = net.ReadInt(16)
        chat.AddText(Color(100, 255, 100), "[Roleplay] ", Color(255, 255, 255), "Вы купили дверь за ", Color(100, 255, 100), price .. "$")
    elseif msgType == "buy_group" then
        local count = net.ReadInt(8)
        local price = net.ReadInt(16)
        chat.AddText(Color(100, 255, 100), "[Roleplay] ", Color(255, 255, 255), "Вы купили группу из ", Color(255, 200, 100), count .. " дверей", Color(255, 255, 255), " за ", Color(100, 255, 100), price .. "$")
    elseif msgType == "sell" then
        local refund = net.ReadInt(16)
        chat.AddText(Color(255, 100, 100), "[Roleplay] ", Color(255, 255, 255), "Вы продали дверь за ", Color(100, 255, 100), refund .. "$")
    elseif msgType == "sell_group" then
        local count = net.ReadInt(8)
        local refund = net.ReadInt(16)
        chat.AddText(Color(255, 100, 100), "[Roleplay] ", Color(255, 255, 255), "Вы продали группу из ", Color(255, 200, 100), count .. " дверей", Color(255, 255, 255), " за ", Color(100, 255, 100), refund .. "$")
    end
end)


-- Получение сообщения о сборе денег с принтера
net.Receive("roleplay_printer_collect", function()
    local money = net.ReadInt(32)
    chat.AddText(Color(100, 255, 100), "[Roleplay] ", Color(255, 255, 255), "Вы собрали ", Color(100, 255, 100), money .. "$", Color(255, 255, 255), " с принтера")
end)

-- Получение цветных сообщений о принтерах
net.Receive("roleplay_printer_message", function()
    local msgType = net.ReadString()
    
    if msgType == "buy" then
        local printerName = net.ReadString()
        local price = net.ReadInt(16)
        chat.AddText(Color(100, 200, 255), "[Roleplay] ", Color(255, 255, 255), "Вы купили ", Color(150, 220, 255), printerName, Color(255, 255, 255), " за ", Color(100, 255, 100), price .. "$")
    end
end)

-- Получение цветного сообщения о зарплате
net.Receive("roleplay_salary_message", function()
    local salary = net.ReadInt(16)
    local tax = net.ReadInt(16)
    
    if tax > 0 then
        chat.AddText(Color(255, 200, 100), "[Roleplay] ", Color(255, 255, 255), "Вы получили зарплату: ", Color(100, 255, 100), salary .. "$", Color(255, 255, 255), " (налог: ", Color(255, 100, 100), tax .. "$", Color(255, 255, 255), ")")
    else
        chat.AddText(Color(255, 200, 100), "[Roleplay] ", Color(255, 255, 255), "Вы получили зарплату: ", Color(100, 255, 100), salary .. "$")
    end
end)

-- Получение цветных сообщений об ошибках
net.Receive("roleplay_error_message", function()
    local errorText = net.ReadString()
    chat.AddText(Color(255, 100, 100), "[Roleplay] ", Color(255, 200, 200), errorText)
end)

-- Данные города
local CityTaxRate = 0
local CityTreasury = 0
local CityRules = "Правила города не установлены"

-- Синхронизация данных города
net.Receive("roleplay_sync_city_data", function()
    CityTaxRate = net.ReadInt(8)
    CityTreasury = net.ReadInt(32)
    CityRules = net.ReadString()
end)

-- Функция открытия меню мэра
local function OpenMayorMenu()
    local Frame = vgui.Create("DFrame")
    Frame:SetTitle("Управление городом")
    Frame:SetSize(600, 680)
    Frame:Center()
    Frame:MakePopup()

    -- Панель налогов
    local TaxPanel = vgui.Create("DPanel", Frame)
    TaxPanel:Dock(TOP)
    TaxPanel:SetHeight(120)
    TaxPanel:DockMargin(10, 10, 10, 5)

    TaxPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 200))
    end

    local TaxLabel = vgui.Create("DLabel", TaxPanel)
    TaxLabel:SetText("Налог на зарплату (10-50%)")
    TaxLabel:SetFont("DermaLarge")
    TaxLabel:Dock(TOP)
    TaxLabel:DockMargin(10, 10, 10, 5)
    TaxLabel:SetTextColor(Color(255, 255, 255))

    local TaxSlider = vgui.Create("DNumSlider", TaxPanel)
    TaxSlider:Dock(TOP)
    TaxSlider:DockMargin(10, 0, 10, 5)
    TaxSlider:SetMin(10)
    TaxSlider:SetMax(50)
    TaxSlider:SetDecimals(0)
    TaxSlider:SetValue(CityTaxRate)
    TaxSlider:SetText("")

    local TaxButton = vgui.Create("DButton", TaxPanel)
    TaxButton:SetText("Установить налог")
    TaxButton:Dock(TOP)
    TaxButton:DockMargin(10, 5, 10, 10)
    TaxButton:SetHeight(30)
    TaxButton.DoClick = function()
        net.Start("roleplay_set_tax")
        net.WriteInt(math.floor(TaxSlider:GetValue()), 8)
        net.SendToServer()
        chat.AddText(Color(100, 255, 100), "[Roleplay] ", Color(255, 255, 255), "Налог установлен: ", Color(255, 200, 100), math.floor(TaxSlider:GetValue()) .. "%")
    end

    -- Панель казны
    local TreasuryPanel = vgui.Create("DPanel", Frame)
    TreasuryPanel:Dock(TOP)
    TreasuryPanel:SetHeight(60)
    TreasuryPanel:DockMargin(10, 5, 10, 5)

    TreasuryPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 200))
        draw.SimpleText("Казна города: " .. CityTreasury .. "$", "DermaLarge", w / 2, h / 2, Color(100, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Панель комендантского часа (BOTTOM — добавляем ДО FILL)
    local CurfewPanel = vgui.Create("DPanel", Frame)
    CurfewPanel:Dock(BOTTOM)
    CurfewPanel:SetHeight(140)
    CurfewPanel:DockMargin(10, 5, 10, 10)

    CurfewPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 35, 10, 200))
        surface.SetDrawColor(180, 140, 20, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local CurfewTitle = vgui.Create("DLabel", CurfewPanel)
    CurfewTitle:SetText("Комендантский час (300 сек)")
    CurfewTitle:SetFont("DermaLarge")
    CurfewTitle:Dock(TOP)
    CurfewTitle:DockMargin(10, 8, 10, 4)
    CurfewTitle:SetTextColor(Color(255, 220, 80))

    local CurfewReasonEntry = vgui.Create("DTextEntry", CurfewPanel)
    CurfewReasonEntry:Dock(TOP)
    CurfewReasonEntry:DockMargin(10, 0, 10, 6)
    CurfewReasonEntry:SetHeight(28)
    CurfewReasonEntry:SetPlaceholderText("Укажите причину комендантского часа...")
    CurfewReasonEntry:SetMaximumCharCount(120)

    local CurfewBtnRow = vgui.Create("DPanel", CurfewPanel)
    CurfewBtnRow:Dock(TOP)
    CurfewBtnRow:SetHeight(40)
    CurfewBtnRow:DockMargin(10, 0, 10, 8)
    CurfewBtnRow.Paint = nil

    local DeclareBtn = vgui.Create("DButton", CurfewBtnRow)
    DeclareBtn:Dock(LEFT)
    DeclareBtn:SetWide(200)
    DeclareBtn:DockMargin(0, 0, 8, 0)
    DeclareBtn:SetText("")
    DeclareBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and Color(220, 170, 40, 255) or Color(180, 140, 20, 255)
        draw.RoundedBox(6, 0, 0, w, h, col)
        draw.SimpleText("Объявить", "DermaLarge", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    DeclareBtn.DoClick = function()
        local reason = CurfewReasonEntry:GetValue()
        if reason == "" then
            chat.AddText(Color(255, 100, 100), "[Roleplay] ", Color(255, 255, 255), "Укажите причину комендантского часа!")
            return
        end
        net.Start("roleplay_declare_curfew")
        net.WriteBool(true)
        net.WriteString(reason)
        net.SendToServer()
        Frame:Remove()
    end

    local CancelBtn = vgui.Create("DButton", CurfewBtnRow)
    CancelBtn:Dock(LEFT)
    CancelBtn:SetWide(200)
    CancelBtn:SetText("")
    CancelBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and Color(100, 80, 20, 255) or Color(70, 55, 15, 255)
        draw.RoundedBox(6, 0, 0, w, h, col)
        draw.SimpleText("Отменить", "DermaLarge", w / 2, h / 2, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    CancelBtn.DoClick = function()
        net.Start("roleplay_declare_curfew")
        net.WriteBool(false)
        net.WriteString("")
        net.SendToServer()
        Frame:Remove()
    end

    -- Панель правил (FILL — добавляем ПОСЛЕ всех BOTTOM)
    local RulesPanel = vgui.Create("DPanel", Frame)
    RulesPanel:Dock(FILL)
    RulesPanel:DockMargin(10, 5, 10, 5)

    RulesPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 200))
    end

    local RulesLabel = vgui.Create("DLabel", RulesPanel)
    RulesLabel:SetText("Правила города")
    RulesLabel:SetFont("DermaLarge")
    RulesLabel:Dock(TOP)
    RulesLabel:DockMargin(10, 10, 10, 5)
    RulesLabel:SetTextColor(Color(255, 255, 255))

    local RulesText = vgui.Create("DTextEntry", RulesPanel)
    RulesText:Dock(FILL)
    RulesText:DockMargin(10, 0, 10, 5)
    RulesText:SetMultiline(true)
    RulesText:SetValue(CityRules)

    local RulesButton = vgui.Create("DButton", RulesPanel)
    RulesButton:SetText("Установить правила")
    RulesButton:Dock(BOTTOM)
    RulesButton:DockMargin(10, 5, 10, 10)
    RulesButton:SetHeight(30)
    RulesButton.DoClick = function()
        net.Start("roleplay_set_rules")
        net.WriteString(RulesText:GetValue())
        net.SendToServer()
        chat.AddText(Color(100, 255, 100), "[Roleplay] ", Color(255, 255, 255), "Правила города обновлены")
    end
end

concommand.Add("roleplay_mayor_menu", function()
    net.Start("roleplay_mayor_menu")
    net.SendToServer()
    
    timer.Simple(0.1, function()
        OpenMayorMenu()
    end)
end)

-- Добавляем кнопку управления городом для мэра в радиальное меню (добавляется первой)
hook.Add("radialOptions", "a_roleplay_mayor", function()
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true

    local ply = LocalPlayer()
    if not ply:Alive() then return end

    local jobName = ply:GetNWString("RoleplayJob", "Гражданский")
    if jobName ~= "Мэр" then return end

    hg.radialOptions[#hg.radialOptions + 1] = {
        function()
            RunConsoleCommand("roleplay_mayor_menu")
            return 0
        end,
        "Управление\nгородом"
    }
end)

-- Добавляем кнопку ограбления казны для Главы ЦАХАЛ
hook.Add("radialOptions", "roleplay_rob_treasury", function()
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    
    local ply = LocalPlayer()
    if not ply:Alive() then return end
    
    local jobName = ply:GetNWString("RoleplayJob", "Гражданский")
    if jobName ~= "Глава ЦАХАЛ" then return end
    
    -- Проверяем расстояние до таблички казны
    local nearTreasury = false
    for _, ent in ipairs(ents.FindByClass("zb_city_text")) do
        if IsValid(ent) then
            local textType = ent:GetTextType() or ent:GetNWString("TextType", "")
            if textType == "treasury" then
                local dist = ply:GetPos():Distance(ent:GetPos())
                if dist <= 200 then -- 200 единиц = примерно 5 метров
                    nearTreasury = true
                    break
                end
            end
        end
    end
    
    -- Показываем кнопку только если рядом с казной
    if not nearTreasury then return end
    
    hg.radialOptions[#hg.radialOptions + 1] = {
        function()
            net.Start("roleplay_rob_treasury")
            net.SendToServer()
            return 0
        end,
        "Ограбить\nказну"
    }
end)

-- Обработчик цветных сообщений об ограблении
net.Receive("roleplay_colored_message", function()
    local msgType = net.ReadString()
    
    if msgType == "robbery_member" then
        local amount = net.ReadInt(32)
        chat.AddText(Color(100, 255, 100), "[Roleplay] ", Color(255, 255, 255), "Вы получили долю от ограбления казны: ", Color(100, 255, 100), amount .. "$")
    elseif msgType == "robbery_leader" then
        local amount = net.ReadInt(32)
        chat.AddText(Color(100, 255, 100), "[Roleplay] ", Color(255, 255, 255), "Вы получили от ограбления казны: ", Color(100, 255, 100), amount .. "$", Color(255, 255, 255), " (лидерская доля + общая)")
    elseif msgType == "robbery_started" then
        local playerName = net.ReadString()
        chat.AddText(Color(255, 100, 100), "[Roleplay] ", Color(255, 200, 100), playerName, Color(255, 255, 255), " начал ограбление казны города!")
    elseif msgType == "robbery_success" then
        local amount = net.ReadInt(32)
        chat.AddText(Color(100, 255, 100), "[Roleplay] ", Color(255, 255, 255), "Ограбление казны успешно завершено! Украдено: ", Color(100, 255, 100), amount .. "$")
    elseif msgType == "robbery_failed" then
        local playerName = net.ReadString()
        chat.AddText(Color(255, 100, 100), "[Roleplay] ", Color(255, 255, 255), "Ограбление провалено! ", Color(255, 200, 100), playerName, Color(255, 255, 255), " был убит!")
    end
end)

-- Переменные для прогресс-бара ограбления
local RobberyProgress = 0
local RobberyEndTime = 0
local IsRobbing = false

-- Начало ограбления
net.Receive("roleplay_robbery_start", function()
    local duration = net.ReadFloat()
    IsRobbing = true
    RobberyEndTime = CurTime() + duration
    RobberyProgress = 0
end)

-- Отмена ограбления
net.Receive("roleplay_robbery_cancel", function()
    IsRobbing = false
    RobberyProgress = 0
end)

-- Отрисовка прогресс-бара ограбления
hook.Add("HUDPaint", "DrawRobberyProgress", function()
    if not IsRobbing then return end
    
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        IsRobbing = false
        return
    end
    
    -- Обновляем прогресс
    local timeLeft = RobberyEndTime - CurTime()
    if timeLeft <= 0 then
        IsRobbing = false
        return
    end
    
    RobberyProgress = 1 - (timeLeft / 30)
    
    -- Рисуем прогресс-бар
    local scrW, scrH = ScrW(), ScrH()
    local barW, barH = 400, 40
    local barX, barY = scrW / 2 - barW / 2, scrH - 150
    
    -- Фон
    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawRect(barX - 5, barY - 5, barW + 10, barH + 10)
    
    -- Рамка
    surface.SetDrawColor(255, 100, 100, 255)
    surface.DrawOutlinedRect(barX - 5, barY - 5, barW + 10, barH + 10, 2)
    
    -- Прогресс
    surface.SetDrawColor(255, 200, 100, 255)
    surface.DrawRect(barX, barY, barW * RobberyProgress, barH)
    
    -- Текст
    draw.SimpleText("ОГРАБЛЕНИЕ КАЗНЫ", "DermaLarge", scrW / 2, barY - 30, Color(255, 200, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(math.ceil(timeLeft) .. " сек", "DermaLarge", scrW / 2, barY + barH / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)


-- Добавляем кнопку управления войной для Главы ЦАХАЛ
hook.Add("radialOptions", "roleplay_isis_war", function()
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    
    local ply = LocalPlayer()
    if not ply:Alive() then return end
    
    local jobName = ply:GetNWString("RoleplayJob", "Гражданский")
    if jobName ~= "Глава ЦАХАЛ" then return end
    
    hg.radialOptions[#hg.radialOptions + 1] = {
        function()
            RunConsoleCommand("roleplay_isis_war_menu")
            return 0
        end,
        "Управление\nвойной"
    }
end)

-- Меню управления войной
local function OpenWarMenu()
    local Frame = vgui.Create("DFrame")
    Frame:SetTitle("")
    Frame:SetSize(500, 300)
    Frame:Center()
    Frame:MakePopup()
    Frame:ShowCloseButton(false)
    
    Frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 20, 28, 245))
        surface.SetDrawColor(100, 20, 20, 200)
        surface.DrawRect(0, 0, w, 4)
        draw.SimpleText("УПРАВЛЕНИЕ ВОЙНОЙ", "DermaLarge", w / 2, 30, Color(220, 220, 230, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(100, 20, 20, 150)
        surface.DrawRect(w / 2 - 150, 50, 300, 2)
    end
    
    -- Кнопка закрытия
    local CloseBtn = vgui.Create("DButton", Frame)
    CloseBtn:SetPos(Frame:GetWide() - 45, 10)
    CloseBtn:SetSize(35, 35)
    CloseBtn:SetText("")
    CloseBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and Color(200, 50, 50, 255) or Color(80, 20, 20, 200)
        draw.RoundedBox(4, 0, 0, w, h, col)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawLine(10, 10, w - 10, h - 10)
        surface.DrawLine(w - 10, 10, 10, h - 10)
    end
    CloseBtn.DoClick = function()
        Frame:Remove()
    end
    
    -- Информационная панель
    local InfoPanel = vgui.Create("DPanel", Frame)
    InfoPanel:SetPos(20, 70)
    InfoPanel:SetSize(460, 80)
    InfoPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 42, 255))
        draw.SimpleText("Объявление войны позволяет ЦАХАЛу атаковать город", "WarInfoText", w / 2, 8, Color(220, 220, 220), TEXT_ALIGN_CENTER)
        draw.SimpleText("и мэрию без последствий. Все игроки будут уведомлены.", "WarInfoText", w / 2, 30, Color(220, 220, 220), TEXT_ALIGN_CENTER)
        draw.SimpleText("Окончание войны восстанавливает мирное время.", "WarInfoText", w / 2, 52, Color(220, 220, 220), TEXT_ALIGN_CENTER)
    end
    
    -- Кнопка объявления войны
    local DeclareBtn = vgui.Create("DButton", Frame)
    DeclareBtn:SetPos(50, 170)
    DeclareBtn:SetSize(180, 80)
    DeclareBtn:SetText("")
    DeclareBtn.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and Color(200, 50, 50, 255) or Color(150, 30, 30, 255)
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Color(255, 255, 255, 20))
        end
        draw.SimpleText("ОБЪЯВИТЬ", "DermaLarge", w / 2, h / 2 - 10, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("ВОЙНУ", "DermaLarge", w / 2, h / 2 + 15, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    DeclareBtn.DoClick = function()
        net.Start("roleplay_declare_war")
        net.WriteBool(true)
        net.SendToServer()
        Frame:Remove()
    end
    
    -- Кнопка окончания войны
    local EndBtn = vgui.Create("DButton", Frame)
    EndBtn:SetPos(270, 170)
    EndBtn:SetSize(180, 80)
    EndBtn:SetText("")
    EndBtn.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and Color(50, 200, 50, 255) or Color(30, 150, 30, 255)
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Color(255, 255, 255, 20))
        end
        draw.SimpleText("ЗАКОНЧИТЬ", "DermaLarge", w / 2, h / 2 - 10, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("ВОЙНУ", "DermaLarge", w / 2, h / 2 + 15, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    EndBtn.DoClick = function()
        net.Start("roleplay_declare_war")
        net.WriteBool(false)
        net.SendToServer()
        Frame:Remove()
    end
end

concommand.Add("roleplay_isis_war_menu", function()
    OpenWarMenu()
end)

-- Получение сообщений о войне
-- Кастомные шрифты для полоски войны
surface.CreateFont("WarTitle", {
    font = "Roboto",
    size = 32,
    weight = 800,
    antialias = true,
    shadow = true
})

surface.CreateFont("WarSubtitle", {
    font = "Roboto",
    size = 18,
    weight = 600,
    antialias = true,
    shadow = false
})

surface.CreateFont("WarTimer", {
    font = "Roboto Mono",
    size = 28,
    weight = 700,
    antialias = true,
    shadow = true
})

surface.CreateFont("WarIcon", {
    font = "Arial",
    size = 40,
    weight = 900,
    antialias = true,
    shadow = true
})

surface.CreateFont("WarInfoText", {
    font = "Roboto",
    size = 16,
    weight = 500,
    antialias = true,
    shadow = false
})

-- Получение сообщений о войне
local WarEndTime = 0

net.Receive("roleplay_war_message", function()
    local isWar = net.ReadBool()

    if isWar then
        -- Читаем оставшееся время (при синхронизации при входе) или ставим 600
        local timeLeft = net.ReadInt(32)
        if timeLeft and timeLeft > 0 then
            WarEndTime = CurTime() + timeLeft
        else
            WarEndTime = CurTime() + 600
        end

        -- Сообщение в чат только если это новое объявление войны (не синхронизация)
        if timeLeft >= 590 then
            -- Верхняя линия
            chat.AddText(Color(255, 50, 50), "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            chat.AddText(
                Color(255, 100, 100), "[ВОЙНА] ",
                Color(255, 255, 255), "Глава ЦАХАЛ объявил войну городу! Все граждане в опасности!"
            )
            chat.AddText(Color(255, 50, 50), "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            surface.PlaySound("ambient/alarms/warningbell1.wav")
        end
    else
        -- Сбрасываем таймер войны
        WarEndTime = 0
        
        if victoryType == "isis_victory" then
            -- Победа ЦАХАЛ
            chat.AddText(Color(255, 100, 100), "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            chat.AddText(
                Color(255, 100, 100), "[ВОЙНА] ",
                Color(255, 255, 255), "Мэр убит! ",
                Color(255, 150, 100), "ЦАХАЛ победил войну!"
            )
            chat.AddText(Color(255, 100, 100), "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            
            -- Звуковое оповещение
            surface.PlaySound("ambient/alarms/warningbell1.wav")
        else
            -- Обычное окончание войны
            chat.AddText(Color(100, 255, 100), "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            chat.AddText(
                Color(100, 255, 100), "[МИР] ",
                Color(255, 255, 255), "Война окончена! Город возвращается к мирной жизни."
            )
            chat.AddText(Color(100, 255, 100), "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            
            -- Звуковое оповещение
            surface.PlaySound("buttons/button14.wav")
        end
    end
end)

-- Отображение полоски войны сверху экрана
hook.Add("HUDPaint", "RoleplayWarBar", function()
    if not CurrentRound then return end
    local round = ZCity_RP -- [ZCITY_PORT]
    
    -- Проверяем, идет ли война
    if WarEndTime <= CurTime() then return end
    
    local scrW, scrH = ScrW(), ScrH()
    local barHeight = 70
    local timeLeft = math.max(0, WarEndTime - CurTime())
    local minutes = math.floor(timeLeft / 60)
    local seconds = math.floor(timeLeft % 60)
    
    -- Пульсирующий эффект для фона
    local pulse = math.abs(math.sin(CurTime() * 2)) * 30
    
    -- Основной фон полоски с градиентом
    draw.RoundedBox(0, 0, 0, scrW, barHeight, Color(150 + pulse, 20, 20, 250))
    
    -- Верхняя темная полоса для глубины
    draw.RoundedBox(0, 0, 0, scrW, 3, Color(80, 10, 10, 255))
    
    -- Темная полоса снизу для глубины
    draw.RoundedBox(0, 0, barHeight - 5, scrW, 5, Color(100, 10, 10, 255))
    
    -- Анимированная полоса прогресса
    local progressWidth = (timeLeft / 600) * scrW
    draw.RoundedBox(0, 0, barHeight - 5, progressWidth, 5, Color(255, 100, 100, 255))
    
    -- Иконка предупреждения (мигающий треугольник)
    local iconAlpha = 200 + math.abs(math.sin(CurTime() * 3)) * 55
    draw.SimpleText("⚠", "WarIcon", 45, barHeight / 2 - 3, Color(255, 255, 100, iconAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    -- Текст "ВОЙНА"
    draw.SimpleText("ВОЙНА", "WarTitle", 85, barHeight / 2 - 12, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    
    -- Описание
    draw.SimpleText("ЦАХАЛ атакует город!", "WarSubtitle", 85, barHeight / 2 + 12, Color(255, 220, 220, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    
    -- Таймер справа
    local timerText = string.format("До конца: %02d:%02d", minutes, seconds)
    draw.SimpleText(timerText, "WarTimer", scrW - 50, barHeight / 2, Color(255, 255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    
    -- Мигающая точка рядом с таймером
    local dotAlpha = 100 + math.abs(math.sin(CurTime() * 4)) * 155
    draw.SimpleText("●", "WarIcon", scrW - 270, barHeight / 2 - 3, Color(255, 50, 50, dotAlpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)



-- ============================================
-- СИСТЕМА КОМЕНДАНТСКОГО ЧАСА (клиент)
-- ============================================

local CurfewEndTime = 0
local CurfewReason  = ""

net.Receive("roleplay_curfew_message", function()
    local isCurfew = net.ReadBool()
    local timeLeft = net.ReadInt(32)
    local reason   = net.ReadString()

    if isCurfew then
        CurfewReason = reason
        if timeLeft and timeLeft > 0 then
            CurfewEndTime = CurTime() + timeLeft
        else
            CurfewEndTime = CurTime() + 300
        end

        -- Объявление только при новом комендантском часе (не синхронизация)
        if timeLeft >= 295 then
            chat.AddText(Color(200, 160, 60), "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            chat.AddText(
                Color(255, 200, 80), "[КОМЕНДАНТСКИЙ ЧАС] ",
                Color(255, 255, 255), "Мэр объявил комендантский час!"
            )
            chat.AddText(
                Color(200, 200, 200), "Причина: ",
                Color(255, 220, 120), reason
            )
            chat.AddText(Color(200, 160, 60), "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            surface.PlaySound("ambient/alarms/klaxon1.wav")
        end
    else
        -- Окончание комендантского часа
        if CurfewEndTime > 0 then
            chat.AddText(Color(100, 200, 100), "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            if reason == "mayor_died" then
                chat.AddText(
                    Color(255, 200, 80), "[КОМЕНДАНТСКИЙ ЧАС] ",
                    Color(255, 255, 255), "Мэр убит — комендантский час снят."
                )
            elseif reason == "mayor_disconnected" then
                chat.AddText(
                    Color(255, 200, 80), "[КОМЕНДАНТСКИЙ ЧАС] ",
                    Color(255, 255, 255), "Мэр покинул сервер — комендантский час снят."
                )
            elseif reason == "mayor_spectator" then
                chat.AddText(
                    Color(255, 200, 80), "[КОМЕНДАНТСКИЙ ЧАС] ",
                    Color(255, 255, 255), "Мэр перешёл в наблюдатели — комендантский час снят."
                )
            elseif reason == "mayor_job_changed" then
                chat.AddText(
                    Color(255, 200, 80), "[КОМЕНДАНТСКИЙ ЧАС] ",
                    Color(255, 255, 255), "Мэр сменил профессию — комендантский час снят."
                )
            elseif reason == "cancel_by_mayor" then
                chat.AddText(
                    Color(100, 220, 100), "[КОМЕНДАНТСКИЙ ЧАС] ",
                    Color(255, 255, 255), "Мэр отменил комендантский час."
                )
            else
                chat.AddText(
                    Color(100, 220, 100), "[КОМЕНДАНТСКИЙ ЧАС] ",
                    Color(255, 255, 255), "Комендантский час завершён. Можно выходить на улицу."
                )
            end

            chat.AddText(Color(100, 200, 100), "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            surface.PlaySound("buttons/button14.wav")
        end
        CurfewEndTime = 0
        CurfewReason  = ""
    end
end)

-- Полоска комендантского часа (под полоской войны, если она есть)
hook.Add("HUDPaint", "RoleplayCurfewBar", function()
    if not CurrentRound then return end
    local round = ZCity_RP -- [ZCITY_PORT]

    if CurfewEndTime <= CurTime() then return end

    local scrW = ScrW()
    local barHeight = 60
    -- Смещаем вниз, если идёт война
    local offsetY = (WarEndTime > CurTime()) and 70 or 0

    local timeLeft = math.max(0, CurfewEndTime - CurTime())
    local minutes  = math.floor(timeLeft / 60)
    local seconds  = math.floor(timeLeft % 60)

    local pulse = math.abs(math.sin(CurTime() * 1.5)) * 20

    -- Фон
    draw.RoundedBox(0, 0, offsetY, scrW, barHeight, Color(180 + pulse, 140, 20, 240))
    draw.RoundedBox(0, 0, offsetY, scrW, 3, Color(100, 80, 10, 255))
    draw.RoundedBox(0, 0, offsetY + barHeight - 4, scrW, 4, Color(120, 90, 10, 255))

    -- Прогресс-бар
    local progressWidth = (timeLeft / 300) * scrW
    draw.RoundedBox(0, 0, offsetY + barHeight - 4, progressWidth, 4, Color(255, 220, 80, 255))

    -- Иконка
    local iconAlpha = 200 + math.abs(math.sin(CurTime() * 2.5)) * 55
    draw.SimpleText("!", "WarIcon", 40, offsetY + barHeight / 2 - 3, Color(255, 240, 100, iconAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Заголовок
    draw.SimpleText("КОМЕНДАНТСКИЙ ЧАС", "WarTitle", 80, offsetY + barHeight / 2 - 12, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Причина (обрезаем если длинная)
    local reasonDisplay = CurfewReason ~= "" and ("Причина: " .. CurfewReason) or ""
    if #reasonDisplay > 60 then reasonDisplay = string.sub(reasonDisplay, 1, 57) .. "..." end
    draw.SimpleText(reasonDisplay, "WarSubtitle", 80, offsetY + barHeight / 2 + 12, Color(255, 240, 180, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Таймер
    local timerText = string.format("До конца: %02d:%02d", minutes, seconds)
    draw.SimpleText(timerText, "WarTimer", scrW - 50, offsetY + barHeight / 2, Color(255, 255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)

-- ============================================
-- МАГАЗИН ПРОДАВЦА ОРУЖИЯ (F3) — см. cl_gundealer.lua
-- ============================================

-- ============================================
-- F3 — КУРСОР ДЛЯ ВСЕХ
-- ============================================
-- PlayerBindPress (не input.IsKeyDown!): после gui.EnableScreenClicker(true)
-- ввод уходит к Derma и Think-хуки уже не видят нажатий F3 — курсор не закрывался.
-- PlayerBindPress срабатывает на bind независимо от фокуса мыши.

local rpCursorEnabled = false

local function rpSetCursor(state)
    rpCursorEnabled = state and true or false
    gui.EnableScreenClicker(rpCursorEnabled)
    -- Уведомляем подписчиков (Elysium chat panels и т.п.), чтобы они
    -- синхронизировали свой SetMouseInputEnabled/SetKeyboardInputEnabled.
    -- Без этого MakePopup-panel держит мышь захваченной и F3 не освобождает курсор.
    hook.Run("RoleplayCursorChanged", rpCursorEnabled)
end

-- Глобальные геттер/сеттер — Elysium и другие аддоны опрашивают/меняют курсор
-- через них, чтобы единственный источник правды о курсоре оставался в RP.
function _G.RP_IsCursorEnabled() return rpCursorEnabled end
function _G.RP_SetCursor(state) rpSetCursor(state) end

-- [ZCITY_PORT] было: проверка `not CurrentRound` (глобал старого gamemode,
-- которого на DarkRP нет) + `ZCity_RP.name ~= "roleplay"`. Это блокировало F3
-- toggle на DarkRP — курсор Elysium-reports и других модулей включался через
-- MakePopup, но F3 не мог его освободить.
hook.Add("PlayerBindPress", "RoleplayF3Cursor", function(ply, bind, pressed)
    if not pressed then return end
    if bind ~= "gm_showspare1" then return end
    rpSetCursor(not rpCursorEnabled)
    return true -- блокируем стандартное поведение F3
end)

-- [ZCITY_PORT] Think-хук RoleplayF3CursorReset УДАЛЁН: на DarkRP мы всегда
-- в RP, отдельный "сброс при выходе из раунда" не нужен. Хук сбивал курсор
-- модалок Elysium из-за `not CurrentRound`-условия, которое на DarkRP всегда
-- истинно.

hook.Add("OnPlayerChat", "RoleplayF3CursorChat", function()
    if rpCursorEnabled then rpSetCursor(false) end
end)

