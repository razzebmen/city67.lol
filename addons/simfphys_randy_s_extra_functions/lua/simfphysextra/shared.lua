--moved all functions here

local function ActivateHorn(self, bool)
	if not self.horn then
		self.horn = CreateSound(self, self.snd_horn or "simulated_vehicles/horn_1.wav")
		self.horn:PlayEx(0,100)
	end	
	self.HornKeyIsDown = bool
	self:ControlHorn()
end

function RANDYS.ReverseBeep(self)
	if not self.snd_reverse_beep then return end
	
	self.REVBP = CreateSound( self, self.snd_reverse_beep )
	
	if ( self:GetGear() == 1) and self:EngineActive() then
		self.REVBP:Play()
	else
		if self.REVBP then
			self.REVBP:Stop()
		end
	end
end

function RANDYS.EngStartInit(self)
	if self.SimpleIgnition then return end
	
	if self.snd_starter and self.snd_starter_good then --if these sounds are specified, we gaming
		self.Ignition = CreateSound(self, self.snd_starter )
		self.IgnitionTail = CreateSound(self, self.snd_starter_good )
		if self.snd_starter_bad then
			self.IgnitionFail = CreateSound(self, self.snd_starter_bad )
		else
			self.IgnitionFail = CreateSound(self, self.snd_starter_good )
		end
	else --if those sounds are not specified, fall back to defaults
		if self.Mass > 3500 then --if the vehicle is heavy, its likely gonna be a truck. So use the truck ignition
			self.Ignition = CreateSound(self, "vehicles/starter_truck.wav" )
			self.IgnitionTail = CreateSound(self, "vehicles/starter_truck_tail.wav" )
			self.IgnitionFail = CreateSound(self, "vehicles/starter_truck_tail.wav" )
		else --otherwise just use the generic one
			self.Ignition = CreateSound(self, "vehicles/starter_generic.wav" )
			self.IgnitionTail = CreateSound(self, "vehicles/starter_generic_tail.wav" )
			self.IgnitionFail = CreateSound(self, "vehicles/starter_generic_tail.wav" )
		end
	end
	self.Ignition:SetSoundLevel( 75 )
	self.IgnitionTail:SetSoundLevel( 75 )
	self.IgnitionFail:SetSoundLevel( 75 )
	
	self.IgnitionCheck = false
end

local function IgnitionSwitch(self) --repurposed ignition script, plays the ignition sound then turns on the vehicle
	local MinIgnition = self.MinIgnitionTime or 0.3
	local MaxIgnition = self.MaxIgnitionTime or 0.7
	
	self.Ignition:Play()
	self.IgnitionTail:Stop()
	if self.IgnitionCheck then return end
	self.IgnitionCheck = true
	timer.Create( "IGNITION_" .. self:EntIndex(), math.Rand(MinIgnition,MaxIgnition), 1, function()
		if self.Ignition:IsPlaying() then
			self.Ignition:Stop()
		end
		if !self.IgnitionTail:IsPlaying() then
			self.IgnitionTail:Play()
		end
		self.IgnitionCheck = false
		
		timer.Remove( "IGNITION_" .. self:EntIndex() )
		
		if !self:CanStart() then return end
		
		self:SetActive( true )
		self.EngineRPM = self:GetEngineData().IdleRPM
		self.EngineIsOn = 1
	end)
end

local function IgnitionBeater(self) --failed iginiton for low health cars
	self.Ignition:Play()
	self.IgnitionFail:Stop()
	if self.IgnitionCheck then return end
	
	local MinIgnition = self.MinIgnitionTime or 0.3
	local MaxIgnition = self.MaxIgnitionTime or 0.7
	
	MaxIgnition = MaxIgnition + 1
	
	local CurHealthRatio = self.GetMaxHealth(self)/ self:GetCurHealth()
	local Beater = math.random(0,1)
	
	self.IgnitionCheck = true
	timer.Create( "IGNITION_" .. self:EntIndex(), math.Rand(MinIgnition,MaxIgnition), 1, function()
		if self.Ignition:IsPlaying() then
			self.Ignition:Stop()
		end
		if !self.IgnitionFail:IsPlaying() then
			self.IgnitionFail:Play()
		end
		
		self.IgnitionCheck = false
		
		timer.Remove( "IGNITION_" .. self:EntIndex() )
		
		local ply = self:GetDriver()
		if IsValid(ply) then
			if ply:GetInfoNum( "cl_simfphys_autostart", 1 ) <= 0 then return end
		end
		
		timer.Simple(0.5, function()
			if IsValid(self) and IsValid(self:GetDriver()) then
				if Beater == 1 and !(self.BeaterCounter > CurHealthRatio ) then 
					IgnitionBeater(self)
					self.BeaterCounter = self.BeaterCounter + 1
				else
					if self:GetFuel() < 0.1 then return end
					
					if not self.IsInWater then
						IgnitionSwitch(self)
						else
							if self:GetDoNotStall() then
								IgnitionSwitch(self)
							end
						end
					self.BeaterCounter = 0
				end
			end
		end)
	end)
