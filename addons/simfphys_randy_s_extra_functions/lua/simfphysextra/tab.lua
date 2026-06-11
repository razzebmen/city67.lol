--moved the tab menu here

--local k_act1 = CreateClientConVar( "cl_simfphys_actionkey1", KEY_G , true, true )
--local k_act2 = CreateClientConVar( "cl_simfphys_actionkey2", KEY_J , true, true )

local function buildExtraSettingsMenu( self )
	local Shape = vgui.Create( "DShape", self.PropPanel )
	Shape:SetType( "Rect" )
	Shape:SetPos( 20, 20 )
	Shape:SetSize( 350, 400 )
	Shape:SetColor( Color( 0, 0, 0, 200 ) )
	
	local y = 25
	local Label1 = vgui.Create( "DLabel", self.PropPanel )
	Label1:SetPos( 25, y )
	Label1:SetSize( 340, 25 )
	Label1:SetText( "Clientside settings:" )
	y = y + 25
	
	local cboxColors = vgui.Create( "DCheckBoxLabel", self.PropPanel )
	cboxColors:SetPos( 25,y )
	cboxColors:SetText( "Use Random Colors" )
	cboxColors:SetConVar( GetConVar( "cl_simfphys_randomcolors" ):GetName() )
	cboxColors:SetValue( GetConVar( "cl_simfphys_randomcolors" ):GetInt() )
	cboxColors:SizeToContents()
	y = y + 25
	
	local cboxBodygroup = vgui.Create( "DCheckBoxLabel", self.PropPanel)
	cboxBodygroup:SetPos( 25,y )
	cboxBodygroup:SetText( "Use Random Bodygroups" )
	cboxBodygroup:SetConVar( GetConVar( "cl_simfphys_randombodygroups" ):GetName() )
	cboxBodygroup:SetValue( GetConVar( "cl_simfphys_randombodygroups" ):GetInt() )
	cboxBodygroup:SizeToContents()
	y = y + 25
	
	local cboxBodygroup = vgui.Create( "DCheckBoxLabel", self.PropPanel)
	cboxBodygroup:SetPos( 25,y )
	cboxBodygroup:SetText( "Use Presets" )
	cboxBodygroup:SetConVar( GetConVar( "cl_simfphys_vehiclepresets" ):GetName() )
	cboxBodygroup:SetValue( GetConVar( "cl_simfphys_vehiclepresets" ):GetInt() )
	cboxBodygroup:SizeToContents()
	y = y + 25
	
	local cboxBus = vgui.Create( "DCheckBoxLabel", self.PropPanel)
	cboxBus:SetPos( 25,y )
	cboxBus:SetText( "Apply handbrake when bus doors are open" )
	cboxBus:SetConVar( GetConVar( "cl_simfphys_bus_safety_brakes" ):GetName() )
	cboxBus:SetValue( GetConVar( "cl_simfphys_bus_safety_brakes" ):GetInt() )
	cboxBus:SizeToContents()
	y = y + 25
	
	local cboxFuel = vgui.Create( "DCheckBoxLabel", self.PropPanel)
	cboxFuel:SetPos( 25,y )
	cboxFuel:SetText( "Spawn with random fuel amount" )
	cboxFuel:SetConVar( GetConVar( "cl_simfphys_randomfuel" ):GetName() )
	cboxFuel:SetValue( GetConVar( "cl_simfphys_randomfuel" ):GetInt() )
	cboxFuel:SizeToContents()
	y = y + 25
	
	local sliderFuel = vgui.Create( "DNumSlider", self.PropPanel)
	sliderFuel:SetPos( 25,y )
	sliderFuel:SetSize( 345, 25 )
	sliderFuel:SetText( "Min. Fuel Percentage" )
	sliderFuel:SetMin( 0 )
	sliderFuel:SetMax( 100 )
	sliderFuel:SetDecimals( 0 )
	sliderFuel:SetConVar( "cl_simfphys_randomfuel_min" )
	sliderFuel:SetValue( 10 )
	y = y + 35
	
	--[[
	local Label1 = vgui.Create( "DLabel", self.PropPanel )
	Label1:SetPos( 25, y )
	Label1:SetSize( 340, 25 )
	Label1:SetText( "Vehicle-Specific Action Keys:" )
	y = y + 25
	
	local Label1 = vgui.Create( "DLabel", self.PropPanel )
	Label1:SetPos( 25, y )
	Label1:SetSize( 340, 25 )
	Label1:SetText( "Action Key 1:" )
	
	local act1Binder = vgui.Create( "DBinder", self.PropPanel)
	act1Binder:SetPos( 100, y )
	act1Binder:SetSize( 65, 25 )
	act1Binder:SetValue( GetConVar( "cl_simfphys_actionkey1" ):GetInt() )
	function act1Binder:SetSelectedNumber( k_act1 )
		self.m_iSelectedNumber = k_act1
		self:ConVarChanged( "cl_simfphys_actionkey1" ) 
		self:UpdateText() 
		self:OnChange( k_act1 ) 
	end
	y = y + 25
	
	local Label1 = vgui.Create( "DLabel", self.PropPanel )
	Label1:SetPos( 25, y )
	Label1:SetSize( 340, 25 )
	Label1:SetText( "Action Key 2:" )
	
	local act2Binder = vgui.Create( "DBinder", self.PropPanel)
	act2Binder:SetPos( 100, y )
	act2Binder:SetSize( 65, 25 )
	act2Binder:SetValue( GetConVar( "cl_simfphys_actionkey2" ):GetInt() )
	function act1Binder:SetSelectedNumber( k_act2 )
		self.m_iSelectedNumber = k_act2
		self:ConVarChanged( "cl_simfphys_actionkey2" ) 
		self:UpdateText() 
		self:OnChange( k_act2 ) 
	end
	y = y + 25]]
	
	local Label1 = vgui.Create( "DLabel", self.PropPanel )
	Label1:SetPos( 25, y )
	Label1:SetSize( 340, 25 )
	Label1:SetText( "Serverside settings:" )
	y = y + 25
	
	if LocalPlayer():IsSuperAdmin() then
		local cboxPlates = vgui.Create( "DCheckBoxLabel", self.PropPanel)
		cboxPlates:SetPos( 25,y )
		cboxPlates:SetText( "Apply random license plates to vehicles" )
		--cboxPlates:SetConVar( GetConVar( "sv_simfphys_license_plates" ):GetName() )
		cboxPlates:SetValue( GetConVar( "sv_simfphys_license_plates" ):GetInt() )
		cboxPlates:SizeToContents()
		y = y + 25
		
		local cboxTrLegs = vgui.Create( "DCheckBoxLabel", self.PropPanel)
		cboxTrLegs:SetPos( 25,y )
		cboxTrLegs:SetText( "Use physical trailer legs" )
		--cboxTrLegs:SetConVar( GetConVar( "sv_simfphys_trailer_legs" ):GetName() )
		cboxTrLegs:SetValue( GetConVar( "sv_simfphys_trailer_legs" ):GetInt() )
		cboxTrLegs:SizeToContents()
		y = y + 25
		
		local cboxBullhorn = vgui.Create( "DCheckBoxLabel", self.PropPanel)
		cboxBullhorn:SetPos( 25,y )
		cboxBullhorn:SetText( "Allow bullhorns" )
		--cboxBullhorn:SetConVar( GetConVar( "sv_simfphys_bullhorn" ):GetName() )
		cboxBullhorn:SetValue( GetConVar( "sv_simfphys_bullhorn" ):GetInt() )
		cboxBullhorn:SizeToContents()
		y = y + 25
		
		--[[local bindAction1 = vgui.Create("DBinder", self.PropPanel)
		bindAction1.OnChange = function(____, butt)
			actionKey1:SetInt(butt)
		end
		bindAction1:SetPos(25, y)
		bindAction1:SetText(
			input.GetKeyName(
				actionKey1:GetInt()
			)
		)
		y = y + 7
		local bindAction1Label = vgui.Create("DLabel", self.PropPanel)
		bindAction1Label:SetText("Action Button 1")
		bindAction1Label:SetPos(100, y)
		bindAction1Label:SizeToContents()
		y = y + 30]] --I tried making bind-able input keys but this shit just doesnt work. If you can fix it please let me know
		
		local cboxBrakes = vgui.Create( "DCheckBoxLabel", self.PropPanel)
		cboxBrakes:SetPos( 25,y )
		cboxBrakes:SetText( "Play braking sounds" )
		--cboxBrakes:SetConVar( GetConVar( "sv_simfphys_brakenoises" ):GetName() )
		cboxBrakes:SetValue( GetConVar( "sv_simfphys_brakenoises" ):GetInt() )
		cboxBrakes:SizeToContents()
		y = y + 25
		
		local cboxAlarm = vgui.Create( "DCheckBoxLabel", self.PropPanel)
		cboxAlarm:SetPos( 25,y )
		cboxAlarm:SetText( "Allow Alarms" )
		cboxAlarm:SetValue( GetConVar( "sv_simfphys_alarms" ):GetInt() )
		cboxAlarm:SizeToContents()
		y = y + 25
		
		local cboxIgnition = vgui.Create( "DCheckBoxLabel", self.PropPanel)
		cboxIgnition:SetPos( 25,y )
		cboxIgnition:SetText( "Use advanced ignition" )
		--cboxIgnition:SetConVar( GetConVar( "sv_simfphys_advanced_ignition" ):GetName() )
		cboxIgnition:SetValue( GetConVar( "sv_simfphys_advanced_ignition" ):GetInt() )
		cboxIgnition:SizeToContents()
		y = y + 35
		
		local DermaButton = vgui.Create( "DButton" )
		DermaButton:SetParent( self.PropPanel )
		DermaButton:SetText( "Apply Server Settings" )	
		DermaButton:SetPos( 25, y - 10 )
		DermaButton:SetSize( 340, 25 )
		DermaButton.DoClick = function()
			net.Start("simfphys_extra_settings")
				net.WriteBool( cboxPlates:GetChecked() )
				net.WriteBool( cboxTrLegs:GetChecked() )
				net.WriteBool( cboxBullhorn:GetChecked() )
				net.WriteBool( cboxBrakes:GetChecked() )
				net.WriteBool( cboxIgnition:GetChecked() )
				net.WriteBool( cboxAlarm:GetChecked() )
			net.SendToServer()
		end
	else
		local Label = vgui.Create( "DLabel", self.PropPanel )
		Label:SetPos( 25, y )
		Label:SetText( "License Plates are "..((GetConVar( "sv_simfphys_license_plates" ):GetInt() > 0) and "enabled" or "disabled").."." )
		Label:SizeToContents()
		y = y + 25
		
		local Label = vgui.Create( "DLabel", self.PropPanel )
		Label:SetPos( 25, y )
		Label:SetText( "Advanced Ignition is "..((GetConVar( "sv_simfphys_advanced_ignition" ):GetInt() > 0) and "enabled" or "disabled").."." )
		Label:SizeToContents()
		y = y + 25
		
		local Label = vgui.Create( "DLabel", self.PropPanel )
		Label:SetPos( 25, y )
		Label:SetText( "Bullhorns are "..((GetConVar( "sv_simfphys_bullhorn" ):GetInt() > 0) and "enabled" or "disabled").."." )
		Label:SizeToContents()
		y = y + 25
		
		local Label = vgui.Create( "DLabel", self.PropPanel )
		Label:SetPos( 25, y )
		Label:SetText( "Braking sounds are "..((GetConVar( "sv_simfphys_brakenoises" ):GetInt() > 0) and "enabled" or "disabled").."." )
		Label:SizeToContents()
		y = y + 25
		
		local Label = vgui.Create( "DLabel", self.PropPanel )
		Label:SetPos( 25, y )
		Label:SetText( "Alarms are "..((GetConVar( "sv_simfphys_alarms" ):GetInt() > 0) and "enabled" or "disabled").."." )
		Label:SizeToContents()
		y = y + 25
		
		local Label = vgui.Create( "DLabel", self.PropPanel )
		Label:SetPos( 25, y )
		Label:SetText( "Physical trailer legs are "..((GetConVar( "sv_simfphys_trailer_legs" ):GetInt() > 0) and "enabled" or "disabled").."." )
		Label:SizeToContents()
		y = y + 25
	end
	
	--[[local Reset = vgui.Create( "DButton" )
	Reset:SetParent( self.PropPanel )
	Reset:SetText( "Reset to Default" )	
	Reset:SetPos( 25, y )
	Reset:SetSize( 340, 25 )
	Reset.DoClick = function()
		cboxColors:SetValue( 1 )
		cboxBodygroup:SetValue( 1 )
		cboxBus:SetValue( 1 )
		cboxPlates:SetValue( 1 )
		cboxTrLegs:SetValue( 1 )
		cboxBrakes:SetValue( 1 )
		cboxIgnition:SetValue( 1 )
		cboxBullhorn:SetValue( 1 )
	end]]
end


hook.Add( "SimfphysPopulateVehicles", "RandysExtraSettings", function( pnlContent, tree, node )
	local node = tree:AddNode( "Randy's Extra Settings", "icon16/car_add.png" )
	node.DoPopulate = function( self )
		self.PropPanel = vgui.Create( "ContentContainer", pnlContent )
		self.PropPanel:SetVisible( false )
		self.PropPanel:SetTriggerSpawnlistChange( false )

		buildExtraSettingsMenu( self )
	end
	node.DoClick = function( self )
		self:DoPopulate()
		pnlContent:SwitchPanel( self.PropPanel )
	end
end )
