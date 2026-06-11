--[[
    ZCity Logs — контекстное меню (ПКМ) на строке лога.

    Возможности:
      • Копировать SteamID игрока (инициатор / цель)
      • Копировать SteamID64 (для ссылок)
      • Копировать ник
      • Копировать весь лог
      • Открыть Steam-профиль (gui.OpenURL)
      • Фильтр по этому игроку (показать все его логи)
      • Очистить фильтр игрока
]]

if not ZLogs then return end

-- Утилита: показать всплывающий toast в верхнем правом углу
local toastStack = {}
local function showToast(text, color)
    local toast = {
        text  = text,
        color = color or ZLogs.Theme.Success,
        ts    = SysTime(),
    }
    table.insert(toastStack, 1, toast)
    if #toastStack > 4 then table.remove(toastStack) end
end

hook.Add("HUDPaint", "zlogs_toasts", function()
    if #toastStack == 0 then return end
    local now = SysTime()
    local y = 80
    for i = #toastStack, 1, -1 do
        local t = toastStack[i]
        local age = now - t.ts
        if age > 3 then
            table.remove(toastStack, i)
        else
            local alpha = 255
            if age > 2.5 then alpha = math.floor((3 - age) * 510) end
            surface.SetFont("ZLogs.TextBold")
            local tw = surface.GetTextSize(t.text)
            local x = ScrW() - tw - 40
            local bg = Color(20, 28, 50, math.floor(alpha * 0.9))
            draw.RoundedBox(4, x - 12, y - 6, tw + 24, 28, bg)
            local accent = Color(t.color.r, t.color.g, t.color.b, alpha)
            surface.SetDrawColor(accent)
            surface.DrawRect(x - 12, y - 6, 3, 28)
            local txtClr = Color(255, 255, 255, alpha)
            draw.SimpleText(t.text, "ZLogs.TextBold", x, y + 8, txtClr,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            y = y + 34
        end
    end
end)

-- Утилита: копировать в буфер обмена с уведомлением
local function copyToClipboard(value, label)
    if not value or value == "" then
        showToast("Значение пустое", ZLogs.Theme.Error)
        return
    end
    SetClipboardText(value)
    showToast("Скопировано: " .. label, ZLogs.Theme.Success)
end

-- Открыть Steam-профиль
local function openSteamProfile(sid)
    if not sid or sid == "" then
        showToast("Нет SteamID", ZLogs.Theme.Error)
        return
    end
    local sid64 = ZLogs.SID64(sid)
    if sid64 == "" then
        showToast("Не удалось преобразовать SteamID", ZLogs.Theme.Error)
        return
    end
    gui.OpenURL("https://steamcommunity.com/profiles/" .. sid64)
end

-- Применить фильтр по игроку
local function filterByPlayer(sid, nick)
    if not sid or sid == "" then return end
    ZLogs.Menu.State.sid       = sid
    ZLogs.Menu.State.sid_label = nick or sid
    ZLogs.Menu.State.page      = 1

    -- Перезагрузить страницу
    if ZLogs.Menu.RequestPage then
        ZLogs.Menu.RequestPage()
    else
        -- Триггерим перерисовку: эмулируем клик на категорию
        net.Start("zlogs_query")
        local payload = util.TableToJSON({
            cat       = ZLogs.Menu.State.cat,
            sid       = sid,
            search    = ZLogs.Menu.State.search ~= "" and ZLogs.Menu.State.search or nil,
            page      = 1,
            page_size = ZLogs.Menu.State.page_size,
            reqId     = (ZLogs.Menu.State.reqId or 0) + 1,
        })
        local compressed = util.Compress(payload)
        net.WriteUInt(#compressed, 24)
        net.WriteData(compressed, #compressed)
        net.SendToServer()
    end
    showToast("Фильтр: " .. (nick or sid), ZLogs.Theme.Accent)
end

-- ============================================
-- ОТКРЫТИЕ КОНТЕКСТНОГО МЕНЮ
-- ============================================
function ZLogs.OpenContextMenu(row)
    if not row then return end

    local menu = DermaMenu()

    -- Стилизация
    menu.Paint = function(self, w, h)
        surface.SetDrawColor(ZLogs.Theme.BgPanel)
        surface.DrawRect(0, 0, w, h)
        ZLogs.DrawBorder(0, 0, w, h, ZLogs.Theme.AccentSoft)
    end

    -- Заголовок (категория)
    -- DMenu:AddPanel() не возвращает панель — создаём отдельно
    local title = vgui.Create("DPanel")
    menu:AddPanel(title)
    title:SetTall(28)
    title.Paint = function(self, w, h)
        local cc = ZLogs.Categories[row.cat] and ZLogs.Categories[row.cat].color or ZLogs.Theme.Text
        surface.SetDrawColor(ZLogs.Theme.BgDeep)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(cc)
        surface.DrawRect(0, 0, 3, h)
        local nm = (ZLogs.Categories[row.cat] and ZLogs.Categories[row.cat].name) or row.cat or "?"
        draw.SimpleText(nm, "ZLogs.TextBold", 10, h / 2, cc,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(ZLogs.FormatTime(row.ts), "ZLogs.Small",
            w - 10, h / 2, ZLogs.Theme.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- ИНИЦИАТОР (sid)
    if row.sid and row.sid ~= "" then
        local sub = menu:AddSubMenu(row.nick ~= "" and ("Инициатор: " .. row.nick) or "Инициатор", nil)

        sub:AddOption("Копировать SteamID", function()
            copyToClipboard(row.sid, "SteamID")
        end):SetIcon("icon16/page_copy.png")

        sub:AddOption("Копировать SteamID64", function()
            local sid64 = ZLogs.SID64(row.sid)
            copyToClipboard(sid64, "SteamID64")
        end):SetIcon("icon16/page_copy.png")

        if row.nick and row.nick ~= "" then
            sub:AddOption("Копировать ник", function()
                copyToClipboard(row.nick, "ник")
            end):SetIcon("icon16/user.png")
        end

        sub:AddOption("Открыть профиль Steam", function()
            openSteamProfile(row.sid)
        end):SetIcon("icon16/world.png")

        sub:AddSpacer()

        sub:AddOption("Показать все логи игрока", function()
            filterByPlayer(row.sid, row.nick)
        end):SetIcon("icon16/magnifier.png")
    end

    -- ЦЕЛЬ (sid_target)
    if row.sid_target and row.sid_target ~= "" then
        local lbl = row.nick_target ~= "" and ("Цель: " .. row.nick_target) or "Цель"
        local sub = menu:AddSubMenu(lbl, nil)

        sub:AddOption("Копировать SteamID", function()
            copyToClipboard(row.sid_target, "SteamID цели")
        end):SetIcon("icon16/page_copy.png")

        sub:AddOption("Копировать SteamID64", function()
            local sid64 = ZLogs.SID64(row.sid_target)
            copyToClipboard(sid64, "SteamID64 цели")
        end):SetIcon("icon16/page_copy.png")

        if row.nick_target and row.nick_target ~= "" then
            sub:AddOption("Копировать ник", function()
                copyToClipboard(row.nick_target, "ник цели")
            end):SetIcon("icon16/user.png")
        end

        sub:AddOption("Открыть профиль Steam", function()
            openSteamProfile(row.sid_target)
        end):SetIcon("icon16/world.png")

        sub:AddSpacer()

        sub:AddOption("Показать все логи цели", function()
            filterByPlayer(row.sid_target, row.nick_target)
        end):SetIcon("icon16/magnifier.png")
    end

    menu:AddSpacer()

    -- Копировать сам лог
    menu:AddOption("Копировать текст лога", function()
        copyToClipboard(row.txt, "лог")
    end):SetIcon("icon16/script.png")

    -- Копировать как форматированную строку
    menu:AddOption("Копировать с меткой времени", function()
        local line = "[" .. ZLogs.FormatTime(row.ts) .. "] " ..
            (ZLogs.Categories[row.cat] and ZLogs.Categories[row.cat].name or row.cat) ..
            " | " .. (row.txt or "")
        copyToClipboard(line, "форматированный лог")
    end):SetIcon("icon16/page_white_text.png")

    -- Снять фильтр игрока (если есть)
    if ZLogs.Menu and ZLogs.Menu.State and ZLogs.Menu.State.sid then
        menu:AddSpacer()
        menu:AddOption("Снять фильтр игрока", function()
            ZLogs.Menu.State.sid       = nil
            ZLogs.Menu.State.sid_label = nil
            ZLogs.Menu.State.page      = 1
            -- Перезапрос
            net.Start("zlogs_query")
            local payload = util.TableToJSON({
                cat       = ZLogs.Menu.State.cat,
                sid       = nil,
                search    = ZLogs.Menu.State.search ~= "" and ZLogs.Menu.State.search or nil,
                page      = 1,
                page_size = ZLogs.Menu.State.page_size,
                reqId     = (ZLogs.Menu.State.reqId or 0) + 1,
            })
            local compressed = util.Compress(payload)
            net.WriteUInt(#compressed, 24)
            net.WriteData(compressed, #compressed)
            net.SendToServer()
            showToast("Фильтр снят", ZLogs.Theme.Warn)
        end):SetIcon("icon16/cross.png")
    end

    menu:Open()
end