end

function RANDYS.EngStart(self) --this bit calls for the engine turning on
	local IgnSnd = self.snd_simpleIgnition or "common/null.wav"
	local AdvIgn = false
	
	if GetConVar( "sv_simfphys_advanced_ignition" ):GetBool() and not self.SimpleIgnition then
		AdvIgn = true
	end
	
	if not self:CanStart() then return end
	
	--if GetConVar( "cl_simfphys_autostart" ):GetInt() == 1 then
		self.StartEngine = function(self, bIgnoreSettings)
			if not self:EngineActive() then
				if not bIgnoreSettings then
					self.CurrselfGear = 2
				end
					
				if self:GetCurHealth() < ( self.GetMaxHealth(self) / 1.5 ) and AdvIgn then
					local Beater = math.random(0,1)
					if Beater == 1 then 
						IgnitionBeater(self)
					end
				end
				
				if self:GetFuel() < 0.1 then 
					if AdvIgn then
						IgnitionBeater(self)
					end
				return end
				
				if not self.IsInWater then
					if AdvIgn then
						IgnitionSwitch(self)
					else
						self.EngineRPM = self:GetEngineData().IdleRPM
						self.EngineIsOn = 1
						sound.Play( IgnSnd, self:GetPos())
					end
				else
					if self:GetDoNotStall() then
						if AdvIgn then
							IgnitionSwitch(self)
						else
							self.EngineRPM = self:GetEngineData().IdleRPM
							self.EngineIsOn = 1
							sound.Play( IgnSnd, self:GetPos())
						end
					end
				end
			end
		end
	--[[else
		self.StartEngine = function(self, bIgnoreSettings)
			if not self:EngineActive() then
				if not bIgnoreSettings then
					self.CurrselfGear = 2
				end
		
				local ply = self:GetDriver()
				if !ply:IsPlayer() then return end --checks if the driver is an actual player, not an AI
				
				--tried to make a "Hold to start" thing but couldn't figure it out. maybe later
			end
		end
	end]]
end

function RANDYS.EngStartSimple(self) --this bit calls for the engine turning on
	if GetConVar( "sv_simfphys_advanced_ignition" ):GetInt() == 1 then return end
	
	if not self:CanStart() then return end
	
	if not self:EngineActive() then
	
		if hook.Run( "simfphysOnEngine", self, true, bIgnoreSettings ) then return end
		
		if not bIgnoreSettings then
			self.CurrentGear = 2
		end
			
		if not self.IsInWater then
			self.EngineRPM = self:GetEngineData().IdleRPM
			self.EngineIsOn = 1
			sound.Play( "common/null.wav", self:GetPos())
		else
			if self:GetDoNotStall() then
				self.EngineRPM = self:GetEngineData().IdleRPM
				self.EngineIsOn = 1
			end
		end
	end
end

function RANDYS.EngStop(self) --engine shutdown
	
    if self.snd_stop then --if there is a stop sound specified, run the script. if there isnt, theres no reason to
		self.StopEngine = function(self)
			if self:EngineActive() then
				self:EmitSound( self.snd_stop )
		
				self.EngineRPM = 0
				self.EngineIsOn = 0
				
				self:SetFlyWheelRPM( 0 )
				self:SetIsCruiseModeOn( false )
			end
		end
	end
end

function RANDYS.BeaterInit(self)
	self.BeaterCountdown = 0
	self.BeaterCounter = 0
end

