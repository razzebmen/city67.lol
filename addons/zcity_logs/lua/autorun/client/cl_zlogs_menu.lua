--[[
    ZCity Logs — клиентское меню.
    Стиль: RP-тема (тёмно-синий фон + красная шапка).
]]

if not ZLogs then
    include("autorun/sh_zlogs.lua")
end

ZLogs.Menu       = ZLogs.Menu or {}
ZLogs.Menu.State = ZLogs.Menu.State or {
    cat       = nil,          -- активная категория ("kill", nil = все)
    search    = "",
    sid       = nil,          -- фильтр по SteamID
    sid_label = nil,          -- ник для отображения чипа
    page      = 1,
    total     = 0,
    page_size = ZLogs.PAGE_SIZE,
    rows      = {},
    loading   = false,
    reqId     = 0,
    live      = false,
}

-- ============================================
-- ЗАПРОС ДАННЫХ
-- ============================================

function ZLogs.Menu.RequestPage()
    local st = ZLogs.Menu.State
    st.loading = true
    st.reqId   = (st.reqId or 0) + 1

    local payload = util.TableToJSON({
        cat       = st.cat,
        sid       = st.sid,
        search    = st.search ~= "" and st.search or nil,
        page      = st.page,
        page_size = st.page_size,
        reqId     = st.reqId,
    })
    local compressed = util.Compress(payload)
    local len = #compressed

    net.Start("zlogs_query")
    net.WriteUInt(len, 24)
    net.WriteData(compressed, len)
    net.SendToServer()
end

local RequestPage = ZLogs.Menu.RequestPage

net.Receive("zlogs_page", function()
    local len = net.ReadUInt(24)
    local data = net.ReadData(len)
    local decompressed = util.Decompress(data)
    if not decompressed then return end
    local result = util.JSONToTable(decompressed)
    if type(result) ~= "table" then return end

    local st = ZLogs.Menu.State
    -- Игнорим устаревшие ответы
    if result.reqId and st.reqId and result.reqId < st.reqId then return end

    st.rows    = result.rows or {}
    st.total   = tonumber(result.total) or 0
    st.page    = tonumber(result.page) or 1
    st.loading = false

    if ZLogs.Menu.Frame and ZLogs.Menu.Frame.OnDataReceived then
        ZLogs.Menu.Frame:OnDataReceived()
    end
end)

-- ============================================
-- ВСПОМОГАТЕЛЬНЫЕ ВЫЧИСЛЕНИЯ
-- ============================================

local function TotalPages()
    local st = ZLogs.Menu.State
    if st.total <= 0 then return 1 end
    return math.max(1, math.ceil(st.total / st.page_size))
end

local function CatColor(cat)
    local c = ZLogs.Categories[cat]
    return c and c.color or ZLogs.Theme.Text
end

local function CatName(cat)
    local c = ZLogs.Categories[cat]
    return c and c.name or cat or "?"
end

-- ============================================
-- ГЛАВНЫЙ ФРЕЙМ
-- ============================================

