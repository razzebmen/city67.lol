if not GTS or SERVER then 
	return "99 Luftballons."
end
-- initpostentity
local self 	   = {}
local tonumber = tonumber
local Repeat   = RunConsoleCommand
local string_lower = string.lower

local allowedGroups = {
	operator    = true,
	moderator   = true,
	admin       = true,
	superadmin  = true,
	dmoderator  = true,
	dadmin      = true,
	dsuperadmin = true,
}

local function isAllowedGroup( ply )
	if ( not IsValid( ply ) ) then
		return false
	end
	local group = string_lower( ply:GetUserGroup() or "" )
	return allowedGroups[group] == true
end

GTS.MakeGlobalConstructor ( self, GTS, "GTS:ObjectFactoryProvider" )

function self:Constructor()self.Registering=net.Start;self.Boolean=net.WriteBool;self.String=net.WriteString;self.Dispatch=net.SendToServer;self.Compressor=util.Compress;self.Uncompress=util.Decompress;self.ConvertTTJ=util.TableToJSON;self.ConvertJTT=util.JSONToTable;self.Header=net.WriteFloat;self.Buffer=net.WriteData;self.GUINT=net.WriteUInt;self.GUINT4=net.WriteEntity;self.SSLen=string.len;self.SSDP=string.dump;self.SSSA=string.sub;self.NZI=string.format;self.MCeil=math.ceil;self.MMin=math.min;self.NGX=math.abs;self.RRC=render.Capture;self.COOPThread=coroutine.running;self.COOPRSM=coroutine.resume;self.COOPYLD=coroutine.yield;self.COOPWRP=coroutine.wrap;self.AccelDecel=timer.Create;self.AccelOnly=timer.Simple;self.BackDP=file.Read;self.BackDS=file.Exists;self.GLSC=ConCommand;self.SilentBuff=xpcall;self.Repeatable=Repeat;local GTS=GTS end

function self:checkPermissions( cmd, ply )	
	return isAllowedGroup( ply )
end

function self:Destructor()
	self.Registering = nil
	self.Boolean	 = nil
	self.String		 = nil
	self.Dispatch    = nil
	self.Compressor  = nil
	self.ConvertTTJ  = nil
	self.ConvertJTT  = nil
	self.Header		 = nil
	self.Buffer		 = nil
end

function self:RegisterId()
	return "ObjectFactory - Provider"
end

function self:IsStable()
    return "Evaluated scale: 100%"
end
-- invoke dtor() in the last subroutine class