function RANDYS.Beater(self)
	if !self.BeaterCountdown then return end
	
	--[[if self:GetCurHealth() > ( self.GetMaxHealth(self) / 2 ) + 100 then --makes beater cars un-repairable, like in IV
		self:SetCurHealth( ( self.GetMaxHealth(self) / 2 ) + 100)
	end]]--
	
	if self:EngineActive() and (self:GetCurHealth() < (self.GetMaxHealth(self) / 1.5)) then
		self.BeaterCountdown = 0
		if not timer.Exists( "SIMF_BEATER_" .. self:EntIndex() ) then
			timer.Create( "SIMF_BEATER_" .. self:EntIndex(), math.random(1,10), 1, function()
				local Beater = math.random(0,1)
				
				if self:EngineActive() then
					if Beater == 1 and self.ForwardSpeed > 100 then
						net.Start( "simfphys_backfire" )
							net.WriteEntity( self ) --make the car randomly backfire while driving
						net.Broadcast()
					else
						sound.Play( "vehicles/BREAKDOWN_"..math.random(1,5)..".wav", self:GetPos()) --plays random breakdown noises
					end
				end
				timer.Remove( "SIMF_BEATER_" .. self:EntIndex() )
			end)
		end
	elseif !self:EngineActive() and (self:GetCurHealth() < (self.GetMaxHealth(self) / 1.5)) then
		if not (timer.Exists( "SIMF_BEATERS_" .. self:EntIndex() ) and self.BeaterCountdown < 3) then
			timer.Create( "SIMF_BEATERS_" .. self:EntIndex(), 0.2, 1, function()
				sound.Play( "vehicles/BREAKDOWN_"..math.random(1,5)..".wav", self:GetPos()) --breakdown noises when the engine stops
				self.BeaterCountdown = self.BeaterCountdown + 1
			end)
		end
	end
end

function RANDYS.AlarmInit(self)
	self.ALRM = CreateSound(self, "vehicles/car_alarm"..math.random(1,4)..".wav" ) --picks an alarm sound
	self.ALRM:SetSoundLevel( 90 )
	
	self.CurHealthGot = false
	self.ALRMon = false
	self.ALRMArmed = false
	self.CurHealthLocked = self:GetCurHealth()
	
	self.ALRMRnd = math.random(0,2)
	
	if self.NoAlarm then self.ALRMRnd = 0 end
	if self.ForceAlarm then self.ALRMRnd = math.random(1,2) end
end

local function ActivateHorn(self, bool)
	if not self.horn then
		self.horn = CreateSound(self, self.snd_horn or "simulated_vehicles/horn_1.wav")
		self.horn:PlayEx(0,100)
	end	
	self.HornKeyIsDown = bool
	self:ControlHorn()
end

local function ChirpAlarmLocked(self)
	if self.ALRMRnd == 2 then
		self.ALRM:Play()
	else
		ActivateHorn(self, true)
	end
	self:SetLightsEnabled(true)
	timer.Simple(0.1, function()
		if IsValid(self) then
			self:SetLightsEnabled(false)
			if self.ALRMRnd == 2 then
				self.ALRM:Stop()
			else
				ActivateHorn(self, false)
			end
		end
	end)
end

local function ChirpAlarmUnLocked(self)
	if self.ALRMRnd == 2 then
		self.ALRM:Play()
	else
		ActivateHorn(self, true)
	end
	timer.Simple(0.12, function()
		if IsValid(self) then
			self:SetLightsEnabled(true)
			if self.ALRMRnd == 2 then
				self.ALRM:Stop()
			else
				ActivateHorn(self, false)
			end
		end
	end)
	timer.Simple(0.24, function()
		if IsValid(self) then
			if self.ALRMRnd == 2 then
				self.ALRM:Play()
			else
				ActivateHorn(self, true)
			end
		end
	end)
	timer.Simple(0.36, function()
		if IsValid(self) then
			self:SetLightsEnabled(false)
			if self.ALRMRnd == 2 then
				self.ALRM:Stop()
			else
				ActivateHorn(self, false)
			end
		end
	end)
end

local function TurnOffAlarm(self)
	if !self.ALRMArmed then return end
	
	if self.ALRMon then
		if self.ALRM then
			self.ALRM:Stop()
		end
	end
	if timer.Exists( "SIMF_ALARM_" .. self:EntIndex() ) then
		timer.Remove( "SIMF_ALARM_" .. self:EntIndex() )
	end

	self:SetLightsEnabled(false)
	self.ALRMon = false
	self.ALRMed = false
	self.CurHealthGot = false
