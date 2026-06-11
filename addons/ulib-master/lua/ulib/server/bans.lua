local function nilIfNull(data)
	if data == "NULL" then return nil
	else return data end
end

--[[
	Title: Bans

	Ban-related functions and listeners.
]]

-- ULib default ban message
ULib.BanMessage = [[
-------===== [ BANNED ] =====-------

Причина: {{REASON}}
Срок: {{TIME_LEFT}}
Администратор: {{BANNED_BY}}

Апелляция и поддержка в Discord:
https://discord.gg/xvaStaQhmh ]]

function ULib.getBanMessage( steamid, banData, templateMessage )
	banData = banData or ULib.bans[ steamid ]
	if not banData then return end
	templateMessage = templateMessage or ULib.BanMessage

	local replacements = {
		BANNED_BY = "(Unknown)",
		BAN_START = "(Unknown)",
		REASON = "(None given)",
		TIME_LEFT = "(Permaban)",
		STEAMID = steamid,
		STEAMID64 = util.SteamIDTo64( steamid ),
	}

	if banData.admin and banData.admin ~= "" then
		replacements.BANNED_BY = banData.admin
	end

	local time = tonumber( banData.time )
	if time and time > 0 then
		replacements.BAN_START = os.date( "%c", time )
	end

	if banData.reason and banData.reason ~= "" then
		replacements.REASON = banData.reason
	end

	local unban = tonumber( banData.unban )
	if unban and unban > 0 then
		replacements.TIME_LEFT = ULib.secondsToStringTime( unban - os.time() )
	end
  
  	local banMessage = templateMessage:gsub( "{{([%w_]+)}}", replacements )
	return banMessage
end

if(ULib)then
	local function checkBan( steamid64, ip, password, clpassword, name, noRefresh )
		local steamid = util.SteamIDFrom64( steamid64 )
		local banData = ULib.bans[ steamid ]

		if not banData then
			local query = mysql:Select("ulib_bans")
			query:Where("steamid",steamid64)
			query:Callback(function(results)
				if results then
					for i = 1, #results do
						local r = results[i]
						--print(i)
						--PrintTable(r)
						r.steamID = util.SteamIDFrom64( r.steamid )
						r.steamid = nil
						r.reason = nilIfNull( r.reason )
						r.name = nilIfNull( r.name )
						r.admin = nilIfNull( r.admin )
						r.modified_admin = nilIfNull( r.modified_admin )
						r.modified_time = nilIfNull( r.modified_time )
						ULib.bans[ r.steamID ] = r

						local unban = tonumber( r.unban )
						if unban - os.time() < 0 and unban > 0 then return end
						local message = ULib.getBanMessage( steamid )
						game.KickID(steamid,message)
					end
				end
			end)
			query:Execute()
		return end
		-- Nothing useful to show them, go to default message
		local unban = tonumber( banData.unban )
		if unban - os.time() < 0 and unban > 0 then return end
		if not banData.admin and not banData.reason and not banData.unban and not banData.time then return end

		local message = ULib.getBanMessage( steamid )
		Msg(string.format("%s (%s)<%s> was kicked by ULib because they are on the ban list\n", name, steamid, ip))
		return false, message
	end
	
	hook.Add( "CheckPassword", "ULibBanCheck", checkBan )
	
	hook.Add( "NetworkIDValidated", "KickIdiotFromServer", function( name, steamID, ownerID )
		timer.Simple(0,function()
			local hasBan,reason = checkBan( ownerID )
			if hasBan == false then
				game.KickID(steamid,reason)
				return
			end
		end)
	end )
end
-- Low priority to allow servers to easily have another ban message addon


--[[
	Function: ban

	Bans a user.

	Parameters:

		ply - The player to ban.
		time - *(Optional)* The time in minutes to ban the person for, leave nil or 0 for permaban.
		reason - *(Optional)* The reason for banning
		admin - *(Optional)* Admin player enacting ban

	Revisions:

		v2.10 - Added support for custom ban list
]]
function ULib.ban( ply, time, reason, admin )
	if not time or type( time ) ~= "number" then
		time = 0
	end

	if ply:IsListenServerHost() then
		return
	end

	ULib.addBan( ply:SteamID(), time, reason, ply:Name(), admin )
end


--[[
	Function: kickban

	An alias for <ban>.
]]
ULib.kickban = ULib.ban


local function escapeOrNull( str )
	if not str then return "NULL"
	else return sql.SQLStr(str) end
end


local function writeBan( bandata )
	sql.Query(
		"REPLACE INTO ulib_bans (steamid, time, unban, reason, name, admin, modified_admin, modified_time) " ..
		string.format( "VALUES (%s, %i, %i, %s, %s, %s, %s, %s)",
			util.SteamIDTo64( bandata.steamID ),
			bandata.time or 0,
			bandata.unban or 0,
			escapeOrNull( bandata.reason ),
			escapeOrNull( bandata.name ),
			escapeOrNull( bandata.admin ),
			escapeOrNull( bandata.modified_admin ),
			escapeOrNull( bandata.modified_time )
		)
	)
	if ULib.mySQL_Active then
		local query = mysql:Select("ulib_bans")
		query:Where("steamid", tostring(util.SteamIDTo64( bandata.steamID )))
		query:Callback(function(result)
			if not result or not result[1] then
				local insertQuery = mysql:Insert("ulib_bans")
					insertQuery:Insert("steamid", tostring(util.SteamIDTo64( bandata.steamID )))
					insertQuery:Insert("time", tostring(bandata.time or 0))
					insertQuery:Insert("unban", tostring(bandata.unban or 0))
					insertQuery:Insert("reason", bandata.reason or "NULL" )
					insertQuery:Insert("name", bandata.name or "NULL" )
					insertQuery:Insert("admin", bandata.admin or "NULL" )
					if bandata.modified_admin then
						insertQuery:Insert("modified_admin", bandata.modified_admin )
					end
					if bandata.modified_time then
						insertQuery:Insert("modified_time", bandata.modified_time )
					end
				insertQuery:Execute()
			else
				local updateQuery = mysql:Update("ulib_bans")
					updateQuery:Update("time", tostring(bandata.time or 0))
					updateQuery:Update("unban", tostring(bandata.unban or 0))
					updateQuery:Update("reason", bandata.reason or "NULL" )
					updateQuery:Update("name", bandata.name or "NULL" )
					updateQuery:Update("admin", bandata.admin or "NULL" )
					if bandata.modified_admin then
						updateQuery:Update("modified_admin", bandata.modified_admin )
					end
					if bandata.modified_time then
						updateQuery:Update("modified_time", bandata.modified_time )
					end
					updateQuery:Where("steamid", util.SteamIDTo64( bandata.steamID ))
				updateQuery:Execute()
			end
		end)
		query:Execute()
	end
end


--[[
	Function: addBan

	Helper function to store additional data about bans.

	Parameters:

		steamid - Banned player's steamid
		time - Length of ban in minutes, use 0 for permanant bans
		reason - *(Optional)* Reason for banning
		name - *(Optional)* Name of player banned
		admin - *(Optional)* Admin player enacting the ban

	Revisions:

		2.10 - Initial
		2.40 - If the steamid is connected, kicks them with the reason given
]]
function ULib.addBan( steamid, time, reason, name, admin, override )
	if reason == "" then reason = nil end

	local admin_name
	if admin then
		if isstring(admin) then
			admin_name = admin
		elseif not IsValid(admin) then
			admin_name = "(Console)"
		elseif admin:IsPlayer() then
			admin_name = string.format("%s(%s)", admin:Name(), admin:SteamID())
		end
	end

	-- Clean up passed data
	local t = {}
	local timeNow = os.time()
	if ULib.bans[ steamid ] then
		t = ULib.bans[ steamid ]
		t.modified_admin = admin_name
		t.modified_time = timeNow
	else
		t.admin = admin_name
	end
	t.time = t.time or timeNow
	if time > 0 then
		t.unban = ( ( time * 60 ) + timeNow )
	else
		t.unban = 0
	end
	t.reason = reason
	t.name = name
	t.steamID = steamid

	ULib.bans[ steamid ] = t

	local strTime = time ~= 0 and ULib.secondsToStringTime( time*60 )
	local shortReason = "Banned for " .. (strTime or "eternity")
	if reason then
		shortReason = shortReason .. ": " .. reason
	end

	local longReason = shortReason
	if reason or strTime or admin then -- If we have something useful to show
		longReason = "\n" .. ULib.getBanMessage( steamid ) .. "\n" -- Newlines because we are forced to show "Disconnect: <msg>."
	end

	local ply = player.GetBySteamID( steamid )
	if ply then
		--if steamid != ply:OwnerSteamID64() and not override then
		--	ULib.addBan( util.SteamIDFrom64( ply:OwnerSteamID64() ), time, reason, name, admin, true )
		--end
		ULib.kick( ply, longReason, nil, true)
	end

	-- This redundant kick is to ensure they're kicked -- even if they're joining
	game.KickID( steamid, shortReason or "" )

	writeBan( t )
	hook.Call( ULib.HOOK_USER_BANNED, _, steamid, t )
end


--[[
	Function: unban

	Unbans the given steamid.

	Parameters:

		steamid - The steamid to unban.
		admin - *(Optional)* Admin player unbanning steamid

	Revisions:

		v2.10 - Initial
]]
function ULib.unban( steamid, admin )
	RunConsoleCommand("removeid", steamid) -- Remove from srcds in case it was stored there
	RunConsoleCommand("writeid") -- Saving

	--ULib banlist
	ULib.bans[ steamid ] = nil
	sql.Query( "DELETE FROM ulib_bans WHERE steamid=" .. util.SteamIDTo64( steamid ) )
	hook.Call( ULib.HOOK_USER_UNBANNED, _, steamid, admin )

	if ULib.mySQL_Active then
		local query = mysql:Delete("ulib_bans")
		query:Where("steamid", tostring(util.SteamIDTo64( steamid )))
		query:Execute()
	end
end

-- Init our bans table
if not sql.TableExists( "ulib_bans" ) then
	sql.Query( "CREATE TABLE IF NOT EXISTS ulib_bans ( " ..
		"steamid INTEGER NOT NULL PRIMARY KEY, " ..
		"time INTEGER NOT NULL, " ..
		"unban INTEGER NOT NULL, " ..
		"reason TEXT, " ..
		"name TEXT, " ..
		"admin TEXT, " ..
		"modified_admin TEXT, " ..
		"modified_time INTEGER " ..
		");" )
	sql.Query( "CREATE INDEX IDX_ULIB_BANS_TIME ON ulib_bans ( time DESC );" )
	sql.Query( "CREATE INDEX IDX_ULIB_BANS_UNBAN ON ulib_bans ( unban DESC );" )
end

local LEGACY_BANS_FILE = "data/ulib/bans.txt"
--[[
	Function: getLegacyBans

	Returns bans written by ULib versions prior to 2.7.
]]
function ULib.getLegacyBans()
	if not ULib.fileExists( LEGACY_BANS_FILE ) then
		return nil
	end

	local bans, err = ULib.parseKeyValues( ULib.fileRead( LEGACY_BANS_FILE ) )

	if err then
		return nil
	else
		return bans
	end
end

local legacy_bans = ULib.getLegacyBans()


--[[
	Function: refreshBans

	Refreshes the ULib bans.
]]

--[[
	"steamid INTEGER NOT NULL PRIMARY KEY, " ..
	"time INTEGER NOT NULL, " ..
	"unban INTEGER NOT NULL, " ..
	"reason TEXT, " ..
	"name TEXT, " ..
	"admin TEXT, " ..
	"modified_admin TEXT, " ..
	"modified_time INTEGER " ..
--]]
-- Ulib sync with DB

function ULib.DB_SyncBans()
	local results = sql.Query( "SELECT * FROM ulib_bans" )
	if results then
		for i=1, #results do
			local r = results[i]
			local query = mysql:Select("ulib_bans")
			query:Where("steamid", tostring(r.steamid))
			query:Callback(function(result)
				if not result or not result[1] then
					local insertQuery = mysql:Insert("ulib_bans")
						insertQuery:Insert("steamid", tostring(r.steamid))
						insertQuery:Insert("time", tostring(r.time))
						insertQuery:Insert("unban", tostring(r.unban))
						insertQuery:Insert("reason", r.reason)
						insertQuery:Insert("name", r.name)
						insertQuery:Insert("admin", r.admin)
						if r.modified_admin != "NULL" then
							insertQuery:Insert("modified_admin", r.modified_admin)
						end
						if r.modified_time != "NULL" then
							insertQuery:Insert("modified_time", r.modified_time)
						end
					insertQuery:Execute()
				end
			end)
			query:Execute()
		end
	end
end

hook.Add("DatabaseConnected", "ULibBansDB", function()
	local query

	query = mysql:Create("ulib_bans")
		query:Create("steamid", "VARCHAR(20) NOT NULL")
		query:Create("time", "INT NOT NULL")
		query:Create("unban", "INT NOT NULL")
		query:Create("reason", "TEXT")
		query:Create("name", "TEXT")
        query:Create("admin", "TEXT")
		query:Create("modified_admin", "TEXT")
		query:Create("modified_time", "INT")
		query:PrimaryKey("steamid")
	query:Execute()

    ULib.mySQL_Active = true

	ULib.refreshBans()
end)

function ULib.refreshBans()
	ULib.bans = {}

	if ULib.mySQL_Active then
		local query = mysql:Select("ulib_bans")
			query:Callback(function(results)
				if results then
					for i=1, #results do
						local r = results[i]
						--print(i)
						--PrintTable(r)
						r.steamID = util.SteamIDFrom64( r.steamid )
						r.steamid = nil
						r.reason = nilIfNull( r.reason )
						r.name = nilIfNull( r.name )
						r.admin = nilIfNull( r.admin )
						r.modified_admin = nilIfNull( r.modified_admin )
						r.modified_time = nilIfNull( r.modified_time )
						ULib.bans[ r.steamID ] = r
					end
				end
			end)
		query:Execute()
	end
end

hook.Add( "Initialize", "ULibLoadBans", ULib.refreshBans, HOOK_MONITOR_HIGH )