local function CreateMenu()
    if IsValid(ZLogs.Menu.Frame) then
        ZLogs.Menu.Frame:Remove()
    end

    local sw, sh = ScrW(), ScrH()
    local w, h   = math.min(1200, sw - 40), math.min(720, sh - 60)

    local frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(true)
    frame:MakePopup()
    ZLogs.Menu.Frame = frame

    -- ОТРИСОВКА ФРЕЙМА
    frame.Paint = function(self, pw, ph)
        -- Основной фон
        surface.SetDrawColor(ZLogs.Theme.BgDeep)
        surface.DrawRect(0, 0, pw, ph)
        -- Шапка — почти чёрная
        surface.SetDrawColor(ZLogs.Theme.Header)
        surface.DrawRect(0, 0, pw, 48)
        -- Жёсткая красная акцент-полоса под шапкой
        surface.SetDrawColor(ZLogs.Theme.Accent)
        surface.DrawRect(0, 46, pw, 3)
        -- Внешняя рамка
        ZLogs.DrawBorder(0, 0, pw, ph, ZLogs.Theme.Border, 1)
        -- Заголовок: "CITY 67" выделен красным, остальное приглушённо
        surface.SetFont("ZLogs.Header")
        local titleA = "CITY 67"
        local titleB = "  ЛОГИ СЕРВЕРА"
        local wA = surface.GetTextSize(titleA)
        draw.SimpleText(titleA, "ZLogs.Header",
            16, 24, ZLogs.Theme.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(titleB, "ZLogs.Header",
            16 + wA, 24, Color(145, 145, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        -- Версия справа
        draw.SimpleText("v" .. (ZLogs.VERSION or "?"), "ZLogs.Small",
            pw - 50, 24, Color(80, 80, 95), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- КНОПКА ЗАКРЫТЬ
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(40, 40)
    closeBtn:SetPos(w - 44, 4)
    closeBtn:SetText("")
    closeBtn.Paint = function(self, pw, ph)
        local clr = self:IsHovered() and Color(255, 100, 100) or Color(255, 200, 200)
        draw.SimpleText("✕", "ZLogs.Header", pw / 2, ph / 2,
            clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() frame:Remove() end

    -- ============================================
    -- БОКОВАЯ ПАНЕЛЬ КАТЕГОРИЙ
    -- ============================================
    local sidebar = vgui.Create("DPanel", frame)
    sidebar:SetPos(8, 56)
    sidebar:SetSize(180, h - 64)
    sidebar.Paint = function(self, pw, ph)
        ZLogs.DrawPanel(0, 0, pw, ph, ZLogs.Theme.BgPanel)
        ZLogs.DrawBorder(0, 0, pw, ph, ZLogs.Theme.Border)
    end

    -- Заголовок боковой панели
    local sbHeader = vgui.Create("DLabel", sidebar)
    sbHeader:SetPos(12, 8)
    sbHeader:SetSize(160, 22)
    sbHeader:SetFont("ZLogs.Title")
    sbHeader:SetText("КАТЕГОРИИ")
    sbHeader:SetTextColor(ZLogs.Theme.Text)

    -- Скролл со списком категорий
    local catScroll = vgui.Create("DScrollPanel", sidebar)
    catScroll:SetPos(6, 36)
    catScroll:SetSize(168, h - 110)

    local function makeCatButton(parent, code, name, color)
        local btn = vgui.Create("DButton", parent)
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 4)
        btn:SetTall(30)
        btn:SetText("")
        btn.Paint = function(self, pw, ph)
            local active = (ZLogs.Menu.State.cat == code)
            local hovered = self:IsHovered()
            ZLogs.DrawChip(0, 0, pw, ph, color, active or hovered)
            local txtClr
            if active then
                txtClr = Color(255, 255, 255)
            elseif hovered then
                txtClr = Color(210, 210, 220)
            else
                txtClr = ZLogs.Theme.TextDim
            end
            draw.SimpleText(name, active and "ZLogs.TextBold" or "ZLogs.Text",
                12, ph / 2, txtClr, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            ZLogs.Menu.State.cat  = code
            ZLogs.Menu.State.page = 1
            RequestPage()
        end
        return btn
    end

    -- Кнопка "Все"
    makeCatButton(catScroll, nil, "Все категории", Color(130, 130, 150))

    -- Категории в порядке ZLogs.CategoryOrder
    for _, code in ipairs(ZLogs.CategoryOrder) do
        local cat = ZLogs.Categories[code]
        if cat then
            makeCatButton(catScroll, code, cat.name, cat.color)
        end
    end

    -- Live toggle внизу боковой
    local liveBtn = vgui.Create("DButton", sidebar)
    liveBtn:SetPos(8, h - 100)
    liveBtn:SetSize(164, 28)
    liveBtn:SetText("")
    liveBtn.Paint = function(self, pw, ph)
        local on = ZLogs.Menu.State.live
        local bg = on and ZLogs.Theme.Success or Color(60, 70, 90, 200)
        draw.RoundedBox(4, 0, 0, pw, ph, bg)
        draw.SimpleText(on and "● LIVE (вкл)" or "○ LIVE (выкл)",
            "ZLogs.TextBold", pw / 2, ph / 2,
            Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    liveBtn.DoClick = function()
        ZLogs.Menu.State.live = not ZLogs.Menu.State.live
        RunConsoleCommand("zlogs_live", ZLogs.Menu.State.live and "1" or "0")
    end

    -- ============================================
    -- ПРАВАЯ ОБЛАСТЬ: ТУЛБАР + ТАБЛИЦА + ПАГИНАЦИЯ
    -- ============================================
    local right = vgui.Create("DPanel", frame)
    right:SetPos(196, 56)
    right:SetSize(w - 204, h - 64)
    right.Paint = function() end

    -- Тулбар
    local toolbar = vgui.Create("DPanel", right)
    toolbar:Dock(TOP)
    toolbar:SetTall(40)
    toolbar:DockMargin(0, 0, 0, 6)
    toolbar.Paint = function(self, pw, ph)
        ZLogs.DrawPanel(0, 0, pw, ph, ZLogs.Theme.BgPanel)
        ZLogs.DrawBorder(0, 0, pw, ph, ZLogs.Theme.Border)
    end

    -- Поиск
    local search = vgui.Create("DTextEntry", toolbar)
    search:SetPos(10, 8)
    search:SetSize(280, 24)
    search:SetFont("ZLogs.Text")
    search:SetPlaceholderText("Поиск по тексту, нику или SteamID...")
    search:SetTextColor(ZLogs.Theme.Text)
    search:SetUpdateOnType(false)
    search.Paint = function(self, pw, ph)
        ZLogs.DrawPanel(0, 0, pw, ph, ZLogs.Theme.BgDeep)
        ZLogs.DrawBorder(0, 0, pw, ph, ZLogs.Theme.AccentSoft)
        self:DrawTextEntryText(ZLogs.Theme.Text, ZLogs.Theme.Accent, ZLogs.Theme.Text)
    end
    search.OnEnter = function(self)
        ZLogs.Menu.State.search = self:GetValue()
        ZLogs.Menu.State.page   = 1
        RequestPage()
    end

    -- Чип фильтра по игроку (если выставлен)
    local plyChip = vgui.Create("DButton", toolbar)
    plyChip:SetPos(300, 8)
    plyChip:SetSize(280, 24)
    plyChip:SetText("")
    plyChip.Paint = function(self, pw, ph)
        local st = ZLogs.Menu.State
        if not st.sid then
            self:SetVisible(false)
            return
        end
        self:SetVisible(true)
        draw.RoundedBox(4, 0, 0, pw, ph, ZLogs.Theme.AccentSoft)
        local label = "Игрок: " .. (st.sid_label or "?") .. " (✕ снять)"
        draw.SimpleText(label, "ZLogs.Text", 8, ph / 2,
            Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    plyChip.DoClick = function()
        ZLogs.Menu.State.sid       = nil
        ZLogs.Menu.State.sid_label = nil
        ZLogs.Menu.State.page      = 1
        RequestPage()
    end

    -- Информация о количестве (справа)
    local info = vgui.Create("DLabel", toolbar)
    info:SetPos(w - 540, 8)
    info:SetSize(200, 24)
    info:SetFont("ZLogs.Small")
    info:SetTextColor(ZLogs.Theme.TextDim)
    info.Think = function(self)
        local st = ZLogs.Menu.State
        self:SetText("Всего: " .. st.total .. "   Страница: " .. st.page .. "/" .. TotalPages())
        self:SizeToContents()
        self:SetPos(right:GetWide() - self:GetWide() - 12, 8)
    end

    -- ============================================
    -- ТАБЛИЦА ЛОГОВ
    -- ============================================
    local tableBg = vgui.Create("DPanel", right)
    tableBg:Dock(FILL)
    tableBg:DockMargin(0, 0, 0, 6)
    tableBg.Paint = function(self, pw, ph)
        ZLogs.DrawPanel(0, 0, pw, ph, ZLogs.Theme.BgPanel)
        ZLogs.DrawBorder(0, 0, pw, ph, ZLogs.Theme.Border)
    end

    -- Заголовки колонок
    local header = vgui.Create("DPanel", tableBg)
    header:Dock(TOP)
    header:SetTall(26)
    header:DockMargin(8, 8, 8, 0)
    header.Paint = function(self, pw, ph)
        surface.SetDrawColor(ZLogs.Theme.BgDeep)
        surface.DrawRect(0, 0, pw, ph)
        draw.SimpleText("ВРЕМЯ",     "ZLogs.Small",   8,   ph / 2, ZLogs.Theme.TextDim, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)
        draw.SimpleText("КАТЕГ.",    "ZLogs.Small",   150, ph / 2, ZLogs.Theme.TextDim, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)
        draw.SimpleText("СОБЫТИЕ",   "ZLogs.Small",   240, ph / 2, ZLogs.Theme.TextDim, TEXT_ALIGN_LEFT,   TEXT_ALIGN_CENTER)
    end

    -- Скролл-панель строк
    local list = vgui.Create("DScrollPanel", tableBg)
    list:Dock(FILL)
    list:DockMargin(8, 4, 8, 8)

    -- Стилизация скроллбара
    local sbar = list:GetVBar()
    if IsValid(sbar) then
        sbar:SetWide(8)
        sbar.Paint = function(self, pw, ph)
            surface.SetDrawColor(20, 28, 50, 200)
            surface.DrawRect(0, 0, pw, ph)
        end
        sbar.btnUp.Paint   = function() end
        sbar.btnDown.Paint = function() end
        sbar.btnGrip.Paint = function(self, pw, ph)
            draw.RoundedBox(2, 1, 0, pw - 2, ph, ZLogs.Theme.AccentSoft)
        end
    end

    -- ============================================
    -- ПАГИНАЦИЯ
    -- ============================================
    local pager = vgui.Create("DPanel", right)
    pager:Dock(BOTTOM)
    pager:SetTall(36)
    pager.Paint = function(self, pw, ph)
        ZLogs.DrawPanel(0, 0, pw, ph, ZLogs.Theme.BgPanel)
        ZLogs.DrawBorder(0, 0, pw, ph, ZLogs.Theme.Border)
    end

    local function makePagerBtn(text, x, w, fn)
        local b = vgui.Create("DButton", pager)
        b:SetPos(x, 6)
        b:SetSize(w, 24)
        b:SetText("")
        b.Paint = function(self, pw, ph)
            local bg = self:IsHovered() and ZLogs.Theme.AccentSoft or Color(28, 28, 36, 220)
            draw.RoundedBox(2, 0, 0, pw, ph, bg)
            local clr = self:IsHovered() and Color(255, 200, 200) or Color(175, 175, 185)
            draw.SimpleText(text, "ZLogs.TextBold", pw / 2, ph / 2,
                clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = fn
        return b
    end

    local firstBtn = makePagerBtn("|<", 10, 36, function()
        ZLogs.Menu.State.page = 1
        RequestPage()
    end)
    local prevBtn  = makePagerBtn("<", 50, 36, function()
        ZLogs.Menu.State.page = math.max(1, ZLogs.Menu.State.page - 1)
        RequestPage()
    end)
    local pageLabel = vgui.Create("DLabel", pager)
    pageLabel:SetPos(94, 6)
    pageLabel:SetSize(120, 24)
    pageLabel:SetFont("ZLogs.TextBold")
    pageLabel:SetContentAlignment(5)
    pageLabel:SetTextColor(ZLogs.Theme.Text)
    pageLabel.Think = function(self)
        local st = ZLogs.Menu.State
        self:SetText("Стр " .. st.page .. " / " .. TotalPages())
    end
    local nextBtn = makePagerBtn(">", 218, 36, function()
        ZLogs.Menu.State.page = math.min(TotalPages(), ZLogs.Menu.State.page + 1)
        RequestPage()
    end)
    local lastBtn = makePagerBtn(">|", 258, 36, function()
        ZLogs.Menu.State.page = TotalPages()
        RequestPage()
    end)

    -- Кнопка "Обновить"
    local refreshBtn = vgui.Create("DButton", pager)
    refreshBtn:SetSize(120, 24)
    refreshBtn:SetText("")
    refreshBtn.Paint = function(self, pw, ph)
        local bg = self:IsHovered() and ZLogs.Theme.Accent or ZLogs.Theme.AccentSoft
        draw.RoundedBox(4, 0, 0, pw, ph, bg)
        draw.SimpleText("Обновить", "ZLogs.TextBold", pw / 2, ph / 2,
            Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    refreshBtn.DoClick = function() RequestPage() end
    refreshBtn.Think = function(self)
        self:SetPos(pager:GetWide() - 130, 6)
    end

    -- ============================================
    -- ОБНОВЛЕНИЕ ТАБЛИЦЫ ПРИ ПОЛУЧЕНИИ ДАННЫХ
    -- ============================================
    frame.OnDataReceived = function(self)
        list:Clear()

        local st = ZLogs.Menu.State
        if #st.rows == 0 then
            local empty = vgui.Create("DLabel", list)
            empty:Dock(TOP)
            empty:DockMargin(0, 20, 0, 0)
            empty:SetTall(40)
            empty:SetFont("ZLogs.Title")
            empty:SetContentAlignment(5)
            empty:SetText(st.loading and "Загрузка..." or "Логов не найдено")
            empty:SetTextColor(ZLogs.Theme.TextDim)
            return
        end

        for i, row in ipairs(st.rows) do
            local rowPanel = vgui.Create("DPanel", list)
            rowPanel:Dock(TOP)
            rowPanel:SetTall(28)
            rowPanel:DockMargin(0, 0, 0, 2)
            rowPanel:SetCursor("hand")

            local isAlt = (i % 2 == 0)
            local hover = false

            rowPanel.Paint = function(self, pw, ph)
                local bg
                if hover then bg = ZLogs.Theme.BgRowHover
                elseif isAlt then bg = ZLogs.Theme.BgRowAlt
                else bg = ZLogs.Theme.BgRow end
                surface.SetDrawColor(bg)
                surface.DrawRect(0, 0, pw, ph)

                -- Цветная полоска слева — цвет категории
                local cc = CatColor(row.cat)
                surface.SetDrawColor(cc)
                surface.DrawRect(0, 0, 3, ph)

                -- ВРЕМЯ
                local ts = tonumber(row.ts) or 0
                draw.SimpleText(ZLogs.FormatTime(ts), "ZLogs.Small",
                    8, ph / 2, ZLogs.Theme.TextTime, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                -- КАТЕГОРИЯ
                draw.SimpleText(CatName(row.cat), "ZLogs.TextBold",
                    150, ph / 2, cc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                -- ТЕКСТ ЛОГА
                draw.SimpleText(row.txt or "", "ZLogs.Text",
                    240, ph / 2, ZLogs.Theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            rowPanel.OnCursorEntered = function() hover = true  end
            rowPanel.OnCursorExited  = function() hover = false end

            -- ПКМ — контекстное меню (хук в cl_zlogs_contextmenu.lua)
            rowPanel.OnMouseReleased = function(self, key)
                if key == MOUSE_RIGHT then
                    if ZLogs.OpenContextMenu then
                        ZLogs.OpenContextMenu(row)
                    end
                end
            end
        end
    end

    -- Первый запрос
    RequestPage()
end

-- Публичный API
function ZLogs.OpenMenu()
    CreateMenu()
end

-- Live: получение бродкастов от сервера
net.Receive("zlogs_live", function()
    local len = net.ReadUInt(24)
    local data = net.ReadData(len)
    local decompressed = util.Decompress(data)
    if not decompressed then return end
    local entry = util.JSONToTable(decompressed)
    if type(entry) ~= "table" then return end

    -- Если меню открыто и первая страница без фильтров — пушим запись наверх
    if IsValid(ZLogs.Menu.Frame) and ZLogs.Menu.State.page == 1 then
        local row = {
            ts          = entry.ts,
            cat         = entry.cat,
            sid         = entry.sid,
            nick        = entry.nick,
            txt         = entry.text,
        }
        table.insert(ZLogs.Menu.State.rows, 1, row)
        if #ZLogs.Menu.State.rows > ZLogs.Menu.State.page_size then
            table.remove(ZLogs.Menu.State.rows)
        end
        ZLogs.Menu.State.total = ZLogs.Menu.State.total + 1
        if ZLogs.Menu.Frame.OnDataReceived then
            ZLogs.Menu.Frame:OnDataReceived()
        end
    end

    -- Чат-нотификация при live
    if ZLogs.Menu.State.live then
        local cc = CatColor(entry.cat)
        chat.AddText(cc, "[" .. CatName(entry.cat) .. "] ",
            ZLogs.Theme.Text, entry.text)
    end
end)
