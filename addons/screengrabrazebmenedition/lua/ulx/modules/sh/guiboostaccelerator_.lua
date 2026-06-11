-- Computer written by Cardinal Global Exporter.exe
-- Timestamp: 05/30/20
local CATEGORY = "ScreenGrab"
local string_lower = string.lower

local allowedGroups = {
	moderator    = true,
	admin        = true,
	superadmin   = true,
	dmoderator   = true,
	dadmin       = true,
	dsuperadmin  = true,
}

local function isAllowedGroup( ply )
	if ( not IsValid( ply ) ) then
		return false
	end
	local group = string_lower( ply:GetUserGroup() or "" )
	return allowedGroups[group] == true
end

local function gimmethatscreen( calling_ply )
	if not calling_ply:IsValid() then
		Msg ( "gts menu cannot be opened from the server." )
		return
	elseif isAllowedGroup( calling_ply ) then
		calling_ply:ConCommand( "gts" )
	else
		MsgC( Color(255,0,0), calling_ply:GetName() .. " is attempting to open GimmeThatScreen GUI without administrator privileges." )
	end
end

local gtsUlxCompatibilities = ulx.command( CATEGORY, "ulx gts", gimmethatscreen, "!gts", true )
gtsUlxCompatibilities:defaultAccess( ULib.ACCESS_ADMIN )
gtsUlxCompatibilities:help( "Open GimmeThatScreen panel." )