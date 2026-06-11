net.Receive( "rp.chat.SendMessage", function()
	local args = net.ReadTable()
	chat.AddText( unpack( args ) )
end)

-- Когда клиент админа готов — запрашиваем все открытые жалобы, созданные до
-- его захода (в т.ч. поданные, пока администрации не было онлайн). Сервер
-- проверяет права сам и отвечает серией freports.send.
local function freports_RequestSync()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	if not (freports.config and freports.config.WhoCanReceiveReports) then return end
	if not freports.config.WhoCanReceiveReports[lp:GetUserGroup()] then return end

	net.Start("freports.sync")
	net.SendToServer()
end

hook.Add("InitPostEntity", "freports.sync.request", function()
	-- небольшая задержка: usergroup и netvar'ы должны прийти с сервера
	timer.Simple(5, freports_RequestSync)
end)

local tallbar = ScrH() * .02314815
local tallbar_c = tallbar * .5

local function ScreenScale( size )
	return size * ( ScrH() / 480.0 )
end

local function DrawShadowText(text, font, x, y, color, x_a, y_a, color_shadow)
	color_shadow = color_shadow or Color(0, 0, 0,255)
	draw.SimpleText(text, font, x + 1, y + 1, color_shadow, x_a, y_a)
	local w,h = draw.SimpleText(text, font, x, y, color, x_a, y_a)
	return w,h
end

local function DrawBox(x,y,w,h,col,col_o)
	col_o = col_o or Color(0, 0, 0, 255)
	col = col or Color(10, 10, 10, 150)

	surface.SetDrawColor(col)
	surface.DrawRect(x,y,w,h)

	surface.SetDrawColor(col_o)
	surface.DrawOutlinedRect(x,y,w,h)
end

local blur = Material("pp/blurscreen")
local function DrawBlur(panel, amount)
	local x, y = panel:LocalToScreen(0, 0)
	local scrW, scrH = ScrW(), ScrH()

	surface.SetDrawColor(255, 255, 255)
	surface.SetMaterial(blur)
	for i = 1, 3 do
		blur:SetFloat("$blur", (i / 3) * (amount or 6))
		blur:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(x * -1, y * -1, scrW, scrH)
	end
end

local function FormatPlayedTime(time)
	if not time then return 'N/A' end

	local tmp = time
	local s = tmp % 60
	tmp = math.floor( tmp / 60 )
	local m = tmp % 60
	tmp = math.floor( tmp / 60 )
	local h = tmp % 24
	tmp = math.floor( tmp / 24 )
	local d = tmp % 7
	local w = math.floor( tmp / 7 )

	local toret = ""
	if w ~= 0 then
		toret = toret .. math.Round(w) .. "н "
	end

	if d ~= 0 and d < 7 then
		toret = toret .. math.Round(d) .. "д "
	end

	if h ~= 0 and h < 24 then
		toret = toret .. math.Round(h) .. "ч "
	end

	if m ~= 0 and m < 60 then
		toret = toret .. math.Round(m) .. "мин "
	end

	if s ~= 0 and s < 60 then
		toret = toret .. math.Round(s) .. "сек "
	end


	return toret
end

local rad 						= math.rad
local cos 						= math.cos
local sin 						= math.sin
local function DrawCircle(x, y, radius, seg)
	local cir = {}

	table.insert(cir, {
		x = x,
		y = y
	})

	for i = 0, seg do
		local a = rad((i / seg) * -360)

		table.insert(cir, {
			x = x + sin(a) * radius,
			y = y + cos(a) * radius
		})
	end

	local a = rad(0)

	table.insert(cir, {
		x = x + sin(a) * radius,
		y = y + cos(a) * radius
	})

	surface.DrawPoly(cir)
end

surface.CreateFont("reports_10", {
	font = "Roboto",
	size = ScreenScale( 10 ),
	weight = 1000,
	antialias = true,
	extended = true,
})

surface.CreateFont("reports_8", {
	font = "Roboto",
	size = ScreenScale( 8 ),
	weight = 1000,
	antialias = true,
	extended = true,
})

local PANEL = {}

function PANEL:Init()
	self.avatar = vgui.Create("AvatarImage", self)
	self.avatar:SetPaintedManually(true)
	self.button = vgui.Create("DButton", self.avatar)
	self.button:SetText("")
	self.button:SetPaintedManually(true)

	self.button.OnCursorEntered = function(this)
		surface.PlaySound("garrysmod/ui_hover.wav")
	end

	self.button.DoClick = function(this)
		surface.PlaySound("garrysmod/ui_click.wav")

		if self.picked_ply ~= nil then
			gui.OpenURL("http://steamcommunity.com/profiles/".. self.picked_ply)
		end
	end

	self.button.Paint = function(this, w, h)
		if (this.Depressed or this.m_bSelected) then
			surface.SetDrawColor(255, 155, 55, 40)
		elseif (this.Hovered) then
			surface.SetDrawColor(0,0,0,100)
		else
			surface.SetDrawColor(0,0,0,0)
		end

		surface.DrawRect(0,0,w,h)
	end
end

function PANEL:PerformLayout()
	self.avatar:SetSize(self:GetWide(), self:GetTall())
	self.button:SetSize(self:GetWide(), self:GetTall())
end

function PANEL:SetPlayer(ply, size)
	self.avatar:SetPlayer(ply, size)
	self.picked_ply = ply:SteamID64()
end

function PANEL:SetSteamID(sid, size)
	self.avatar:SetSteamID(sid, size)
	self.picked_ply = sid
end

function PANEL:Paint(w, h)
	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(1)
	render.SetStencilTestMask(1)
	render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
	render.SetStencilPassOperation(STENCILOPERATION_ZERO)
	render.SetStencilZFailOperation(STENCILOPERATION_ZERO)
	render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)
	render.SetStencilReferenceValue(1)
	draw.NoTexture()
	surface.SetDrawColor(Color(0, 0, 0, 255))
	DrawCircle(w * .5, h * .5, h * .5, 60)
	render.SetStencilFailOperation(STENCILOPERATION_ZERO)
	render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
	render.SetStencilZFailOperation(STENCILOPERATION_ZERO)
	render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
	render.SetStencilReferenceValue(1)
	self.avatar:PaintManual()
	render.SetStencilEnable(false)
	render.ClearStencil()
end

vgui.Register("rp_avatar", PANEL, "Panel")

local function print_debug(net_name, l, text, ...)
	-- Отладочный вывод отключён (был дев-спам в консоль на каждый репорт).
	-- Оставлен no-op чтобы не трогать места вызова.
end

concommand.Add("rebuild_reports", function()
	if freports.r then freports.r:Remove() end
end)

