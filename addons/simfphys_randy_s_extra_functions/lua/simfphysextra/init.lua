--DO NOT REDISTRIBUTE THIS CODE IN YOUR ADDONS. IF YOU WANT TO MAKE CHANGES TO IT ASK ME FIRST.
--moved all initializing stuff here

RANDYS = istable( RANDYS ) and RANDYS or {} --define table to store all functions in

AddCSLuaFile("simfphysextra/shared.lua")
AddCSLuaFile("simfphysextra/hooks.lua")
AddCSLuaFile("simfphysextra/tab.lua")

include("simfphysextra/shared.lua")
include("simfphysextra/hooks.lua")
include("simfphysextra/tab.lua")

CreateConVar( "sv_simfphys_brakenoises", "1", {FCVAR_REPLICATED , FCVAR_ARCHIVE}, "Set to play brake disc sounds when Simfphys vehicles are braking.", 0, 1 )
CreateConVar( "sv_simfphys_license_plates", "1", {FCVAR_REPLICATED , FCVAR_ARCHIVE}, "Set to apply randomized license plates to newly spawned supported Simfphys vehicles.", 0, 1 )
CreateConVar( "sv_simfphys_trailer_legs", "1", {FCVAR_REPLICATED , FCVAR_ARCHIVE}, "Set to use physical trailer legs on supported Simfphys trailers.", 0, 1 )
CreateConVar( "sv_simfphys_advanced_ignition", "1", {FCVAR_REPLICATED , FCVAR_ARCHIVE}, "Set to use an actual ignition to start up all Simfphys vehicles. This will also affect the vehicles when they are low on health.", 0, 1 )
CreateConVar( "sv_simfphys_bullhorn", "1", {FCVAR_REPLICATED , FCVAR_ARCHIVE}, "Set to allow bullhorns on supported Simfphys vehicles.", 0, 1 )
CreateConVar( "sv_simfphys_alarms", "1", {FCVAR_REPLICATED , FCVAR_ARCHIVE}, "Set to allow alarms on supported simfphys vehicles.", 0, 1 )
--create server convars
	
--add the network string required to apply the server options. this is so that multiple superadmins can apply changes without stuff breaking
if SERVER then
	util.AddNetworkString( "simfphys_extra_settings" )
	
	net.Receive( "simfphys_extra_settings", function( length, ply )
		if not IsValid( ply ) or not ply:IsSuperAdmin() then return end
		
		local platesEnabled = tostring(net.ReadBool() and 1 or 0)
		local legsEnabled = tostring(net.ReadBool() and 1 or 0)
		local bullhornEnabled = tostring(net.ReadBool() and 1 or 0)
		local BrakesEnabled = tostring(net.ReadBool() and 1 or 0)
		local IgnitionEnabled = tostring(net.ReadBool() and 1 or 0)
		local AlarmsEnabled = tostring(net.ReadBool() and 1 or 0)
		
		RunConsoleCommand("sv_simfphys_license_plates", platesEnabled ) 
		RunConsoleCommand("sv_simfphys_trailer_legs", legsEnabled ) 
		RunConsoleCommand("sv_simfphys_bullhorn", bullhornEnabled ) 
		RunConsoleCommand("sv_simfphys_brakenoises", BrakesEnabled ) 
		RunConsoleCommand("sv_simfphys_advanced_ignition", IgnitionEnabled ) 
		RunConsoleCommand("sv_simfphys_alarms", AlarmsEnabled ) 
	end)
end

--[[actionKey1 = CreateClientConVar( "simfphys_action1", KEY_PAD_1, true, true, "Action key for supported simfphys vehicles. Use the customization menu to change this!" )
actionKey2 = CreateClientConVar( "simfphys_action2", KEY_PAD_2, true, true, "Action key for supported simfphys vehicles. Use the customization menu to change this!" )
actionKey3 = CreateClientConVar( "simfphys_action3", KEY_PAD_3, true, true, "Action key for supported simfphys vehicles. Use the customization menu to change this!" )
actionKey4 = CreateClientConVar( "simfphys_action4", KEY_PAD_4, true, true, "Action key for supported simfphys vehicles. Use the customization menu to change this!" )
actionKey5 = CreateClientConVar( "simfphys_action5", KEY_PAD_5, true, true, "Action key for supported simfphys vehicles. Use the customization menu to change this!" )]]
--bind-able input keys. This shit doesnt work