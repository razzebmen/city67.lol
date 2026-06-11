--Roleplay Kill Logs for XGUI

local roleplaypanel = xlib.makepanel{ parent=xgui.null }

-- Kill logs list
xlib.makelabel{ x=10, y=10, label="Логи убийств (последние 100):", parent=roleplaypanel }

local killlog_list = xlib.makelistview{ x=5, y=30, w=587, h=280, multiselect=false, parent=roleplaypanel }
killlog_list:AddColumn("Время")
killlog_list:AddColumn("Убийца")
killlog_list:AddColumn("Жертва")
killlog_list:AddColumn("Оружие")
killlog_list:AddColumn("Дистанция")

-- Filter controls
xlib.makelabel{ x=10, y=315, label="Фильтр по игроку:", parent=roleplaypanel }
local filter_player = xlib.maketextbox{ x=120, y=312, w=150, parent=roleplaypanel }

local filter_button = xlib.makebutton{ x=275, y=312, w=80, label="Применить", parent=roleplaypanel }
filter_button.DoClick = function()
    local filterText = filter_player:GetValue()
    RequestKillLogs(filterText)
end

local clear_button = xlib.makebutton{ x=360, y=312, w=80, label="Сбросить", parent=roleplaypanel }
clear_button.DoClick = function()
    filter_player:SetValue("")
    RequestKillLogs("")
end

local refresh_button = xlib.makebutton{ x=445, y=312, w=80, label="Обновить", parent=roleplaypanel }
refresh_button.DoClick = function()
    RequestKillLogs(filter_player:GetValue())
end

-- Details panel
local details_group = vgui.Create("DCollapsibleCategory", roleplaypanel)
details_group:SetPos(5, 345)
details_group:SetSize(587, 60)
details_group:SetExpanded(0)
details_group:SetLabel("Детали выбранного убийства")

local details_text = vgui.Create("DLabel", details_group)
details_text:SetPos(10, 30)
details_text:SetSize(570, 25)
details_text:SetText("Выберите запись для просмотра деталей")
details_text:SetWrap(true)
details_text:SetAutoStretchVertical(true)

killlog_list.OnRowSelected = function(self, LineID, Line)
    local time = Line:GetColumnText(1)
    local killer = Line:GetColumnText(2)
    local victim = Line:GetColumnText(3)
    local weapon = Line:GetColumnText(4)
    local distance = Line:GetColumnText(5)
    
    details_text:SetText(string.format(
        "Время: %s | Убийца: %s | Жертва: %s | Оружие: %s | Дистанция: %s",
        time, killer, victim, weapon, distance
    ))
    details_group:SetExpanded(1)
end

-- Request kill logs from server
function RequestKillLogs(filter)
    killlog_list:Clear()
    RunConsoleCommand("xgui_getkilllogs", filter or "")
end

-- Receive kill logs from server
net.Receive("XGUI_KillLogs", function()
    local logs = net.ReadTable()
    killlog_list:Clear()
    
    for i = #logs, 1, -1 do
        local log = logs[i]
        killlog_list:AddLine(
            log.time,
            log.killer,
            log.victim,
            log.weapon,
            log.distance
        )
    end
end)

-- Auto-refresh on open
function roleplaypanel.onOpen()
    RequestKillLogs("")
end
xgui.hookEvent("onOpen", nil, roleplaypanel.onOpen)

--xgui.addModule("Логи", roleplaypanel, "icon16/user_suit.png")