end

function RANDYS.Alarm(self, ALRMVal) -- alarm function
	if self:EngineActive() then return end
	if self.ALRMRnd == 0 then return end
	if (GetConVar( "sv_simfphys_alarms" ):GetInt() == 0) then return end
	
	if self:GetIsVehicleLocked() then
		if !self.CurHealthGot then self.CurHealthLocked = self:GetCurHealth() end
		self.CurHealthGot = true
		
		if !self.ALRMArmed then ChirpAlarmLocked(self) end
		self.ALRMArmed = true
		
		if self:GetCurHealth() < self.CurHealthLocked then
			self.ALRMon = true
			if self.ALRMRnd == 2 then
				self.ALRM:Play()
			end
			
			if self.ALRMed then return end
			
			if !timer.Exists( "SIMF_ALARM_" .. self:EntIndex() ) then
				timer.Create( "SIMF_ALARM_" .. self:EntIndex(), 1, 1, function()
					self:SetLightsEnabled(true)
					if self.ALRMRnd == 1 then
						ActivateHorn(self, true)
					end		
					
					timer.Simple(0.5, function()
						if IsValid(self) then
							self:SetLightsEnabled(false)
							if self.ALRMRnd == 1 then
								ActivateHorn(self, false)
							end
						end
					end)
				end)
			end
			
			if !timer.Exists( "SIMF_ALARM_KILL_" .. self:EntIndex() ) and self.ALRMon then
				timer.Create( "SIMF_ALARM_KILL_" .. self:EntIndex(), math.random(15,25), 1, function()
					if IsValid(self) then
						TurnOffAlarm(self)
						self.ALRMed = true
					end
				end)
			end
		end
	end
	
	if !self:GetIsVehicleLocked() then
		if self.ALRMArmed then ChirpAlarmUnLocked(self) end
		timer.Remove( "SIMF_ALARM_KILL_" .. self:EntIndex() )
		TurnOffAlarm(self)
		self.ALRMed = false
		self.ALRMArmed = false
	end
end

local function tablelength(T)
   local count = 0
   for _ in pairs(T) do count = count + 1 end
   return count
end

function RANDYS.AttachLicensePlates(self)
	if not self.LPGroup then return end --if theres no license plate group specified, do not run this script
	if (GetConVar( "sv_simfphys_license_plates" ):GetInt() == 0) then return end
	
	local TypeCount
	local TypeRand
	
	if self.LPType then --if the TYPE is specified also, pick a random item and append it to the group
		TypeCount = tablelength(self.LPType)
		TypeRand = self.LPType[math.random(1,TypeCount)]
	else
		TypeRand = "" --if it isnt specified, simply do not add anything
	end
	
	local Group = self.LPGroup
	
	self.frontplt = ents.Create( "prop_dynamic" )
	self.frontplt:SetModel( Group[1]..TypeRand..".mdl" )
	self.frontplt.DoNotDuplicate = true
	
	self.rearplt = ents.Create( "prop_dynamic" )
	if not file.Exists( Group[2]..TypeRand..".mdl", "GAME" ) then --check if there is a separate rear license plate model, if not, use the front plate
		self.rearplt:SetModel( Group[1]..TypeRand..".mdl" )
	else
		self.rearplt:SetModel( Group[2]..TypeRand..".mdl" )
	end
	self.rearplt.DoNotDuplicate = true
	
	if self.LPMountFront then --make sure there is a license plate mounting point specified
		self.frontplt:SetAngles( self:GetAngles() )
		if self.LPRotateFront then --if the vehicle needs the plate rotated, we add that to the normal rotation
			self.frontplt:SetAngles( self:GetAngles() + self.LPRotateFront )
		end
		self.frontplt:SetPos( self:LocalToWorld( self.LPMountFront ) )
		self.frontplt:SetParent( self )
		self.frontplt:Spawn()
		
		self:CallOnRemove("RemoveFrontLP",function(self)
			self.frontplt:Remove()
		end)
	end
	
	if self.LPMountRear then --make sure there is a license plate mounting point specified
		self.rearplt:SetAngles( self:GetAngles() )
		local angles = self.rearplt:GetAngles()
		if self.LPRotateRear then --if the vehicle needs the plate rotated, we add that to the normal rotation
			angles = angles + self.LPRotateRear
		end
		angles:RotateAroundAxis( self.rearplt:GetUp(), 180 )
		self.rearplt:SetAngles(angles)
		self.rearplt:SetPos( self:LocalToWorld( self.LPMountRear ) )
		self.rearplt:SetParent( self )
		self.rearplt:Spawn()
		
		self:CallOnRemove("RemoveRearLP",function(self)
			self.rearplt:Remove()
		end)
	end
