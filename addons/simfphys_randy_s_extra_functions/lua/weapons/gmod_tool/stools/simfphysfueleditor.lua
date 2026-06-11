
TOOL.Category		= "simfphys"
TOOL.Name			= "#Fuel Editor"
TOOL.Command		= nil
TOOL.ConfigName		= ""

TOOL.ClientConVar[ "maxfuel" ] = 50
TOOL.ClientConVar[ "curfuel" ] = 25

--[[local function SetGears( ply, ent, gears)
	if ( SERVER ) then
		ent.Gears = gears
		duplicator.StoreEntityModifier( ent, "gearmod", gears )
	end
end
duplicator.RegisterEntityModifier( "gearmod", SetGears )]]

if CLIENT then
	language.Add( "tool.simfphysfueleditor.name", "Fuel Editor" )
	language.Add( "tool.simfphysfueleditor.desc", "A tool used to edit fuel amounts of simfphys vehicles" )
	language.Add( "tool.simfphysfueleditor.0", "Left click apply settings. Right click copy settings. Reload to reset" )
	language.Add( "tool.simfphysfueleditor.1", "Left click apply settings. Right click copy settings. Reload to reset" )
end

function TOOL:LeftClick( trace )
	local ent = trace.Entity
	
	if not simfphys.IsCar( ent ) then return false end
	
	if (SERVER) then
		local vname = ent:GetSpawn_List()
		local VehicleList = list.Get( "simfphys_vehicles" )[vname]
		
		local maxfuel = math.Clamp(self:GetClientNumber( "maxfuel" ), 0, 500)
		local curfuel = math.Clamp(self:GetClientNumber( "curfuel" ), 0, 500)
		
		ent:SetFuel(curfuel)
		ent:SetMaxFuel(maxfuel)
	end
	
	return true
end


function TOOL:RightClick( trace )
	local ent = trace.Entity
	local ply = self:GetOwner()
	
	if not simfphys.IsCar( ent ) then return false end
	
	if (SERVER) then
		local vname = ent:GetSpawn_List()
		local VehicleList = list.Get( "simfphys_vehicles" )[vname]
		
		local maxfuel = ent:GetMaxFuel()
		local curfuel = ent:GetFuel()

		ply:ConCommand( "simfphysfueleditor_maxfuel "..maxfuel)
		ply:ConCommand( "simfphysfueleditor_curfuel "..curfuel)
	end
	
	return true
end

function TOOL:Reload( trace )
	local ent = trace.Entity
	local ply = self:GetOwner()
	
	if not simfphys.IsCar( ent ) then return false end
	
	if (SERVER) then
		local vname = ent:GetSpawn_List()
		local VehicleList = list.Get( "simfphys_vehicles" )[vname]
		
		ent:SetMaxFuel( VehicleList.Members.FuelTankSize )
		ent:SetFuel( VehicleList.Members.FuelTankSize )
	end
	
	return true
end

local ConVarsDefault = TOOL:BuildConVarList()
function TOOL.BuildCPanel( panel )
	panel:AddControl( "Header", { Text = "#tool.simfphysfueleditor.name", Description = "#tool.simfphysfueleditor.desc" } )
	panel:AddControl( "ComboBox", { MenuButton = 1, Folder = "fueleditor", Options = { [ "#preset.default" ] = ConVarsDefault }, CVars = table.GetKeys( ConVarsDefault ) } )
	
	local Frame = vgui.Create( "DPanel", panel )
	Frame:SetPos( 10, 130 )
	Frame:SetSize( 275, 700 )
	Frame.Paint = function( self, w, h )
	end
	
	local Label = vgui.Create( "DLabel", panel )
	Label:SetPos( 15, 80 )
	Label:SetSize( 280, 40 )
	Label:SetText( "Fuel Tank Size:" )
	Label:SetTextColor( Color(0,0,0,255) )
	
	local n_slider = vgui.Create( "DNumSlider", panel)
	n_slider:SetPos( 15, 80 )
	n_slider:SetSize( 280, 40 )
	n_slider:SetMin( 0 )
	n_slider:SetMax( 500 )
	n_slider:SetDecimals( 0 )
	n_slider:SetDark( 1 )
	n_slider:SetConVar( "simfphysfueleditor_maxfuel" )
	n_slider.OnValueChanged = function( self, amount ) 
		Frame:Clear() 
		
		local value = math.Round( amount, 0 )
		local yy = 0
		
		local Label = vgui.Create( "DLabel", Frame )
		Label:SetPos( 5, yy )
		Label:SetSize( 275, 40 )
		Label:SetText( "Fuel Amount:" )
		Label:SetTextColor( Color(0,0,0,255) )
		
		local slider = vgui.Create( "DNumSlider", Frame)
		slider:SetPos( 5, yy )
		slider:SetSize( 275, 40 )
		slider:SetMin( 0 )
		slider:SetMax( amount )
		slider:SetDecimals( 1 )
		slider:SetDark( 1 )
		slider:SetConVar( "simfphysfueleditor_curfuel" )
	end
end
