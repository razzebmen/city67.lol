--[[---------------------------------------------------------------------------
ZCity RP — кастомный scoreboard (Tab меню)
---------------------------------------------------------------------------
Перенесён 1:1 из gamemodes/zcity/.../cl_init.lua (city67 - Copy).
Зависимости (colBlue, colBlueUp, lply, OpenPlayerSoundSettings, hg.playerInfo)
подложены в шапке этого файла.
---------------------------------------------------------------------------]]
if SERVER then return end

local scoreBoardMenu
local Dynamic = 0

local colGray         = Color(122,122,122,255)
local colBlue         = Color(130, 10, 10)
local colBlueUp       = Color(160, 30, 30)
local colVip          = Color(95, 70, 25, 255)
local colVipUp        = Color(120, 95, 35, 255)
local colVipText      = Color(255, 210, 90, 255)
local col             = Color(255,255,255,255)
local colSpect1       = Color(75, 75, 75, 255)
local colSpect2       = Color(85, 85, 85, 255)
local colorBG         = Color(55, 55, 55, 255)
local colorBGBlacky   = Color(40, 40, 40, 255)

hg               = hg or {}
hg.playerInfo    = hg.playerInfo or {}
hg.muteall       = hg.muteall or false
hg.mutespect     = hg.mutespect or false

-- VIP-индикатор: маленькая жёлтая звезда и золотистая подсветка строки в табе.
-- Только реальные VIP-донатеры. Админы скрыты намеренно — они сохраняют
-- VIP-привилегии (см. ZCITY_SKINS.VipGroups в zcity_skins/sh_config.lua),
-- но в табе не выделяются, чтобы не "светить" стафф-статус.
local VIP_GROUPS = {
    vip = true,
}
local function IsVipPly(ply)
    return IsValid(ply) and VIP_GROUPS[ply:GetUserGroup()] == true
end

local lply = LocalPlayer()
hook.Add("Think", "ZCity_RP_Scoreboard_UpdateLPly", function()
    lply = LocalPlayer()
end)

local function addToPlayerInfo(ply, muted, volume)
    if not IsValid(ply) then return end
    hg.playerInfo[ply:SteamID()] = {muted and true or false, volume}
    file.Write("zcity_muted.txt", util.TableToJSON(hg.playerInfo))
end

local function OpenPlayerSoundSettings(selfa, ply)
    if not IsValid(ply) then return end
    local Menu = DermaMenu()

    if not hg.playerInfo[ply:SteamID()] or not istable(hg.playerInfo[ply:SteamID()]) then
        addToPlayerInfo(ply, false, 1)
    end

    local mute = Menu:AddOption("Mute", function(self)
        if hg.muteall or hg.mutespect then return end
        self:SetChecked(not ply:IsMuted())
        ply:SetMuted(not ply:IsMuted())
        if IsValid(selfa) then
            selfa:SetImage(not ply:IsMuted() and "icon16/sound.png" or "icon16/sound_mute.png")
        end
        addToPlayerInfo(ply, ply:IsMuted(), hg.playerInfo[ply:SteamID()][2])
    end)
    mute:SetIsCheckable(true)
    mute:SetChecked(ply:IsMuted())

    local volumeSlider = vgui.Create("DSlider", Menu)
    volumeSlider:SetLockY(0.5)
    volumeSlider:SetTrapInside(true)
    volumeSlider:SetSlideX(hg.playerInfo[ply:SteamID()][2])
    volumeSlider.OnValueChanged = function(self, x, y)
        if not IsValid(ply) then return end
        if hg.muteall or (hg.mutespect and not ply:Alive()) then return end
        hg.playerInfo[ply:SteamID()][2] = x
        ply:SetVoiceVolumeScale(hg.playerInfo[ply:SteamID()][2])
        addToPlayerInfo(ply, ply:IsMuted(), hg.playerInfo[ply:SteamID()][2])
    end
    function volumeSlider:Paint(w,h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0,0,0))
        draw.RoundedBox(0, 0, 0, w*self:GetSlideX(), h, Color(255,0,0))
        draw.DrawText((math.Round(100*self:GetSlideX(), 0)).."%", "DermaDefault", w/2, h/4, color_white, TEXT_ALIGN_CENTER)
    end
    function volumeSlider.Knob.Paint(self) end

    Menu:AddPanel(volumeSlider)
    Menu:Open()