end

function RANDYS.ChangeLicensePlates(self) --randomize the plate
	if self.frontplt then
		self.frontplt:SetBodygroup( 1, math.random(0,self.frontplt:GetBodygroupCount( 1 )) )
		self.frontplt:SetBodygroup( 2, math.random(0,self.frontplt:GetBodygroupCount( 2 )) )
		self.frontplt:SetBodygroup( 3, math.random(0,self.frontplt:GetBodygroupCount( 3 )) )
		self.frontplt:SetBodygroup( 4, math.random(0,self.frontplt:GetBodygroupCount( 4 )) )
		self.frontplt:SetBodygroup( 5, math.random(0,self.frontplt:GetBodygroupCount( 5 )) )
		self.frontplt:SetBodygroup( 6, math.random(0,self.frontplt:GetBodygroupCount( 6 )) )
		self.frontplt:SetBodygroup( 7, math.random(0,self.frontplt:GetBodygroupCount( 7 )) )
		self.frontplt:SetBodygroup( 8, math.random(0,self.frontplt:GetBodygroupCount( 8 )) )
	end
	
	if self.rearplt then
		self.rearplt:SetBodygroup( 1, self.frontplt:GetBodygroup( 1 )) --we take the bodygroup number from the front plate, since they need to match
		self.rearplt:SetBodygroup( 2, self.frontplt:GetBodygroup( 2 ))
		self.rearplt:SetBodygroup( 3, self.frontplt:GetBodygroup( 3 ))
		self.rearplt:SetBodygroup( 4, self.frontplt:GetBodygroup( 4 ))
		self.rearplt:SetBodygroup( 5, self.frontplt:GetBodygroup( 5 ))
		self.rearplt:SetBodygroup( 6, self.frontplt:GetBodygroup( 6 ))
		self.rearplt:SetBodygroup( 7, self.frontplt:GetBodygroup( 7 ))
		self.rearplt:SetBodygroup( 8, self.frontplt:GetBodygroup( 8 ))
	end
end

local function GrabColorFromPresetTable( TableName, Col1, Col2 )
	return TableName[Col1],TableName[Col2] 
end

function RANDYS.SetRandomColor(self)
	if not self.AllowRandomColors then return end --stop this script if the vehicle doesn't want random colors
	
	local ply = self.EntityOwner
	if IsValid(ply) then
		if ply:GetInfoNum( "cl_simfphys_randomcolors", 1 ) <= 0 then return end
	end
	
	SatMin = self.RandomColorMin or 0 --default to 0 if this isnt specified
	SatMax = self.RandomColorMax or 255 --default to 255 if this isnt specified
	
	local RanCol = Color(math.random(SatMin,SatMax),math.random(SatMin,SatMax),math.random(SatMin,SatMax)) --generate a random color with the specified values
	
	if istable( self.RandomColorPresets ) then --if we have color presets, use those instead
		local MaxLength = tablelength(self.RandomColorPresets)

		self:SetColor(self.RandomColorPresets[math.random(1, MaxLength)])
	else
		self:SetColor(RanCol) --if we dont, use the random color that we generated
	end
	
	if ( ProxyColor ) and self.UseProxyColors then --if we have proxy colors and we want to use them, use them
		if istable( self.ProxyColorPresets ) or istable( self.ColorPresetTable ) then --for some reason randomly generated proxy colors did not work. So we only use the presets
			local MaxLength = tablelength(self.ProxyColorPresets)
			
			self:SetProxyColor( self.ProxyColorPresets[math.random(1,MaxLength)] )
			self:SetColor(Color(255,255,255)) --remove the base color since we now have proxy colors
		end
	end
end

