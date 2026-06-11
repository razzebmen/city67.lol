--This is the major group of plates. This will usually be the base game you're porting from.
--EXAMPLE ==
if istable( RANDYS ) then --check if shared addon is mounted.
	RANDYS.Plates_Generic = {
		"models/randy/license_plate_generic", --FRONT PLATE MODEL PATH
		"models/randy/license_plate_generic", --REAR PLATE MODEL PATH (if it exists, if it does not just use the front plate)
	}
end

--These are the possible plate types. You will be able to specify which group to put on a vehicle, but the script will randomly pick from the list of items that group contains.
--EXAMPLE ==
--Plates_ATS_Civilian = {"_ca", "_co" }  -  -  -  I can specify I want the "ATS_Civilian" group on the vehicle, but the script will randomly pick between the available options,
--the strings you specify here will be APPENDED AFTER the paths you specify in the MAJOR group above.
--for example it might be license_plate_generic_ca.mdl or license_plate_generic_co.mdl, this is useful for randomization
--if you do not specify ANY Types, then the script will simply use the major group for the mdl files (no appending)

--DON'T FORGET TO RENAME THE GROUPS AS WELL!!! NOT JUST THE FILE!!!