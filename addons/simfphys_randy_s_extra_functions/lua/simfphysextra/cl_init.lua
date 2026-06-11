--moved clientside convars here

CreateClientConVar( "cl_simfphys_randomcolors", "1", true, true, "Set to apply a random color when a supported Simfphys vehicle is spawned." )
CreateClientConVar( "cl_simfphys_randombodygroups", "1", true, true, "Set to apply random bodygroups when a supported Simfphys vehicle is spawned." )
CreateClientConVar( "cl_simfphys_vehiclepresets", "1", true, true, "Set to use vehicle presets (colors/bodygroups) defined by the vehicle's author." )
CreateClientConVar( "cl_simfphys_bus_safety_brakes", "1", true, true,"Set to apply the handbrake if the doors are open on a bus. Only works on supported Simfphys vehicles." )
CreateClientConVar( "cl_simfphys_randomfuel", "1", true, true, "Set to randomize the amount of fuel in the tank when a simfphys vehicle is spawned." )
CreateClientConVar( "cl_simfphys_randomfuel_min", "10", true, true, "The minimum amount of fuel (percentage) vehicles should spawn with." )