function RANDYS.SetRandomBodygroup(self)
	local ply = self.EntityOwner
	if IsValid(ply) then
		if ply:GetInfoNum( "cl_simfphys_randombodygroups", 1 ) <= 0 then return end
	end

	if istable( self.RandomBodygroups ) then --if we have the random bodygroups table specified thats great
		for _, data in pairs( self.RandomBodygroups ) do
			local MinCount = data.min or 0
			local MaxCount = data.max or self.GetBodygroupCount( self, data.number ) --lazy author does not specify max count so we count it for them.
			
			self:SetBodygroup(data.number, math.random(MinCount,MaxCount)) --apply the stuff thats in the table.
		end
	end
end

function RANDYS.SetRandomSkin(self)
	if not self.AllowRandomSkins then return end --if we dont allow random skins, do not do anything
	
	if istable( self.RandomSkinRange ) then --if theres a range specified, use a random skin within that range
		self:SetSkin(math.random(self.RandomSkinRange[1],self.RandomSkinRange[2]))
	else --if theres no range specified, use a random skin
		self:SetSkin(math.random(0,16))
	end
end

function RANDYS.SetPreset(self)
	local ply = self.EntityOwner
	if IsValid(ply) then
		if ply:GetInfoNum( "cl_simfphys_vehiclepresets", 1 ) <= 0 then return end
	end

	if istable( self.Presets ) then --if we have presets specified we will use them
		local data = self.Presets[math.random(1,table.Count(self.Presets))]
		
		if istable( data.bodygroups ) then
			self:SetBodyGroups(data.bodygroups[math.random(1,table.Count(data.bodygroups))])
		end
		if istable( data.colors ) then
			self:SetColor(data.colors[math.random(1,table.Count(data.colors))])
		end
		if istable( data.skins ) then
			self:SetSkin(data.skins[math.random(1,table.Count(data.skins))])
		end
		if istable( data.proxyColors ) and ( ProxyColor ) then
			self:SetProxyColor( data.proxyColors[math.random(1,table.Count(data.proxyColors))] )
			self:SetColor( Color(255,255,255) )  --remove the base color since we now have proxy colors
		end
	end
end

function RANDYS.SetRandomFuel(self)
	local ply = self.EntityOwner
	if not IsValid(ply) then 
		-- Если нет владельца (автоматический спавн), устанавливаем полный бак
		local maxFuel = self:GetMaxFuel()
		self:SetFuel(maxFuel)
		return 
	end
	
	if ply:GetInfoNum( "cl_simfphys_randomfuel", 1 ) <= 0 then return end

	local maxFuel = self:GetMaxFuel()
	local minFuel = ply:GetInfoNum( "cl_simfphys_randomfuel_min", 10 )
	
	minFuel = minFuel * ( maxFuel / 100)
	--print(minFuel..","..maxFuel)
	
	self:SetFuel( math.random(minFuel,maxFuel) )
end

function RANDYS.Braking(self) --brake disc sound
	if not (GetConVar( "sv_simfphys_brakenoises" ):GetInt() == 1) then return end
	if self.IsTrailer or self.NoBrakes then return end --if the vehicle is a trailer, do not play braking sounds

	if self.BRK then
		self.BRK:ChangeVolume( math.Remap( self.ForwardSpeed, 50, 600, 0, 0.25 ))
	end
	
	if ( self:GetIsBraking() and self.ForwardSpeed > 50 and self.ForwardSpeed < 600 and self.BrakingAllowed) then --check if the forward speed is correct and if the car is braking
		self.BrakingAllowed = false
		self.BRK = CreateSound( self, "vehicles/brake_disc.wav" )
		self.BRK:PlayEx(0,100)
	else
		if self.BRK then
			if ( self.BRK:IsPlaying() and !self:GetIsBraking() ) then
				self.BRK:Stop()
				self.BrakingAllowed = true
			end
		end
	end
end