end

hook.Add("Player Disconnected", "ZCity_RP_Scoreboard_Cleanup", function()
    if IsValid(scoreBoardMenu) then
        scoreBoardMenu:Remove()
        scoreBoardMenu = nil
    end
end)

local function ZCity_OpenScoreboard()
	if IsValid(scoreBoardMenu) then
		scoreBoardMenu:Remove()
		scoreBoardMenu = nil
	end
	Dynamic = 0
	scoreBoardMenu = vgui.Create("ZFrame")

	local sizeX,sizeY = ScrW() / 1.3 ,ScrH() / 1.2
	local posX,posY = ScrW() / 2 - sizeX / 2,ScrH() / 2 - sizeY / 2

	scoreBoardMenu:SetPos(posX,posY)
	scoreBoardMenu:SetSize(sizeX,sizeY)
	scoreBoardMenu:MakePopup()
	scoreBoardMenu:SetKeyboardInputEnabled( false )
	scoreBoardMenu:ShowCloseButton( false )

	local muteallbut = vgui.Create("DButton", scoreBoardMenu)
	local w, h = ScreenScale(30),ScreenScale(6)
	muteallbut:SetPos(scoreBoardMenu:GetWide()-w*2.3,scoreBoardMenu:GetTall() - h * 1.5)
	muteallbut:SetSize(w, h)
	muteallbut:SetText("Mute all")
	
	muteallbut.Paint = function(self,w,h)
		surface.SetDrawColor( not hg.muteall and 255 or 0, hg.muteall and 255 or 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
	end

	muteallbut.DoClick = function(self,w,h)
		hg.muteall = not hg.muteall
		
		for i,ply in player.Iterator() do
			if hg.muteall then
				//ply.oldmutedspect = ply:IsMuted()

				ply:SetVoiceVolumeScale(0)
				//if IsValid(ply.soundButton) then
					//ply.soundButton:SetImage(not ply:IsMuted() && "icon16/sound.png" || "icon16/sound_mute.png")
				//end
			else
				ply:SetVoiceVolumeScale((!hg.mutespect or ply:Alive()) and (hg.playerInfo[ply:SteamID()] and hg.playerInfo[ply:SteamID()][2] or 1) or 0)
				//ply:SetMuted(ply.oldmuted)
				//if IsValid(ply.soundButton) then
					//ply.soundButton:SetImage(not ply:IsMuted() && "icon16/sound.png" || "icon16/sound_mute.png")
				//end
				//ply.oldmuted = nil
			end
		end 
	end

	local mutespectbut = vgui.Create("DButton", scoreBoardMenu)
	local w, h = ScreenScale(30),ScreenScale(6)
	mutespectbut:SetPos(scoreBoardMenu:GetWide()-w*1.2,scoreBoardMenu:GetTall() - h * 1.5)
	mutespectbut:SetSize(w, h)
	mutespectbut:SetText("Mute spectators")
	
	mutespectbut.Paint = function(self,w,h)
		surface.SetDrawColor( not hg.mutespect and 255 or 0, hg.mutespect and 255 or 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
	end

	mutespectbut.DoClick = function(self,w,h)
		hg.mutespect = not hg.mutespect
		
		for i,ply in player.Iterator() do
			if ply:Alive() then continue end

			if hg.mutespect then
				ply:SetVoiceVolumeScale(0)
				//ply.oldmutedspect = ply:IsMuted()

				//ply:SetMuted(true)
				//if IsValid(ply.soundButton) then
					//ply.soundButton:SetImage(not ply:IsMuted() && "icon16/sound.png" || "icon16/sound_mute.png")
				//end
			else
				ply:SetVoiceVolumeScale(!hg.muteall and (hg.playerInfo[ply:SteamID()] and hg.playerInfo[ply:SteamID()][2] or 1) or 0)
				//ply:SetMuted(ply.oldmutedspect)
				//if IsValid(ply.soundButton) then
					//ply.soundButton:SetImage(not ply:IsMuted() && "icon16/sound.png" || "icon16/sound_mute.png")
				//end
				//ply.oldmutedspect = nil
			end
		end 
	end

	local ServerName = GetHostName() or "ZCity | Developer Server | #01"
	local tick
	scoreBoardMenu.PaintOver = function(self,w,h)
		surface.SetDrawColor( 255, 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )

		surface.SetFont( "ZB_InterfaceLarge" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize(ServerName)
		surface.SetTextPos(w / 2 - lengthX/2,10)
		surface.DrawText(ServerName)

		surface.SetFont( "ZB_InterfaceSmall" )
		surface.SetTextColor(col.r,col.g,col.b,col.a*0.1)
		local txt = "ZC Version: "..hg.Version
		local lengthX, lengthY = surface.GetTextSize(txt)
		surface.SetTextPos(w*0.01,h - lengthY - h*0.01)
		surface.DrawText(txt)

		surface.SetFont( "ZB_InterfaceMediumLarge" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize("Players:")
		surface.SetTextPos(w / 4 - lengthX/2,ScreenScale(25))
		surface.DrawText("Players:")

		surface.SetFont( "ZB_InterfaceMediumLarge" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize("Spectators:")
		surface.SetTextPos(w * 0.75 - lengthX/2,ScreenScale(25))
		surface.DrawText("Spectators:")
		tick = math.Round(1 / engine.ServerFrameTime())
		local txt = "SV Tick: " .. tick
		local lengthX, lengthY = surface.GetTextSize(txt)
		surface.SetTextPos(w * 0.5 - lengthX/2,ScreenScale(25))
		surface.DrawText(txt)
	end
	-- TEAMSELECTION
	if LocalPlayer():Team() ~= TEAM_SPECTATOR then
		local SPECTATE = vgui.Create("DButton",scoreBoardMenu)
		SPECTATE:SetPos(sizeX * 0.925,sizeY * 0.095)
		SPECTATE:SetSize(ScrW() / 20,ScrH() / 30)
		SPECTATE:SetText("")
		
		SPECTATE.DoClick = function()
			net.Start("ZB_SpecMode")
				net.WriteBool(true)
			net.SendToServer()
			scoreBoardMenu:Remove()
			scoreBoardMenu = nil
		end

		SPECTATE.Paint = function(self,w,h)
			surface.SetDrawColor( 255, 0, 0, 128)
			surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
			surface.SetFont( "ZB_InterfaceMedium" )
			surface.SetTextColor(col.r,col.g,col.b,col.a)
			local lengthX, lengthY = surface.GetTextSize("Join")
			surface.SetTextPos( lengthX - lengthX/2, 2)
			surface.DrawText("Join")
		end
	end

	if LocalPlayer():Team() == TEAM_SPECTATOR then
		local PLAYING = vgui.Create("DButton",scoreBoardMenu)
		PLAYING:SetPos(sizeX * 0.010,sizeY * 0.095)
		PLAYING:SetSize(ScrW() / 20,ScrH() / 30)
		PLAYING:SetText("")
		
		PLAYING.DoClick = function()
			net.Start("ZB_SpecMode")
				net.WriteBool(false)
			net.SendToServer()
			scoreBoardMenu:Remove()
			scoreBoardMenu = nil
		end

		PLAYING.Paint = function(self,w,h)
			surface.SetDrawColor( 255, 0, 0, 128)
			surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
			surface.SetFont( "ZB_InterfaceMedium" )
			surface.SetTextColor(col.r,col.g,col.b,col.a)
			local lengthX, lengthY = surface.GetTextSize("Join")
			surface.SetTextPos( lengthX - lengthX/2, 2)
			surface.DrawText("Join")
		end
	end

	--без матов

	local DScrollPanel = vgui.Create("DScrollPanel", scoreBoardMenu)
	DScrollPanel:SetPos(10, ScreenScaleH(58))
	DScrollPanel:SetSize(sizeX/2 - 10, sizeY - ScreenScaleH(72))
	function DScrollPanel:Paint( w, h )
		-- BlurBackground(self)

		surface.SetDrawColor(0, 0, 0, 125)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor( 255, 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
	end

	local disappearance = lply:GetNetVar("disappearance", nil)
	
	-- Группируем игроков по профессиям
	local playersByJob = {}
	for i, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		if CurrentRound and CurrentRound() and CurrentRound().name == "fear" and !ply:Alive() then continue end
		if disappearance and ply != lply then continue end
		
		local jobName = ply:GetNWString("RoleplayJob", "Гражданский")
		playersByJob[jobName] = playersByJob[jobName] or {}
		table.insert(playersByJob[jobName], ply)
	end
	
	-- Отображаем игроков по группам профессий в заданном порядке
	local jobOrder = {
		"Мэр",
		"Глава Полиции",
		"Спецназ",
		"Полицейский",
		"Глава ЦАХАЛ",
		"Солдат ЦАХАЛ",
		"Медик",
		"Продавец Оружия",
		"Бандит",
		"Гражданский"
	}
	
	for _, jobName in ipairs(jobOrder) do
		local players = playersByJob[jobName]
		if not players then continue end
		-- Заголовок профессии
		local jobHeader = vgui.Create("DPanel", DScrollPanel)
		jobHeader:SetSize(100, ScreenScaleH(18))
		jobHeader:Dock(TOP)
		jobHeader:DockMargin(8, 8, 8, 2)
		
		jobHeader.Paint = function(self, w, h)
			-- Живой подсчёт каждый кадр — без устаревших данных
			local liveCount = 0
			local colorRef
			for i, p in player.Iterator() do
				if p:Team() == TEAM_SPECTATOR then continue end
				if p:GetNWString("RoleplayJob", "Гражданский") == jobName then
					liveCount = liveCount + 1
					if not colorRef and IsValid(p) then colorRef = p end
				end
			end
			if liveCount == 0 then return end

			local ref = colorRef or (IsValid(players[1]) and players[1])
			if not ref then return end
			local jobColorVec = ref:GetNWVector("RoleplayJobColor", Vector(0.5, 0.5, 0.5))
			local jobColor = Color(jobColorVec.x * 255, jobColorVec.y * 255, jobColorVec.z * 255)

			surface.SetDrawColor(jobColor.r * 0.3, jobColor.g * 0.3, jobColor.b * 0.3, 200)
			surface.DrawRect(0, 0, w, h)

			surface.SetFont("ZB_InterfaceMediumLarge")
			surface.SetTextColor(jobColor.r, jobColor.g, jobColor.b, 255)
			local txt = jobName .. " (" .. liveCount .. ")"
			local lengthX, lengthY = surface.GetTextSize(txt)
			surface.SetTextPos(10, h / 2 - lengthY / 2)
			surface.DrawText(txt)
		end
		
		DScrollPanel:AddItem(jobHeader)
		
		-- Игроки в этой профессии
		for _, ply in ipairs(players) do
			local but = vgui.Create("DButton", DScrollPanel)
			but:SetSize(100, ScreenScaleH(22))
			but:Dock(TOP)
			but:DockMargin(8, 2, 8, -1)
			but:SetText("")
			
			-- Аватарка игрока
			local avatar = vgui.Create("AvatarImage", but)
			avatar:SetPos(5, 5)
			avatar:SetSize(ScreenScaleH(22) - 10, ScreenScaleH(22) - 10)
			avatar:SetPlayer(ply, 64)
			
			local soundButton = vgui.Create("DImageButton", but)
			soundButton:Dock(RIGHT)
			soundButton:SetSize( 30, 0 )
			soundButton:DockMargin(5,10,45,10)
			
			soundButton:SetImage(not ply:IsMuted() && "icon16/sound.png" || "icon16/sound_mute.png") 
			soundButton.DoClick = function(self)
				OpenPlayerSoundSettings(self, ply) 
			end
			ply.soundButton = soundButton
		
			but.Paint = function(self, w, h)
				if not IsValid(ply) then return end
				local vip = IsVipPly(ply)
				if vip then
					surface.SetDrawColor(colVipUp.r, colVipUp.g, colVipUp.b, colVipUp.a)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(colVip.r, colVip.g, colVip.b, colVip.a)
					surface.DrawRect(0, h / 2, w, h / 2)
					-- мягкая жёлтая полоска-акцент слева
					surface.SetDrawColor(255, 200, 90, 200)
					surface.DrawRect(0, 0, 3, h)
				else
					surface.SetDrawColor(colBlueUp.r, colBlueUp.g, colBlueUp.b, colBlueUp.a)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(colBlue.r, colBlue.g, colBlue.b, colBlue.a)
					surface.DrawRect(0, h / 2, w, h / 2)
				end

				-- Ник игрока (для VIP — золотистый, плюс ★ перед именем)
				surface.SetFont("ZB_InterfaceMediumLarge")
				local nameClr = vip and colVipText or col
				surface.SetTextColor(nameClr.r, nameClr.g, nameClr.b, nameClr.a)
				local nick = ply:GetPlayerName() or "He quited..."
				local display = vip and ("★ " .. nick) or nick
				local lengthX, lengthY = surface.GetTextSize(display)
				surface.SetTextPos(ScreenScaleH(22) + 10, h / 2 - lengthY / 2)
				surface.DrawText(display)
		
				-- Пинг
				surface.SetFont("ZB_InterfaceMediumLarge")
				surface.SetTextColor(col.r, col.g, col.b, col.a)
				local lengthX2, lengthY2 = surface.GetTextSize(ply:Ping() or "He quited...")
				surface.SetTextPos(w - lengthX2 - 15, h / 2 - lengthY2 / 2)
				surface.DrawText(ply:Ping() or "He quited...")
			end

			function but:DoClick()
				if ply:IsBot() then chat.AddText(Color(255,0,0), "no, you can't") return end
				gui.OpenURL("https://steamcommunity.com/profiles/"..ply:SteamID64())
			end

			function but:DoRightClick()
				local Menu = DermaMenu()
				Menu:AddOption( "Account", function(self)
					zb.Experience.AccountMenu( ply )
				end)
				Menu:AddOption( "Copy SteamID", function(self)
					SetClipboardText(ply:SteamID())
				end)

				Menu:Open()
			end
		
			DScrollPanel:AddItem(but)
		end
	end
	-- SPECTATORS
	local DScrollPanel = vgui.Create("DScrollPanel", scoreBoardMenu)
	DScrollPanel:SetPos(sizeX/2 + 5, ScreenScaleH(58))
	DScrollPanel:SetSize(sizeX/2 - 15, sizeY - ScreenScaleH(72))
	function DScrollPanel:Paint( w, h )
		-- BlurBackground(self)

		surface.SetDrawColor(0, 0, 0, 125)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor( 255, 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
	end

	-- Группируем спектаторов по профессиям
	local spectatorsByJob = {}
	for i, ply in player.Iterator() do
		if ply:Team() ~= TEAM_SPECTATOR then continue end
		if CurrentRound().name == "fear" and !ply:Alive() then continue end
		if disappearance and ply != lply then continue end
		
		local jobName = ply:GetNWString("RoleplayJob", "")
		-- Если профессии нет (пустая строка), показываем как "Наблюдатели"
		if jobName == "" then
			jobName = "Наблюдатели"
		end
		spectatorsByJob[jobName] = spectatorsByJob[jobName] or {}
		table.insert(spectatorsByJob[jobName], ply)
	end
	
	-- Отображаем спектаторов по группам профессий в заданном порядке
	local jobOrder = {
		"Наблюдатели",
		"Мэр",
		"Глава Полиции",
		"Спецназ",
		"Полицейский",
		"Глава ЦАХАЛ",
		"Солдат ЦАХАЛ",
		"Медик",
		"Продавец Оружия",
		"Бандит",
		"Гражданский"
	}
	
	for _, jobName in ipairs(jobOrder) do
		local players = spectatorsByJob[jobName]
		if not players then continue end
		-- Заголовок профессии
		local jobHeader = vgui.Create("DPanel", DScrollPanel)
		jobHeader:SetSize(100, ScreenScaleH(18))
		jobHeader:Dock(TOP)
		jobHeader:DockMargin(8, 8, 8, 2)
		
		jobHeader.Paint = function(self, w, h)
			-- Получаем цвет профессии от первого игрока в группе
			local jobColor
			if jobName == "Наблюдатели" then
				-- Серый цвет для наблюдателей
				jobColor = Color(150, 150, 150)
			else
				local jobColorVec = players[1]:GetNWVector("RoleplayJobColor", Vector(0.5, 0.5, 0.5))
				jobColor = Color(jobColorVec.x * 255, jobColorVec.y * 255, jobColorVec.z * 255)
			end
			
			surface.SetDrawColor(jobColor.r * 0.2, jobColor.g * 0.2, jobColor.b * 0.2, 200)
			surface.DrawRect(0, 0, w, h)
			
			surface.SetFont("ZB_InterfaceMediumLarge")
			surface.SetTextColor(jobColor.r, jobColor.g, jobColor.b, 255)
			local txt = jobName .. " (" .. #players .. ")"
			local lengthX, lengthY = surface.GetTextSize(txt)
			surface.SetTextPos(10, h / 2 - lengthY / 2)
			surface.DrawText(txt)
		end
		
		DScrollPanel:AddItem(jobHeader)
		
		-- Спектаторы в этой профессии
		for _, ply in ipairs(players) do
			local but = vgui.Create("DButton", DScrollPanel)
			but:SetSize(100, ScreenScaleH(22))
			but:Dock(TOP)
			but:DockMargin( 8, 2, 8, -1 )
			but:SetText("")

			-- Аватарка игрока
			local avatar = vgui.Create("AvatarImage", but)
			avatar:SetPos(5, 5)
			avatar:SetSize(ScreenScaleH(22) - 10, ScreenScaleH(22) - 10)
			avatar:SetPlayer(ply, 64)

			local soundButton = vgui.Create("DImageButton", but)
			soundButton:Dock(RIGHT)
			soundButton:SetSize( 30, 0 )
			soundButton:DockMargin(5,10,45,10)
			
			soundButton:SetImage(not ply:IsMuted() && "icon16/sound.png" || "icon16/sound_mute.png") 
			soundButton.DoClick = function(self)
				OpenPlayerSoundSettings(self, ply)
			end
			ply.soundButton = soundButton

			but.Paint = function(self,w,h)
				if not IsValid(ply) then return end
				surface.SetDrawColor(colSpect2.r,colSpect2.g,colSpect2.b,colSpect2.a)
				surface.DrawRect(0,0,w,h)
				surface.SetDrawColor(colSpect1.r,colSpect1.g,colSpect1.b,colSpect1.a)
				surface.DrawRect(0,h/2,w,h/2)

				-- Ник игрока
				surface.SetFont( "ZB_InterfaceMediumLarge" )
				surface.SetTextColor(col.r,col.g,col.b,col.a)
				local lengthX, lengthY = surface.GetTextSize( ply:Name() or "He quited..." )
				surface.SetTextPos(ScreenScaleH(22) + 10,h/2 - lengthY/2)
				surface.DrawText(ply:GetPlayerName() or "He quited...")

				-- Пинг
				surface.SetFont( "ZB_InterfaceMediumLarge" )
				surface.SetTextColor(col.r,col.g,col.b,col.a)
				local lengthX, lengthY = surface.GetTextSize( ply:Ping() or "He quited..." )
				surface.SetTextPos(w - lengthX -15,h/2 - lengthY/2)
				surface.DrawText(ply:Ping() or "He quited...")
			end

			function but:DoClick()
				if ply:IsBot() then chat.AddText("That bot.") return end
				gui.OpenURL("https://steamcommunity.com/profiles/"..ply:SteamID64())
			end

			function but:DoRightClick()
				local Menu = DermaMenu()
				Menu:AddOption( "Account", function(self)
					zb.Experience.AccountMenu( ply )
				end)
				Menu:AddOption( "Copy SteamID", function(self)
					SetClipboardText(ply:SteamID())
				end)

				Menu:Open()
			end

			DScrollPanel:AddItem(but)
		end
	end

	return true
end

local function ZCity_CloseScoreboard()
	if IsValid(scoreBoardMenu) then
		scoreBoardMenu:Close()
		scoreBoardMenu = nil
	end
end

hook.Add("ScoreboardShow", "ZCity_RP_Scoreboard", function()
    ZCity_OpenScoreboard()
    return true
end)

hook.Add("ScoreboardHide", "ZCity_RP_Scoreboard", function()
    ZCity_CloseScoreboard()
    return true
end)

print("[ZCity RP] Custom scoreboard (Tab) loaded")