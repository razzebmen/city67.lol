--moved all hooks here

hook.Add( "simfphysOnSpawn", "RandysOnSpawn", function(self)
	if ( self.EngHeat ) then return end --hacky solution to make the script compatible for my IV pack until I fix it properly
	
	RANDYS.EngStartInit(self)
	RANDYS.EngStart(self)
	RANDYS.EngStop(self)
	RANDYS.BeaterInit(self)
	
	RANDYS.AttachLicensePlates(self)
	RANDYS.ChangeLicensePlates(self)
	
	RANDYS.SetRandomColor(self)
	RANDYS.SetRandomBodygroup(self)
	RANDYS.SetRandomSkin(self)
	RANDYS.SetRandomFuel(self)
	RANDYS.SetPreset(self)
	
	RANDYS.AlarmInit(self)
	
	RANDYS.TrailerLegs(self)
	
	self.BrakingAllowed = true
	
	self.BeaterCounter = 0
	
	self.Reversing = false
	self.RevSound = CreateSound( self, "vehicles/reverse1.wav" )
	self.RevSound2 = CreateSound( self, "vehicles/reverse2.wav" )
end )

hook.Add( "simfphysOnTick", "RandysOnTick", function(self)
		if ( self.EngHeat ) then return end --hacky solution to make the script compatible for my IV pack until I fix it properly
		
		RANDYS.Beater(self)
		RANDYS.Alarm(self)
		RANDYS.ReverseBeep(self)
		RANDYS.ReverseGear(self)
		RANDYS.Bullhorn(self)
		RANDYS.PlayEMSRadio(self)
		if self.HasAirbrakes then
			RANDYS.AirBraking(self)
		else
			RANDYS.Braking(self)
		end
end )

hook.Add( "simfphysOnDelete", "RandysOnDelete", function(self)
	timer.Remove( "IGNITION_" .. self:EntIndex() )
	timer.Remove( "SIMF_BEATER_" .. self:EntIndex() )
	timer.Remove( "SIMF_BEATERS_" .. self:EntIndex() )
	timer.Remove( "SIMF_ALARM_" .. self:EntIndex() )
	timer.Remove( "SIMF_AIRVALVE_" .. self:EntIndex() )
	if self.Ignition then
		self.Ignition:Stop()
	end
	if self.IgnitionTail then
		self.IgnitionTail:Stop()
	end
	if self.ALRM then
		self.ALRM:Stop()
	end
	if self.BRK then
		self.BRK:Stop()
	end
	if self.REVBP then
		self.REVBP:Stop()
	end
	if self.Bullhorn then
		self.Bullhorn:Stop()
	end
	if self.RevSound then
		self.RevSound:Stop()
	end
	if self.RevSound2 then
		self.RevSound2:Stop()
	end
end )