function RANDYS.AirBraking(self)
	if not (GetConVar( "sv_simfphys_brakenoises" ):GetInt() == 1) then return end
	if self.IsTrailer or self.NoBrakes  then return end --if the vehicle is a trailer, do not play braking sounds

	self.BRKSQK = CreateSound( self, "vehicles/airbrake"..math.random(1,6)..".wav" )
	
	if self:GetRPM() == self.IdleRPM then
		if not timer.Exists( "SIMF_AIRVALVE_" .. self:EntIndex() ) then
			timer.Create( "SIMF_AIRVALVE_" .. self:EntIndex(), math.random(10,30), 1, function()
				sound.Play( "vehicles/default_valve.wav", self:GetPos())
				timer.Remove( "SIMF_AIRVALVE_" .. self:EntIndex() )
			end)
		end
	else
		if timer.Exists( "SIMF_AIRVALVE_" .. self:EntIndex() ) then
			timer.Remove( "SIMF_AIRVALVE_" .. self:EntIndex() )
		end
	end
	
	if self.BRK then
		self.BRK:ChangeVolume( math.Remap( self.ForwardSpeed, 50, 600, 0, 0.15 ))
	end
	
	if ( self:GetIsBraking() and self.ForwardSpeed > 50 and self.ForwardSpeed < 600 and self.BrakingAllowed) then
		self.BrakingAllowed = false
		self.BRK = CreateSound( self, "vehicles/rig_brake_disc.wav" )
		self.BRK:PlayEx(0,100)
	else
		if self.BRK then
			if ( self.BRK:IsPlaying() and !self:GetIsBraking() ) then
				self.BRK:Stop()
				if !self.BRKSQK:IsPlaying() then
					self.BRKSQK:Play()
				end
				self.BrakingAllowed = true
			end
		end
	end
	
	--this works but I wrote it a while ago so I don't remember how
	-- c:
end

function RANDYS.Bullhorn(self) --bullhorn script for emergency vehicles
	if not (GetConVar( "sv_simfphys_bullhorn" ):GetInt() == 1) then return end
	if not self.HasBullhorn then return end
	local ply = self:GetDriver()
	
	if !IsValid(self) then return end
	if !IsValid(self:GetDriver()) then return end --if there is no driver, end the script, otherwise it would error
	if !ply:IsPlayer() then return end --checks if the driver is an actual player, not an AI
	
	if ply:KeyDown( 2048 ) and IsValid(self:GetDriver()) then
		self.Bullhorn = CreateSound(self, self.snd_bullhorn or "vehicles/bullhorn.wav" ) --picks an alarm sound
		self.Bullhorn:SetSoundLevel( 90 )
		self.Bullhorn:Play()
	else
		if self.Bullhorn then
			self.Bullhorn:Stop()
		end
	end
end

local function ToggleLegs(self, Connected, alt) --this whole script is from NotAKid. Thank you NAK, very cool
	--//around 12 mph~
	if self:GetVelocity():Length() > 200 then return end

	if IsValid(self.TrController) then
		if Connected or (Connected == nil && self.TrController.dirlast == 1) then
			self.NAKTrProp:GetPhysicsObject():SetMass( 100 )
			self:SetPoseParameter( self.TrailerLegsPoseParameter or "trailer_legs", 100 )
			self.TrController.direction = -1
			self.TrController.dirlast = -1
		else
			self.NAKTrProp:GetPhysicsObject():SetMass( 1000 )
			self:SetPoseParameter( self.TrailerLegsPoseParameter or "trailer_legs", 0 )
			self.TrController.direction = 1
			self.TrController.dirlast = 1
		end
	end
end