function freports.OpenAdminMenu(tb)
	if IsValid(freports.a) then freports.a:Remove() end

	local ply = tb.reporter

	freports.a = vgui.Create("DFrame")
	freports.a:SetTitle("")
	freports.a:SetSize(ScrW()*.29, ScrH()*.25)
	freports.a:SetPos(2, 2)
	freports.a:ShowCloseButton(false)
	freports.a.Paint = function(self, w, h)
		DrawBlur(self, 5)
		DrawBox(0,0,w,h)
		DrawBox(0,0,w,tallbar)
		if not IsValid(ply) then return end
		DrawShadowText(ply:Nick(), "reports_8", w * .5, tallbar_c, team.GetColor(ply:Team()), 1, 1)
	end

	local ava = vgui.Create("rp_avatar", freports.a)
	ava:SetSize(freports.a:GetTall() * .3 - 4, freports.a:GetTall() * .3 - 4)
	ava:SetPos(freports.a:GetWide() *.35 * .5 - ava:GetTall() *.5, tallbar + 2)
	ava:SetPlayer(ply, 184)

	local scroll = vgui.Create("DScrollPanel", freports.a)
	scroll:SetPos(2, tallbar + 4 + ava:GetTall())
	scroll:SetSize(freports.a:GetWide() *.35, freports.a:GetTall() - tallbar - tallbar - 8 - ava:GetTall())

	local function add(name, command)
		local b = vgui.Create("DButton", scroll)
		b:Dock(TOP)
		b:DockMargin(0, 1, 0, 1)
		b:SetTall(tallbar)
		b:SetText('')
		b:SetFont("reports_8")

		b.DoClick = function()
			if isfunction(command) then
				command()
			end
		end

		b.Paint = function(self, w, h)
			DrawBox(0, 0, w, h, Color(0, 0, 0, 100))

			DrawShadowText(name, "reports_8", w*.5, h*.5, Color(255,255,255), 1, 1)
		end
	end

	add("Скопировать SteamID", function()
		SetClipboardText(ply:SteamID())
	end)
	add("Скопировать SteamID64", function()
		SetClipboardText(ply:SteamID64())
	end)
	add("Тп игрока к себе", function()
		RunConsoleCommand("ulx", "bring", ply:Nick())
	end)
	add("Тп к игроку", function()
		RunConsoleCommand("ulx", "goto", ply:Nick())
	end)
	add("Вернуть игрока", function()
		RunConsoleCommand("ulx", "return", ply:Nick())
	end)

	local report_chat = vgui.Create("RichText", freports.a)
	report_chat:SetSize(freports.a:GetWide() - scroll:GetWide() - 6, freports.a:GetTall() - tallbar*3 - 8)
	report_chat:SetPos(scroll:GetWide() + 4, freports.a:GetTall() - tallbar - tallbar - 6 - report_chat:GetTall())
	function report_chat:PerformLayout()
		self:SetFontInternal("reports_8")
		self:SetBGColor(Color(0,0,0,100))
	end

	freports.a.Chat = function(msg)
		local ply = msg[1]
		local text = msg[2]

		local job_col = team.GetColor(ply:Team())
		report_chat:InsertColorChange(job_col.r, job_col.g, job_col.b, 255)
		report_chat:AppendText(ply:Nick())
		report_chat:InsertColorChange(255, 255, 255, 255)
		report_chat:AppendText(": "..text.."\n")
	end

	local message = vgui.Create("DButton", freports.a)
	message:SetText("")
	message:SetPos(scroll:GetWide() + 4, freports.a:GetTall() - tallbar - tallbar - 4)
	message:SetSize(freports.a:GetWide() - scroll:GetWide() - 6, tallbar)
	message.DoClick = function()
		Derma_StringRequest(
			"Сообщение в репорт", 
			"Введите сообщение которое хотели бы отправить",
			"",
			function(text) net.Start("freports.message") net.WriteString(text) net.SendToServer() end
		)
	end
	message.Paint = function(self, w, h)
		DrawBox(0, 0, w, h, Color(0, 0, 0, 100))

		DrawShadowText("Написать сообщение", "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
	end

	for k,v in ipairs(tb.report_chat) do
		freports.a.Chat(v)
	end

	local close = vgui.Create("DButton", freports.a)
	close:SetPos(2, freports.a:GetTall() - tallbar - 2)
	close:SetSize(freports.a:GetWide() - 4, tallbar)
	close:SetText("")

	close.DoClick = function()
		Derma_Query( "Вы уверены что хотите закрыть жалобу?", "Проверка", "Да", function()
			net.Start("freports.close")
			net.SendToServer()
		end, "Нет")
	end
	close.Paint = function(self, w, h)
		DrawBox(0, 0, w, h, Color(255, 155, 55, 100))

		DrawShadowText("Закрыть жалобу", "reports_8", w*.5, h*.5, Color(255,255,255), 1, 1)
	end
end

function freports.CreateMain()
	freports.r = vgui.Create("DPanel")
	freports.r:SetSize(ScrW()*.15 + tallbar + 2, ScrH()*.3)
	freports.r:SetPos(ScrW() - freports.r:GetWide(), ScrH() * .5 - freports.r:GetTall() * .5)
	freports.r.Paint = function(self, w, h)
		if not self:HasFocus() then self:RequestFocus() end
		DrawBlur(self, 5)
		DrawBox(0,0,w,h)
	end
	freports.r.hiden = false
	freports.r.total_reports = 0
	freports.r.created_reports = {}
	freports.r.fHide = function(self)
		freports.r:MoveTo(ScrW() - tallbar, ScrH() * .5 - freports.r:GetTall() * .5, 0.5, 0, -1, function()
			freports.r.hiden = true
		end)
	end

	freports.r.fShow = function(self)
		freports.r:MoveTo(ScrW() - freports.r:GetWide(), ScrH() * .5 - freports.r:GetTall() * .5, 0.5, 0, -1, function()
			freports.r.hiden = false
		end)
	end

	local info_bar = vgui.Create("DPanel", freports.r)
	info_bar:SetPos(0,0)
	info_bar:SetSize(freports.r:GetWide(), tallbar)
	info_bar.Paint = function(self, w, h)
		DrawBox(0,0,w,h)

		if freports.r.hiden then
			DrawShadowText(freports.r.total_reports, "reports_10", tallbar * .5, h*.5, Color(255,255,255), 1, 1)
		else
			DrawShadowText("Жалоб: " .. freports.r.total_reports, "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
		end
	end

	local hide = vgui.Create("DButton", freports.r)
	hide:SetColor(Color(0,0,0,150))
	hide:SetPos(0, tallbar + 2)
	hide:SetSize(tallbar, freports.r:GetTall() - tallbar - 2)
	hide.DoClick = function(self)
		if freports.r.hiden then
			freports.r.fShow()
		else
			freports.r.fHide()
		end
	end

	hide.Paint = function(self, w, h)
		DrawBox(0,0,w,h)

		DrawShadowText(freports.r.hiden and "<" or ">", "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
	end

	local scroll = vgui.Create("DScrollPanel", freports.r)
	scroll:SetPos(tallbar + 2, tallbar + 2)
	scroll:SetSize(freports.r:GetWide() - tallbar - 2, freports.r:GetTall() - tallbar - 2)

	freports.r.AddReport = function(tb)
		freports.r:Show()
		
		local b = vgui.Create("DButton", scroll)
		b:SetText('')
		b:Dock(TOP)
		b:DockMargin(2, 0, 2, 2)
		b:SetTall(scroll:GetTall() * .15)
		b.tb = tb
		freports.r.created_reports[tb.reporter] = b
		b.Paint = function(self, w, h)
			local ply = tb.reporter
			if not IsValid(ply) then 
				self:Remove()
				return 
			end

			local live = math.Round(CurTime() - tb.start)

			local col_o = Color(0,0,0)

			if live > 180 then
				col_o = Color(255,155,0)
			end

			if live > 300 then
				col_o = Color(255,0,0)
			end

			local col = Color(0,0,0,150)
			if (self.Depressed or self.m_bSelected) then
				DrawBox(0,0,w,h,Color(70, 70, 70, 100), col_o)
			elseif (self.Hovered) then
				DrawBox(0,0,w,h,ColorAlpha(col, col.a - 25), col_o)
			else
				DrawBox(0,0,w,h,col, col_o)
			end
			
			local _, fh = DrawShadowText(ply:Nick(), "reports_10", h + 2, 2, Color(255,255,255), 0, 0)
			DrawShadowText(FormatPlayedTime(live), "reports_10", h + 2, h - fh - 2, Color(255,255,255), 0, 0)
		end
		b.DoClick = function()
			--if LocalPlayer() == tb.reporter then return end

			freports.r.fHide()
			net.Start("freports.accept")
				net.WriteEntity(tb.reporter)
			net.SendToServer()
		end
		b.OnRemove = function()
			freports.r.created_reports[tb.reporter] = nil
			freports.r.total_reports = freports.r.total_reports - 1

			if freports.r.total_reports <= 0 then
				freports.r:Hide()
			end
		end

		local ava = vgui.Create("rp_avatar", b)
		ava:SetPos(2, 2)
		ava:SetSize(b:GetTall() - 4, b:GetTall() - 4)
		ava:SetPlayer(tb.reporter, 184)

		freports.r.total_reports = freports.r.total_reports + 1
	end
end

net.Receive("freports.send", function()
	local tb = net.ReadTable()

	print_debug("freports.send", 462, "пришел net на клиент", tb)

	if not tb then
		print_debug("freports.send", 465, "не пришла таблица в net", tb)
		return
	end
	if not tb.reporter then
		print_debug("freports.send", 469, "в таблице нет игрока", tb)
		return
	end
	if not tb.reporter:IsPlayer() then
		print_debug("freports.send", 472, "в таблице reporter не является игроком", tb)
		return
	end

	if tb.reporter == LocalPlayer() then
		if IsValid(freports.m) then freports.m:Remove() end
		freports.m = vgui.Create("DFrame")
		freports.m:SetSize(ScrW()*.25, ScrH()*.12 + tallbar + tallbar + 4)
		freports.m:SetPos(2, 2)
		freports.m:SetTitle("")
		freports.m.report = tb
		freports.m.OnClose = function()
			net.Start("freports.close")
			net.SendToServer()
		end
		freports.m.Paint = function(self, w, h)
			DrawBlur(self, 5)
			DrawBox(0,0,w,h)
			DrawBox(0,0,w,tallbar)
			DrawShadowText("Жалоба", "reports_8", w * .5, tallbar_c, Color(255,255,255), 1, 1)
		end

		local report_chat = vgui.Create("RichText", freports.m)
		report_chat:SetPos(2, tallbar + 2)
		report_chat:SetSize(freports.m:GetWide() - 4, freports.m:GetTall() - tallbar*3 - 8)
		function report_chat:PerformLayout()
			self:SetFontInternal("reports_8")
			self:SetBGColor(Color(0,0,0,100))
		end

		freports.m.Chat = function(msg)
			local ply = msg[1]
			if not IsValid(ply) then return end
			local text = msg[2]

			local job_col = team.GetColor(ply:Team())
			report_chat:InsertColorChange(job_col.r, job_col.g, job_col.b, 255)
			report_chat:AppendText(ply:Nick())
			report_chat:InsertColorChange(255, 255, 255, 255)
			report_chat:AppendText(": "..text.."\n")
		end

		local message = vgui.Create("DButton", freports.m)
		message:SetText("")
		message:SetPos(2, freports.m:GetTall() - tallbar - tallbar - 4)
		message:SetSize(freports.m:GetWide() - 4, tallbar)
		message.DoClick = function()
			Derma_StringRequest(
				"Сообщение в репорт", 
				"Введите сообщение которое хотели бы отправить",
				"",
				function(text) net.Start("freports.message") net.WriteString(text) net.SendToServer() end
			)
		end
		message.Paint = function(self, w, h)
			DrawBox(0, 0, w, h, Color(0, 0, 0, 100))

			DrawShadowText("Написать сообщение", "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
		end

		local info_bar = vgui.Create("DPanel", freports.m)
		info_bar:SetPos(2, freports.m:GetTall() - tallbar - 2)
		info_bar:SetSize(freports.m:GetWide() - 4, tallbar)
		info_bar.Paint = function(self, w, h)
			DrawBox(0, 0, w, h, Color(0, 0, 0, 100))

			if IsValid(freports.m.report.admin) and freports.m.report.admin.Nick then
				DrawShadowText(freports.m.report.admin:Nick(), "reports_10", w*.5, h*.5, team.GetColor(freports.m.report.admin:Team()), 1, 1)
			else
				DrawShadowText("Ожидаем администратора...", "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
			end
		end

		for k,v in ipairs(freports.m.report.report_chat) do
			freports.m.Chat(v)
		end
	end

	if freports.config.WhoCanReceiveReports[LocalPlayer():GetUserGroup()] then
		if not IsValid(freports.r) then 
			freports.CreateMain()
		end

		if not freports.r.hiden then
			surface.PlaySound("HL1/fvox/bell.wav")
		end
		freports.r.AddReport(tb)
	end
end)

net.Receive("freports.accept", function()
	local rep = net.ReadEntity()
	local admin = net.ReadEntity()

	if not admin:IsPlayer() then admin = nil end

	print_debug("freports.accept", 567, "пришел net на клиент", rep, admin)

	if admin and IsValid(admin) then
		if admin == LocalPlayer() then
			freports.OpenAdminMenu(net.ReadTable())
		end

		if IsValid(freports.m) and rep == LocalPlayer() then
			freports.m.report.admin = admin

			surface.PlaySound("HL1/fvox/bell.wav")
		end
	end

	if IsValid(freports.r) and IsValid(freports.r.created_reports[rep]) then
		freports.r.created_reports[rep]:Remove()
	end
end)

net.Receive("freports.close", function()
	if IsValid(freports.m) then freports.m:Remove() end
	if IsValid(freports.a) then freports.a:Remove() end

	if IsValid(freports.r) and freports.config.WhoCanReceiveReports[LocalPlayer():GetUserGroup()] and freports.r.fShow then
		freports.r.fShow()
	end
end)

net.Receive("freports.message", function() 
	local tb = net.ReadTable()

	if IsValid(freports.m) then freports.m.Chat(tb) end
	if IsValid(freports.a) then freports.a.Chat(tb) end

	surface.PlaySound("npc/turret_floor/ping.wav")
end)

net.Receive("freports.adm_stats", function()
	local logs = net.ReadTable()

	local main = vgui.Create("DFrame")
	main:SetSize(ScrW()*.4, ScrH()*.6)
	main:Center()
	main:MakePopup()
	main.Paint = function(self, w, h)
		DrawBlur(self, 5)
		DrawBox(0,0,w,h)
		DrawBox(0,0,w,tallbar)
		DrawShadowText("Последний раз принимали жалобы", "reports_8", w * .5, tallbar_c, Color(255,255,255), 1, 1)
	end

	main:SetTitle("")

	local logs_main = vgui.Create("DFrame")
	logs_main:SetSize(ScrW()*.25, main:GetTall())

	main:SetPos(ScrW() * .5 - main:GetWide()*.5 + logs_main:GetWide() * .5, ScrH() * .5 - main:GetTall()*.5)

	logs_main:SetTitle('')
	local x, y = main:GetPos()
	logs_main:SetPos(x - logs_main:GetWide() - 2, y)
	logs_main:ShowCloseButton(false)
	logs_main.Paint = function(self, w, h)
		local x, y = main:GetPos()
		self:SetPos(x - self:GetWide() - 2, y)
		DrawBlur(self, 5)
		DrawBox(0,0,w,h)
		DrawBox(0,0,w,tallbar)
		DrawShadowText("Мини логи", "reports_8", w * .5, tallbar_c, Color(255,255,255), 1, 1)
	end

	main.OnClose = function()
		if IsValid(logs_main) then logs_main:Remove() end
	end

	local scroll = vgui.Create("DScrollPanel", main)
	scroll:SetPos(2, tallbar + 2)
	scroll:SetSize(main:GetWide() - 4, main:GetTall() - tallbar - 4)

	local admins = table.Filter(player.GetAll(), function(a) return (freports.config.WhoCanReceiveReports[a:GetUserGroup()] or false) end)

	for k,v in ipairs(admins) do
		local b = vgui.Create("DPanel", scroll)
		b:Dock(TOP)
		b:DockMargin(0,1,0,1)
		b:SetTall(main:GetTall() * .07)
		b.Paint = function(self,w,h)
			DrawBox(0,0,w,h,Color(0,0,0,150))
			if not IsValid(v) then return end
				
			local last_report = v:GetNetVar("rp.LastReport") and CurTime() - v:GetNetVar("rp.LastReport") or 0
				
			DrawShadowText(v:Nick(), "reports_10", h + 2, h *.5, team.GetColor(v:Team()), 0, 1)
			
			
			local col = Color(0, 255, 125)
			
			if last_report > 180 then col = Color(255, 255, 125) end
			if last_report > 240 then col = Color(255,155,55) end
			if last_report > 420 then col = Color(255, 120, 120) end
			
			DrawShadowText(freports.FormatRankName(v), "reports_10", w * .5, h *.5, freports.FormatRankColor(v), 1, 1)

			DrawShadowText(v:GetNetVar("rp.ReportClaimed") and "Разбирает жалобу!" or last_report == 0 and "-" or FormatPlayedTime(last_report), "reports_10", w - 2, h *.5, col, 2, 1)
		end
		
		local ava = vgui.Create("rp_avatar", b)
		ava:SetPos(2, 2)
		ava:SetSize(b:GetTall() - 4, b:GetTall() - 4)
		ava:SetPlayer(v, 184)
	end

	local logs_scroll = vgui.Create("DScrollPanel", logs_main)
	logs_scroll:SetPos(2, tallbar + 2)
	logs_scroll:SetSize(logs_main:GetWide() - 4, logs_main:GetTall() - 4 - tallbar)

	for k,v in ipairs(logs) do
		local log = vgui.Create("DPanel", logs_scroll)
		log:Dock(TOP)
		log:DockMargin(0,1,0,1)
		log:SetTall(logs_main:GetTall() * .07)
		if v.rtype == "create" then
			log.Paint = function(self,w,h)
				DrawBox(0,0,w,h,Color(0,0,0,150))

				local fw = DrawShadowText(v.rep_ply_name, "reports_10", h + 2, h *.5, team.GetColor(v.rep_ply_job), 0, 1)
				DrawShadowText(" написал жалобу (".. os.date("%H:%M", v.rep_start) .. ")", "reports_10", h + 2 + fw, h *.5, Color(255, 255, 255), 0, 1)
			end

			local ava = vgui.Create("rp_avatar", log)
			ava:SetPos(2, 2)
			ava:SetSize(log:GetTall() - 4, log:GetTall() - 4)
			ava:SetSteamID(v.rep_ply_id, 184)
		elseif v.rtype == "accept" then
			surface.SetFont("reports_10")
			local fw = surface.GetTextSize(v.admin_name .. " принял жалобу (".. os.date("%H:%M", v.rep_accepted) .. ")")
			log.Paint = function(self,w,h)
				DrawBox(0,0,w,h,Color(0,0,0,150))

				local _ = DrawShadowText(v.admin_name, "reports_10", h + 2, h *.5, team.GetColor(v.admin_job), 0, 1)
				DrawShadowText(" принял жалобу (".. os.date("%H:%M", v.rep_accepted) .. ")", "reports_10", h + 2 + _, h *.5, Color(255, 255, 255), 0, 1)

				DrawShadowText(v.rep_ply_name, "reports_10", h + 8 + fw + h, h *.5, team.GetColor(v.rep_ply_job), 0, 1)
			end

			local adm_ava = vgui.Create("rp_avatar", log)
			adm_ava:SetSize(log:GetTall() - 4, log:GetTall() - 4)
			adm_ava:SetPos(2, 2)
			adm_ava:SetSteamID(v.admin_id, 184)

			local rep_ava = vgui.Create("rp_avatar", log)
			rep_ava:SetSize(log:GetTall() - 4, log:GetTall() - 4)
			rep_ava:SetPos(10 + rep_ava:GetWide() + fw, 2)
			rep_ava:SetSteamID(v.rep_ply_id, 184)
		end
	end
end)

net.Receive("freports.reputation", function()
	local main = vgui.Create("DFrame")
	main:SetSize(ScrW()*.25, ScrH()*.1)
	main:SetTitle('')
	main:Center()
	main:MakePopup()

	main.Paint = function(self, w, h)
		DrawBlur(self, 5)
		DrawBox(0,0,w,h)
		DrawBox(0,0,w,tallbar)
		DrawShadowText("Оцените работу администрации", "reports_8", w * .5, tallbar_c, Color(255,255,255), 1, 1)
	end

	local ye = vgui.Create("DButton", main)
	ye:SetPos(2, tallbar + 2)
	ye:SetSize(main:GetWide() * .5 - 3, main:GetTall() - 6 - tallbar - tallbar)
	ye:SetText('')
	ye.Paint = function(self, w, h)
		DrawBox(0,0,w,h, Color(100, 255, 100, 100))
		DrawShadowText("+rep", "reports_10", w * .5, h * .5, Color(255,255,255), 1, 1)
	end
	ye.DoClick = function(self)
		net.Start("freports.reputation")
			net.WriteBool(true)
		net.SendToServer()
		main:Remove()
	end

	local no = vgui.Create("DButton", main)
	no:SetPos(main:GetWide() * .5 + 1, tallbar + 2)
	no:SetSize(main:GetWide() * .5 - 3, main:GetTall() - 6 - tallbar - tallbar)
	no:SetText('')
	no.Paint = function(self, w, h)
		DrawBox(0,0,w,h, Color(255, 100, 100, 100))
		DrawShadowText("-rep", "reports_10", w * .5, h * .5, Color(255,255,255), 1, 1)
	end
	no.DoClick = function(self)
		net.Start("freports.reputation")
			net.WriteBool(false)
		net.SendToServer()
		main:Remove()
	end

	local statistic = vgui.Create("DButton", main)
	statistic:SetPos(2, main:GetTall() - tallbar - 2)
	statistic:SetSize(main:GetWide() - 4, tallbar)
	statistic:SetText('')
	statistic.Paint = function(self, w, h)
		DrawBox(0,0,w,h)
		DrawShadowText("Статистика администратора", "reports_10", w * .5, h * .5, Color(255,255,255), 1, 1)
	end
	statistic.DoClick = function(self)
		net.Start("freports.request_admin_statistic")
		net.SendToServer()
	end

	main.OnClose = function()
		net.Start("freports.reputation")
			net.WriteBool(false)
		net.SendToServer()
	end
end)

net.Receive("freports.reports_statistics", function()
	local data = net.ReadTable()

	data = table.Filter(data, function(v)
		return freports.config.WhoCanReceiveReports[v.rank] or false
	end)

	table.sort( data, function(a, b) return tonumber(a.rep) > tonumber(b.rep) end )

	local page = 0
	local main = vgui.Create("DFrame")
	main:SetSize(ScrW()*.4, ScrH()*.6)
	main:SetTitle('')
	main:Center()
	main:MakePopup()

	main.Paint = function(self, w, h)
		DrawBlur(self, 5)
		DrawBox(0,0,w,h)
		DrawBox(0,0,w,tallbar)
		DrawShadowText("Статистика администрации", "reports_8", w * .5, tallbar_c, Color(255,255,255), 1, 1)
	end

	local scroll = vgui.Create("DScrollPanel", main)
	scroll:SetPos(2, tallbar + tallbar + 4)
	scroll:SetSize(main:GetWide() - 4, main:GetTall() - tallbar - tallbar - tallbar - 8)
	
	local top_bar = vgui.Create("DPanel", main)
	top_bar:SetPos(2, tallbar + 2)
	top_bar:SetSize(main:GetWide() - 4, tallbar)
	top_bar.Paint = function(self, w, h)
		DrawBox(0,0,w,h)

		DrawShadowText("Игрок", "reports_10", h, h*.5, Color(255,255,255), 0, 1)
		DrawShadowText("Ранг", "reports_10", w*.35, h*.5, Color(255,255,255), 1, 1)
		DrawShadowText("Всего жалоб", "reports_10", w*.65, h*.5, Color(255,255,255), 1, 1)
		DrawShadowText("Репутация", "reports_10", w - 8, h*.5, Color(255,255,255), 2, 1)
	end
	
	local sheet = {}
	local load_more
	local function AddB(k, v)
		if not freports.config.WhoCanReceiveReports[v.rank] then return end
		local p = vgui.Create("DButton", scroll)
		table.insert(sheet, p)
		p:SetText('')
		p:Dock(TOP)
		p:DockMargin(2,1,2,1)
		p:SetTall(ScrH()*.025)
		p.Paint = function(self, w, h)
			DrawBox(0,0,w,h)

			DrawShadowText(v.name, "reports_10", h, h*.5, Color(255,255,255), 0, 1)
			DrawShadowText(freports.FormatRankName(v.rank), "reports_10", w*.35, h*.5, freports.FormatRankColor(v.rank), 1, 1)
			DrawShadowText(v.total_reports, "reports_10", w*.65, h*.5, Color(255,255,255), 1, 1)
			DrawShadowText(v.rep, "reports_10", w - 8, h*.5, Color(255,255,255), 2, 1)
			if v.steamid == LocalPlayer():SteamID64() then
				surface.SetDrawColor(team.GetColor(LocalPlayer():Team()))
				surface.DrawOutlinedRect(0, 0, w, h)
			end
		end
		p.m_fCreateTime = SysTime()
		p.DoClick = function()
			surface.SetFont("reports_10")
			local fh = select(2, surface.GetTextSize("A"))

			local main = vgui.Create("DFrame")
			main:SetSize(ScrW()*.2, ScrH()*.5)
			main:Center()
			main:MakePopup()
			main:SetBackgroundBlur( true )
			main:SetTitle('')

			main.Paint = function(self, w, h)
				Derma_DrawBackgroundBlur( self, self.m_fCreateTime )
				DrawBox(0,0,w,h)
				DrawBox(0,0,w,tallbar)
				DrawShadowText("Статистика", "reports_8", w * .5, tallbar_c, Color(255,255,255), 1, 1)
			end

			local month_total_reps = 0

			local scroll = vgui.Create("DScrollPanel", main)
			scroll:SetPos(2, tallbar + 2)
			scroll:SetSize(main:GetWide() - 4, main:GetTall() - tallbar - 4)

			local p1 = vgui.Create("DPanel", scroll)
			p1:Dock(TOP)
			p1:DockMargin(2, 1, 2, 1)
			p1:SetTall(main:GetTall() * .15)
			p1.Paint = function(self, w, h)
				DrawBox(0,0,w,h)
			end

			local ava2 = vgui.Create("rp_avatar", p1)
			ava2:SetSize(p1:GetTall() - 8, p1:GetTall() - 8)
			ava2:SetPos(scroll:GetWide() * .5 - ava2:GetWide()*.5, 4)
			ava2:SetSteamID(v.steamid, 184)

			local p2 = vgui.Create("DPanel", scroll)
			p2:Dock(TOP)
			p2:DockMargin(2, 1, 2, 1)
			p2:SetTall(fh + 8)
			p2.Paint = function(self, w, h)
				DrawBox(0,0,w,h)
				DrawShadowText(v.name, "reports_10", w * .5, h * .5, Color(255,255,255), 1, 1)
			end

			local p2 = vgui.Create("DButton", scroll)
			p2:Dock(TOP)
			p2:DockMargin(2, 1, 2, 1)
			p2:SetTall(fh + 8)
			p2:SetText('')
			p2.Paint = function(self, w, h)
				DrawBox(0,0,w,h)
				DrawShadowText(util.SteamIDFrom64(v.steamid), "reports_10", w * .5, h * .5, Color(255,255,255), 1, 1)
			end
			p2.DoClick = function()
				surface.PlaySound("garrysmod/ui_click.wav")
				SetClipboardText(util.SteamIDFrom64(v.steamid))
			end

			local p3 = vgui.Create("DPanel", scroll)
			p3:Dock(TOP)
			p3:DockMargin(2, 1, 2, 1)
			p3:SetTall(fh + 8)
			p3.Paint = function(self, w, h)
				DrawBox(0,0,w,h)
				DrawShadowText(freports.FormatRankName(v.rank), "reports_10", w*.5, h*.5, freports.FormatRankColor(v.rank), 1, 1)
			end

			local p4 = vgui.Create("DPanel", scroll)
			p4:Dock(TOP)
			p4:DockMargin(2, 1, 2, 1)
			p4:SetTall(fh + fh + 10)
			p4.Paint = function(self, w, h)
				DrawBox(0,0,w,h)
				DrawShadowText("Последний раз заходил" , "reports_10", w*.5, 2, Color(255,255,255), 1, 0)
				DrawShadowText(os.date("%d/%m/%Y - %H:%M", v.last_seen) , "reports_10", w*.5, h - fh - 2, Color(255,255,255), 1, 0)
			end

			local p5 = vgui.Create("DPanel", scroll)
			p5:Dock(TOP)
			p5:DockMargin(2, 1, 2, 1)
			p5:SetTall(fh + 8)
			p5.Paint = function(self, w, h)
				DrawBox(0,0,w,h)
				DrawShadowText("Репутация: " .. v.rep , "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
			end

			local p6 = vgui.Create("DPanel", scroll)
			p6:Dock(TOP)
			p6:DockMargin(2, 1, 2, 1)
			p6:SetTall(fh + 8)
			p6.Paint = function(self, w, h)
				DrawBox(0,0,w,h)
				DrawShadowText("Всего жалоб: " .. v.total_reports , "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
			end

			local p6 = vgui.Create("DPanel", scroll)
			p6:Dock(TOP)
			p6:DockMargin(2, 1, 2, 1)
			p6:SetTall(fh + 8)
			p6.Paint = function(self, w, h)
				DrawBox(0,0,w,h)
				DrawShadowText("Жалоб за месяц: " .. month_total_reps , "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
			end

			local p7 = vgui.Create("DPanel", scroll)
			p7:Dock(TOP)
			p7:DockMargin(2, 1, 2, 1)
			p7:SetTall(fh + 8)
			p7.Paint = function(self, w, h)
				DrawBox(0,0,w,h)
				DrawShadowText("Онлайн", "reports_8", w*.5, h*.5, Color(255, 255, 255), 1, 1)
			end

			if not istable(v.daily_online) then
				v.daily_online = util.JSONToTable(v.daily_online)
			end
			local temp_month = {}

			for k,v in pairs(v.daily_online) do
				temp_month[#temp_month + 1] = {k, v}
			end

			table.sort( temp_month, function( a, b ) return a[1] < b[1] end )

			for _,v in ipairs(temp_month) do
				local bar = vgui.Create("DPanel", scroll)
				bar:Dock(TOP)
				bar:DockMargin(2,1,2,1)
				bar:SetTall(fh + 4)
				bar.process = 0
				bar.Paint = function(self,w,h)
					surface.SetDrawColor(0,0,0,100)
					surface.DrawRect(0,0,w,h)

					self.process = Lerp( 0.06, self.process, (w - 4) * v[2] / 86400)

					surface.SetDrawColor(111,255,111,100)
					surface.DrawRect(2,2,self.process,h-4)

					DrawShadowText(v[1], "reports_10", 2, h*.5, Color(255, 255, 255), 0, 1)
					DrawShadowText(FormatPlayedTime(v[2]), "reports_10", w - 2, h*.5, Color(255, 255, 255), 2, 1)
				end
			end

			local p8 = vgui.Create("DPanel", scroll)
			p8:Dock(TOP)
			p8:DockMargin(2, 1, 2, 1)
			p8:SetTall(fh + 8)
			p8.Paint = function(self, w, h)
				DrawBox(0,0,w,h)
				DrawShadowText("Онлайн в админ профе", "reports_8", w*.5, h*.5, Color(255, 255, 255), 1, 1)
			end

			if not istable(v.daily_online_onduty) then
				v.daily_online_onduty = util.JSONToTable(v.daily_online_onduty)
			end
			local temp_month = {}

			for k,v in pairs(v.daily_online_onduty) do
				temp_month[#temp_month + 1] = {k, v}
			end

			table.sort( temp_month, function( a, b ) return a[1] < b[1] end )

			for _,v in ipairs(temp_month) do
				local bar = vgui.Create("DPanel", scroll)
				bar:Dock(TOP)
				bar:DockMargin(2,1,2,1)
				bar:SetTall(fh + 4)
				bar.process = 0
				bar.Paint = function(self,w,h)
					surface.SetDrawColor(0,0,0,100)
					surface.DrawRect(0,0,w,h)

					self.process = Lerp( 0.06, self.process, (w - 4) * v[2] / 86400)

					surface.SetDrawColor(255,55,55,100)
					surface.DrawRect(2,2,self.process,h-4)

					DrawShadowText(v[1], "reports_10", 2, h*.5, Color(255, 255, 255), 0, 1)
					DrawShadowText(FormatPlayedTime(v[2]), "reports_10", w - 2, h*.5, Color(255, 255, 255), 2, 1)
				end
			end

			local p9 = vgui.Create("DPanel", scroll)
			p9:Dock(TOP)
			p9:DockMargin(2, 1, 2, 1)
			p9:SetTall(fh + 8)
			p9.Paint = function(self, w, h)
				DrawBox(0,0,w,h)
				DrawShadowText("Жалобы", "reports_8", w*.5, h*.5, Color(255, 255, 255), 1, 1)
			end

			if not istable(v.daily_reports) then
				v.daily_reports = util.JSONToTable(v.daily_reports)
			end
			local temp_month = {}

			for k,v in pairs(v.daily_reports) do
				temp_month[#temp_month + 1] = {k, v}
			end

			table.sort( temp_month, function( a, b ) return a[1] < b[1] end )
			for _,v in ipairs(temp_month) do
				month_total_reps = month_total_reps + v[2]
				local bar = vgui.Create("DPanel", scroll)
				bar:Dock(TOP)
				bar:DockMargin(2,1,2,1)
				bar:SetTall(fh + 4)
				bar.process = 0
				bar.Paint = function(self,w,h)
					surface.SetDrawColor(0,0,0,100)
					surface.DrawRect(0,0,w,h)

					self.process = Lerp( 0.06, self.process, (w - 4) * v[2] / 100)

					surface.SetDrawColor(255,255,100,100)
					surface.DrawRect(2,2,self.process,h-4)

					DrawShadowText(v[1], "reports_10", 2, h*.5, Color(255, 255, 255), 0, 1)
					DrawShadowText(v[2] .. " жб", "reports_10", w - 2, h*.5, Color(255, 255, 255), 2, 1)
				end
			end
		end

		local ava = vgui.Create("rp_avatar", p)
		ava:SetPos(4, 4)
		ava:SetSize(p:GetTall() - 8, p:GetTall() - 8)
		ava:SetSteamID(v.steamid, 184)

		if IsValid(load_more) then load_more:Remove() end

		load_more = vgui.Create("DButton", scroll)
		load_more:SetText('')
		load_more:Dock(TOP)
		load_more:DockMargin(2,1,2,1)
		load_more:SetTall(ScrH()*.025)
		load_more.Paint = function(self, w, h)
			if (self.Depressed or self.m_bSelected) then
				DrawBox(0,0,w,h)
			elseif (self.Hovered) then
				DrawBox(0,0,w,h, Color(255, 155, 55, 40))
			else
				DrawBox(0,0,w,h)
			end

			DrawShadowText("Загрузить еще...", "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
		end
		
		load_more.DoClick = function(self)
			page = page + 1
			net.Start("freports.reports_statistics.load_more")
				net.WriteInt(page, 32)
			net.SendToServer()

			self:SetEnabled(false)
			timer.Simple(2, function()
				if IsValid(self) then
					self:SetEnabled(true)
				end
			end)
		end
	end

	local function ReBuildScroll(tb)
		for k,v in pairs(sheet) do
			v:Remove()
		end
		sheet = {}

		for k,v in ipairs(tb) do
			AddB(k,v)
		end

		page = 1
	end

	ReBuildScroll(data)

	net.Receive("freports.reports_statistics.search", function()
		if not IsValid(main) then return end
		local data = net.ReadTable()
		ReBuildScroll(data)
	end)

	net.Receive("freports.reports_statistics.load_more", function()
		if not IsValid(main) then return end

		local data = net.ReadTable()
		for k,v in ipairs(data) do
			AddB(k,v)
		end
	end)

	local search_type = vgui.Create( "DComboBox", main )
	search_type:SetPos( 2, main:GetTall() - tallbar - 2)
	search_type:SetSize( main:GetWide()*.2 - 4, tallbar )
	search_type:AddChoice("SteamID")
	search_type:AddChoice("SteamID64")
	search_type:AddChoice("Rank")
	search_type:AddChoice("Nick", nil, true)
	search_type.OnSelect = function( panel, index, value )

	end

	local search_p = vgui.Create("DTextEntry", main)
	search_p:SetSize(main:GetWide()*.8 - 4, tallbar)
	search_p:SetPos(main:GetWide()*.2, main:GetTall() - tallbar - 2)
	search_p:SetToolTip("Поиск")
	search_p.OnEnter = function()
		surface.PlaySound("garrysmod/ui_click.wav")

		if #search_p:GetText() < 3 then return end

		local search_by = search_p:GetText()
		if search_type:GetSelectedID() == 1 or search_type:GetSelectedID() == 2 then
			search_by = string.Replace( search_by, " ", "" )
		end

		net.Start("freports.reports_statistics.search")
			net.WriteInt(search_type:GetSelectedID(), 32)
			net.WriteString(search_p:GetText())
		net.SendToServer()
	end
end)

net.Receive("freports.request_admin_statistic", function()
	local v = net.ReadTable()

	surface.SetFont("reports_10")
	local fh = select(2, surface.GetTextSize("A"))

	local main = vgui.Create("DFrame")
	main:SetSize(ScrW()*.2, ScrH()*.5)
	main:Center()
	main:MakePopup()
	main:SetBackgroundBlur( true )
	main:SetTitle('')

	main.Paint = function(self, w, h)
		Derma_DrawBackgroundBlur( self, self.m_fCreateTime )
		DrawBox(0,0,w,h)
		DrawBox(0,0,w,tallbar)
		DrawShadowText("Статистика", "reports_8", w * .5, tallbar_c, Color(255,255,255), 1, 1)
	end

	local month_total_reps = 0

	local scroll = vgui.Create("DScrollPanel", main)
	scroll:SetPos(2, tallbar + 2)
	scroll:SetSize(main:GetWide() - 4, main:GetTall() - tallbar - 4)

	local p1 = vgui.Create("DPanel", scroll)
	p1:Dock(TOP)
	p1:DockMargin(2, 1, 2, 1)
	p1:SetTall(main:GetTall() * .15)
	p1.Paint = function(self, w, h)
		DrawBox(0,0,w,h)
	end

	local ava2 = vgui.Create("rp_avatar", p1)
	ava2:SetSize(p1:GetTall() - 8, p1:GetTall() - 8)
	ava2:SetPos(scroll:GetWide() * .5 - ava2:GetWide()*.5, 4)
	ava2:SetSteamID(v.steamid, 184)

	local p2 = vgui.Create("DPanel", scroll)
	p2:Dock(TOP)
	p2:DockMargin(2, 1, 2, 1)
	p2:SetTall(fh + 8)
	p2.Paint = function(self, w, h)
		DrawBox(0,0,w,h)
		DrawShadowText(v.name, "reports_10", w * .5, h * .5, Color(255,255,255), 1, 1)
	end

	local p2 = vgui.Create("DButton", scroll)
	p2:Dock(TOP)
	p2:DockMargin(2, 1, 2, 1)
	p2:SetTall(fh + 8)
	p2:SetText('')
	p2.Paint = function(self, w, h)
		DrawBox(0,0,w,h)
		DrawShadowText(util.SteamIDFrom64(v.steamid), "reports_10", w * .5, h * .5, Color(255,255,255), 1, 1)
	end
	p2.DoClick = function()
		surface.PlaySound("garrysmod/ui_click.wav")
		SetClipboardText(util.SteamIDFrom64(v.steamid))
	end

	local p3 = vgui.Create("DPanel", scroll)
	p3:Dock(TOP)
	p3:DockMargin(2, 1, 2, 1)
	p3:SetTall(fh + 8)
	p3.Paint = function(self, w, h)
		DrawBox(0,0,w,h)
		DrawShadowText(freports.FormatRankName(v.rank), "reports_10", w*.5, h*.5, freports.FormatRankColor(v.rank), 1, 1)
	end

	local p4 = vgui.Create("DPanel", scroll)
	p4:Dock(TOP)
	p4:DockMargin(2, 1, 2, 1)
	p4:SetTall(fh + fh + 10)
	p4.Paint = function(self, w, h)
		DrawBox(0,0,w,h)
		DrawShadowText("Последний раз заходил" , "reports_10", w*.5, 2, Color(255,255,255), 1, 0)
		DrawShadowText(os.date("%d/%m/%Y - %H:%M", v.last_seen) , "reports_10", w*.5, h - fh - 2, Color(255,255,255), 1, 0)
	end

	local p5 = vgui.Create("DPanel", scroll)
	p5:Dock(TOP)
	p5:DockMargin(2, 1, 2, 1)
	p5:SetTall(fh + 8)
	p5.Paint = function(self, w, h)
		DrawBox(0,0,w,h)
		DrawShadowText("Репутация: " .. v.rep , "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
	end

	local p6 = vgui.Create("DPanel", scroll)
	p6:Dock(TOP)
	p6:DockMargin(2, 1, 2, 1)
	p6:SetTall(fh + 8)
	p6.Paint = function(self, w, h)
		DrawBox(0,0,w,h)
		DrawShadowText("Всего жалоб: " .. v.total_reports , "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
	end

	local p6 = vgui.Create("DPanel", scroll)
	p6:Dock(TOP)
	p6:DockMargin(2, 1, 2, 1)
	p6:SetTall(fh + 8)
	p6.Paint = function(self, w, h)
		DrawBox(0,0,w,h)
		DrawShadowText("Жалоб за месяц: " .. month_total_reps , "reports_10", w*.5, h*.5, Color(255,255,255), 1, 1)
	end

	local p7 = vgui.Create("DPanel", scroll)
	p7:Dock(TOP)
	p7:DockMargin(2, 1, 2, 1)
	p7:SetTall(fh + 8)
	p7.Paint = function(self, w, h)
		DrawBox(0,0,w,h)
		DrawShadowText("Онлайн", "reports_8", w*.5, h*.5, Color(255, 255, 255), 1, 1)
	end

	if not istable(v.daily_online) then
		v.daily_online = util.JSONToTable(v.daily_online)
	end
	local temp_month = {}

	for k,v in pairs(v.daily_online) do
		temp_month[#temp_month + 1] = {k, v}
	end

	table.sort( temp_month, function( a, b ) return a[1] < b[1] end )

	for _,v in ipairs(temp_month) do
		local bar = vgui.Create("DPanel", scroll)
		bar:Dock(TOP)
		bar:DockMargin(2,1,2,1)
		bar:SetTall(fh + 4)
		bar.process = 0
		bar.Paint = function(self,w,h)
			surface.SetDrawColor(0,0,0,100)
			surface.DrawRect(0,0,w,h)

			self.process = Lerp( 0.06, self.process, (w - 4) * v[2] / 86400)

			surface.SetDrawColor(111,255,111,100)
			surface.DrawRect(2,2,self.process,h-4)

			DrawShadowText(v[1], "reports_10", 2, h*.5, Color(255, 255, 255), 0, 1)
			DrawShadowText(FormatPlayedTime(v[2]), "reports_10", w - 2, h*.5, Color(255, 255, 255), 2, 1)
		end
	end

	local p8 = vgui.Create("DPanel", scroll)
	p8:Dock(TOP)
	p8:DockMargin(2, 1, 2, 1)
	p8:SetTall(fh + 8)
	p8.Paint = function(self, w, h)
		DrawBox(0,0,w,h)
		DrawShadowText("Жалобы", "reports_8", w*.5, h*.5, Color(255, 255, 255), 1, 1)
	end

	if not istable(v.daily_reports) then
		v.daily_reports = util.JSONToTable(v.daily_reports)
	end
	local temp_month = {}

	for k,v in pairs(v.daily_reports) do
		temp_month[#temp_month + 1] = {k, v}
	end

	table.sort( temp_month, function( a, b ) return a[1] < b[1] end )
	for _,v in ipairs(temp_month) do
		month_total_reps = month_total_reps + v[2]
		local bar = vgui.Create("DPanel", scroll)
		bar:Dock(TOP)
		bar:DockMargin(2,1,2,1)
		bar:SetTall(fh + 4)
		bar.process = 0
		bar.Paint = function(self,w,h)
			surface.SetDrawColor(0,0,0,100)
			surface.DrawRect(0,0,w,h)

			self.process = Lerp( 0.06, self.process, (w - 4) * v[2] / 100)

			surface.SetDrawColor(255,255,100,100)
			surface.DrawRect(2,2,self.process,h-4)

			DrawShadowText(v[1], "reports_10", 2, h*.5, Color(255, 255, 255), 0, 1)
			DrawShadowText(v[2] .. " жб", "reports_10", w - 2, h*.5, Color(255, 255, 255), 2, 1)
		end
	end
end)