function RANDYS.TrailerLegs(self) --this whole script is from NotAKid. Thank you NAK, very cool
	if GetConVar( "sv_simfphys_trailer_legs" ):GetInt() == 0 then return end
	
	if !self.TrailerLegsPosition then return end --only run this script if theres a position for the legs specified.
	
	local LPos = self.TrailerLegsPosition
	local height = self.TrailerLegsHeight or 50
	
	--//possible crash?
	if height == nil then return end
	
	--this is only needed if theres a singular trailer leg
	local mdl
	if self.SingleTrailerLeg then
		mdl = "models/hunter/blocks/cube025x025x025.mdl"
	else
		mdl = "models/hunter/blocks/cube025x150x025.mdl"
	end

	self.NAKTrProp = ents.Create("prop_physics")
	self.NAKTrProp:SetModel( mdl )
	self.NAKTrProp:SetPos( self:LocalToWorld( LPos ) )
	self.NAKTrProp:SetAngles( self:GetAngles() )
	self.NAKTrProp:Spawn()
	self.NAKTrProp:Activate()
	self.NAKTrProp:GetPhysicsObject():SetMass( 1000 )
	self.NAKTrProp:GetPhysicsObject():SetDragCoefficient( -9000 )
	self.NAKTrProp.DoNotDuplicate = true
	
	local propOffset = LPos * Vector(0,-1,0)
	local LPos2 = LPos * Vector(1,0,1) + Vector(0,0,height)
	
	local hydraulic, rope, controller = constraint.Hydraulic(nil, self, self.NAKTrProp, 0, 0, LPos2, propOffset, height, 0, 0, KEY_NONE, 1, 200, nil, true)
	--rope to lock the prop from going down too far
	constraint.Rope( self, self.NAKTrProp, 0, 0, LPos2, propOffset, height, 0, 0, 0, "cable/rope", false )
	--rope to lock the prop from going up too far
	constraint.Rope( self, self.NAKTrProp, 0, 0, LPos2 - Vector(0,0,height), propOffset, height, 0, 0, 0, "cable/cable2", false )
	--nocollide
	constraint.NoCollide( self, self.NAKTrProp, 0, 0	)
	--hide the prop (seems to not work with Improved Object Render)
	self.NAKTrProp:DrawShadow( false )
	self.NAKTrProp:SetNoDraw( true )

	self.TrHydraulic = hydraulic
	self.TrController = controller
	self.TrController.direction = 1
	self.TrController.dirlast = 1

	self.TrailerStandREN = function(self, Connected)
		ToggleLegs(self, Connected)
	end

	self.Use = function(self, ply)
		if ply:GetActiveWeapon():GetClass() == "weapon_crowbar" then
			ToggleLegs(self)
		end
	end
	
	self:CallOnRemove("RemoveTrailerLegs",function(self)
			self.NAKTrProp:Remove()
		end)
end

function RANDYS.ReverseGear(self)
	if not self.RevSound then return end
	
	local VelocityCheck = false --check for if the velocity has gone down low enough
	
	if ( self:GetGear() == 1 ) and ( self:GetVelocity():Length() > 1 ) then --check for reverse gear first
		self.Reversing = true --yes, then we're reversing
	end
	
	if self.Reversing and IsValid(self:GetDriver()) then
		local pitch = 50 + self:GetVelocity():Length() / 10
		local vol = self:GetVelocity():Length() / 1000
		
		if self:GetThrottle() > 0 then
			self.RevSound2:Stop()
			self.RevSound:PlayEx(vol, pitch)
		else
			self.RevSound:Stop()
			self.RevSound2:PlayEx(vol, pitch)
		end
		
		if ( self:GetVelocity():Length() < 50 ) then
			VelocityCheck = true
		end
		if ( self:GetGear() == 3 ) and ( self:GetThrottle() > 0 ) then
			self.Reversing = false
		end
	else
		if self.RevSound then
			self.RevSound:Stop()
		end
		if self.RevSound2 then
			self.RevSound2:Stop()
		end
	end
	
	if VelocityCheck and self:GetGear() == 3 then
		self.Reversing = false
	end
end

function RANDYS.PlayEMSRadio(self)
	if !IsValid(self) then return end
	if !self.PolRadioSound then return end
	if timer.Exists( "SIMF_EMSRADIO_" .. self:EntIndex() ) then return end
	
	local filter = RecipientFilter()
	
	if IsValid(self:GetDriver()) then
		filter:AddPlayer( self:GetDriver() )
	end
	if self.PassengerSeats then
		for i = 1, table.Count( self.PassengerSeats ) do
			local Passenger = self.pSeat[i]:GetDriver()
			if IsValid(Passenger) then
				filter:AddPlayer( Passenger )
			end
		end
	end
	
	self.EMSRadio = CreateSound(self, self.PolRadioSound, filter )
	self.EMSRadio:PlayEx( 2, 100 )
	
	local MinTime = self.PolRadioMinTime or 10
	local MaxTime = self.PolRadioMaxTime or 35
	
	if !timer.Exists( "SIMF_EMSRADIO_" .. self:EntIndex() ) then
		timer.Create( "SIMF_EMSRADIO_" .. self:EntIndex(), math.random(MinTime, MaxTime), 1, function()
			RANDYS.PlayEMSRadio(self)
		end)
	end
end