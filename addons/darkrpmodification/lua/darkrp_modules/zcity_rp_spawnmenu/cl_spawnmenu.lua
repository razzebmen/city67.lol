-- ZCity RP — кастомное спавн-меню (только vip / moderator / dmoderator)
-- dadmin и выше (admin, superadmin, dsuperadmin, operator) — полный
-- стандартный Q-меню без какой-либо фильтрации вкладок/инструментов.

local ACCESS_GROUPS = {
    vip        = true,
    moderator  = true,
    dmoderator = true,
}

local ALLOWED_TOOLS = {
    textscreen       = true,
    advdupe2         = true,
    keypad_willox    = true,
    light            = true,
    button           = true,
    fading_door      = true,
    stacker_improved = true,
    remover          = true,
    camera           = true,
    material         = true,
    colour           = true,
}

local function HasAccess()
    local ply = LocalPlayer()
    return IsValid(ply) and ACCESS_GROUPS[ply:GetUserGroup()]
end

-- ===== ПРОПЫ: КОНСТРУКЦИИ =====
local Props_Constructions = {
    "models/props_phx/construct/metal_plate1.mdl",
    "models/props_phx/construct/metal_plate1x2.mdl",
    "models/props_phx/construct/metal_plate1x2_tri.mdl",
    "models/props_phx/construct/metal_plate1_tri.mdl",
    "models/props_phx/construct/metal_plate2x2.mdl",
    "models/props_phx/construct/metal_plate2x2_tri.mdl",
    "models/props_phx/construct/metal_plate2x4.mdl",
    "models/props_phx/construct/metal_plate2x4_tri.mdl",
    "models/props_phx/construct/metal_plate4x4.mdl",
    "models/props_phx/construct/metal_plate4x4_tri.mdl",
    "models/props_phx/construct/metal_tube.mdl",
    "models/props_phx/construct/metal_tubex2.mdl",
    "models/props_phx/construct/metal_wire1x1.mdl",
    "models/props_phx/construct/metal_wire1x1x1.mdl",
    "models/props_phx/construct/metal_wire1x1x2.mdl",
    "models/props_phx/construct/metal_wire1x1x2b.mdl",
    "models/props_phx/construct/metal_wire1x2.mdl",
    "models/props_phx/construct/metal_wire1x2b.mdl",
    "models/props_phx/construct/metal_wire1x2x2b.mdl",
    "models/props_phx/construct/metal_wire2x2.mdl",
    "models/props_phx/construct/metal_wire2x2b.mdl",
    "models/props_phx/construct/metal_wire2x2x2b.mdl",
    "models/props_phx/construct/windows/window1x1.mdl",
    "models/props_phx/construct/windows/window1x2.mdl",
    "models/props_phx/construct/windows/window2x2.mdl",
    "models/props_phx/construct/windows/window2x4.mdl",
    "models/props_phx/construct/wood/wood_boardx1.mdl",
    "models/props_phx/construct/wood/wood_boardx2.mdl",
    "models/props_phx/construct/wood/wood_boardx4.mdl",
    "models/props_phx/construct/wood/wood_panel1x1.mdl",
    "models/props_phx/construct/wood/wood_panel1x2.mdl",
    "models/props_phx/construct/wood/wood_panel2x2.mdl",
    "models/props_phx/construct/wood/wood_panel2x4.mdl",
    "models/props_phx/construct/wood/wood_panel4x4.mdl",
    "models/props_phx/construct/wood/wood_wire1x1.mdl",
    "models/props_phx/construct/wood/wood_wire1x1x1.mdl",
    "models/props_phx/construct/wood/wood_wire1x1x2.mdl",
    "models/props_phx/construct/wood/wood_wire1x1x2b.mdl",
    "models/props_phx/construct/wood/wood_wire1x2.mdl",
    "models/props_phx/construct/wood/wood_wire1x2b.mdl",
    "models/props_phx/construct/wood/wood_wire1x2x2b.mdl",
    "models/props_phx/construct/wood/wood_wire2x2.mdl",
    "models/props_phx/construct/wood/wood_wire2x2x2b.mdl",
    "models/props_phx/construct/plastic/plastic_angle_180.mdl",
    "models/props_phx/construct/plastic/plastic_angle_360.mdl",
    "models/props_phx/construct/plastic/plastic_angle_90.mdl",
    "models/props_phx/construct/plastic/plastic_panel1x1.mdl",
    "models/props_phx/construct/plastic/plastic_panel1x2.mdl",
    "models/props_phx/construct/plastic/plastic_panel1x3.mdl",
    "models/props_phx/construct/plastic/plastic_panel1x4.mdl",
    "models/props_phx/construct/plastic/plastic_panel1x8.mdl",
    "models/props_phx/construct/plastic/plastic_panel2x2.mdl",
    "models/props_phx/construct/plastic/plastic_panel2x3.mdl",
    "models/props_phx/construct/plastic/plastic_panel2x4.mdl",
    "models/props_phx/construct/plastic/plastic_panel2x8.mdl",
    "models/props_phx/construct/plastic/plastic_panel3x3.mdl",
    "models/props_phx/construct/plastic/plastic_panel4x4.mdl",
    "models/props_phx/construct/plastic/plastic_panel4x8.mdl",
    "models/props_phx/construct/plastic/plastic_panel8x8.mdl",
    "models/Mechanics/gears2/pinion_20t3.mdl",
    "models/Mechanics/gears2/pinion_40t3.mdl",
    "models/Mechanics/gears2/pinion_80t3.mdl",
    "models/hunter/tubes/circle2x2.mdl",
    "models/hunter/tubes/circle2x2c.mdl",
    "models/hunter/tubes/circle4x4.mdl",
    "models/hunter/tubes/circle4x4c.mdl",
    "models/props_phx/construct/metal_angle180.mdl",
    "models/props_phx/construct/metal_angle360.mdl",
    "models/props_phx/construct/metal_angle90.mdl",
    "models/props_phx/construct/metal_dome180.mdl",
    "models/props_phx/construct/metal_dome360.mdl",
    "models/props_phx/construct/metal_dome90.mdl",
    "models/props_phx/construct/metal_plate_curve.mdl",
    "models/props_phx/construct/metal_plate_curve180.mdl",
    "models/props_phx/construct/metal_plate_curve180x2.mdl",
    "models/props_phx/construct/metal_plate_curve2.mdl",
    "models/props_phx/construct/metal_plate_curve2x2.mdl",
    "models/props_phx/construct/metal_plate_curve360.mdl",
    "models/props_phx/construct/metal_plate_curve360x2.mdl",
    "models/props_phx/construct/metal_wire_angle180x1.mdl",
    "models/props_phx/construct/metal_wire_angle180x2.mdl",
    "models/props_phx/construct/metal_wire_angle360x1.mdl",
    "models/props_phx/construct/metal_wire_angle360x2.mdl",
    "models/props_phx/construct/metal_wire_angle90x1.mdl",
    "models/props_phx/construct/metal_wire_angle90x2.mdl",
    "models/props_phx/construct/windows/window_angle180.mdl",
    "models/props_phx/construct/windows/window_angle360.mdl",
    "models/props_phx/construct/windows/window_angle90.mdl",
    "models/props_phx/construct/windows/window_curve180x1.mdl",
    "models/props_phx/construct/windows/window_curve180x2.mdl",
    "models/props_phx/construct/windows/window_curve360x1.mdl",
    "models/props_phx/construct/windows/window_curve360x2.mdl",
    "models/props_phx/construct/windows/window_curve90x1.mdl",
    "models/props_phx/construct/windows/window_curve90x2.mdl",
    "models/props_phx/construct/windows/window_dome180.mdl",
    "models/props_phx/construct/windows/window_dome360.mdl",
    "models/props_phx/construct/windows/window_dome90.mdl",
    "models/hunter/triangles/025x025.mdl",
    "models/hunter/triangles/05x05.mdl",
    "models/hunter/triangles/075x075.mdl",
    "models/hunter/triangles/1x1.mdl",
    "models/hunter/triangles/2x2.mdl",
    "models/hunter/triangles/3x3.mdl",
    "models/hunter/triangles/4x4.mdl",
    "models/hunter/plates/tri2x1.mdl",
    "models/hunter/plates/tri3x1.mdl",
    "models/hunter/triangles/025x025mirrored.mdl",
    "models/hunter/triangles/05x05mirrored.mdl",
    "models/hunter/triangles/075x075mirrored.mdl",
    "models/hunter/triangles/1x1mirrored.mdl",
    "models/hunter/triangles/2x2mirrored.mdl",
    "models/hunter/triangles/3x3mirrored.mdl",
    "models/hunter/triangles/4x4mirrored.mdl",
    "models/hunter/triangles/05x05x05.mdl",
    "models/hunter/triangles/1x05x05.mdl",
    "models/hunter/triangles/1x05x1.mdl",
    "models/hunter/triangles/1x1x1.mdl",
    "models/hunter/triangles/1x1x2.mdl",
    "models/hunter/triangles/1x1x3.mdl",
    "models/hunter/triangles/1x1x4.mdl",
    "models/hunter/triangles/2x1x1.mdl",
    "models/hunter/triangles/2x2x2.mdl",
    "models/hunter/triangles/3x2x2.mdl",
    "models/hunter/triangles/1x1x1carved.mdl",
    "models/hunter/triangles/2x1x1carved.mdl",
    "models/hunter/triangles/2x2x1carved.mdl",
    "models/hunter/triangles/1x1x2carved.mdl",
    "models/hunter/triangles/1x1x1carved025.mdl",
    "models/hunter/triangles/1x1x2carved025.mdl",
    "models/hunter/triangles/1x1x4carved025.mdl",
    "models/XQM/panel45.mdl",
    "models/XQM/panel90.mdl",
    "models/XQM/panel180.mdl",
    "models/XQM/panel360.mdl",
    "models/PHXtended/bar1x.mdl",
    "models/PHXtended/bar2x.mdl",
    "models/PHXtended/tri1x1.mdl",
    "models/PHXtended/tri1x1solid.mdl",
    "models/PHXtended/tri1x1x1.mdl",
    "models/PHXtended/tri1x1x1solid.mdl",
    "models/PHXtended/tri1x1x2.mdl",
    "models/PHXtended/tri1x1x2solid.mdl",
    "models/PHXtended/trieq1x1x1.mdl",
    "models/PHXtended/trieq1x1x2.mdl",
    "models/PHXtended/trieq1x1x2solid.mdl",
    "models/hunter/misc/stair1x1.mdl",
    "models/hunter/misc/stair1x1inside.mdl",
    "models/hunter/misc/stair1x1outside.mdl",
    "models/Mechanics/robotics/a2.mdl",
    "models/Mechanics/robotics/a3.mdl",
    "models/Mechanics/robotics/a4.mdl",
}

-- ===== ПРОПЫ: ПЛАСТИНЫ И КУБЫ =====
local Props_Plates = {
    "models/hunter/plates/plate1x2.mdl",
    "models/hunter/plates/plate1x3.mdl",
    "models/hunter/plates/plate1x4.mdl",
    "models/hunter/plates/plate1x5.mdl",
    "models/hunter/plates/plate1x6.mdl",
    "models/hunter/plates/plate1x7.mdl",
    "models/hunter/plates/plate1x8.mdl",
    "models/hunter/plates/plate2x2.mdl",
    "models/hunter/plates/plate2x3.mdl",
    "models/hunter/plates/plate2x4.mdl",
    "models/hunter/plates/plate2x5.mdl",
    "models/hunter/plates/plate2x6.mdl",
    "models/hunter/plates/plate2x7.mdl",
    "models/hunter/plates/plate2x8.mdl",
    "models/hunter/plates/plate3x3.mdl",
    "models/hunter/plates/plate3x4.mdl",
    "models/hunter/plates/plate3x5.mdl",
    "models/hunter/plates/plate3x6.mdl",
    "models/hunter/plates/plate3x7.mdl",
    "models/hunter/plates/plate3x8.mdl",
    "models/hunter/plates/plate4x4.mdl",
    "models/hunter/plates/plate4x5.mdl",
    "models/hunter/plates/plate4x6.mdl",
    "models/hunter/plates/plate4x7.mdl",
    "models/hunter/plates/plate4x8.mdl",
    "models/hunter/plates/plate5x5.mdl",
    "models/hunter/plates/plate5x6.mdl",
    "models/hunter/plates/plate5x7.mdl",
    "models/hunter/plates/plate5x8.mdl",
    "models/hunter/plates/plate6x6.mdl",
    "models/hunter/plates/plate6x7.mdl",
    "models/hunter/plates/plate6x8.mdl",
    "models/hunter/plates/plate7x7.mdl",
    "models/hunter/plates/plate7x8.mdl",
    "models/hunter/plates/plate8x8.mdl",
    "models/hunter/blocks/cube025x025x025.mdl",
    "models/hunter/blocks/cube025x05x025.mdl",
    "models/hunter/blocks/cube025x075x025.mdl",
    "models/hunter/blocks/cube025x1x025.mdl",
    "models/hunter/blocks/cube025x125x025.mdl",
    "models/hunter/blocks/cube025x150x025.mdl",
    "models/hunter/blocks/cube025x2x025.mdl",
    "models/hunter/blocks/cube025x3x025.mdl",
    "models/hunter/blocks/cube025x4x025.mdl",
    "models/hunter/blocks/cube05x05x025.mdl",
    "models/hunter/blocks/cube05x075x025.mdl",
    "models/hunter/blocks/cube05x1x025.mdl",
    "models/hunter/blocks/cube05x2x025.mdl",
    "models/hunter/blocks/cube05x3x025.mdl",
    "models/hunter/blocks/cube05x4x025.mdl",
    "models/hunter/blocks/cube05x5x025.mdl",
    "models/hunter/blocks/cube05x6x025.mdl",
    "models/hunter/blocks/cube05x7x025.mdl",
    "models/hunter/blocks/cube075x075x025.mdl",
    "models/hunter/blocks/cube075x1x025.mdl",
    "models/hunter/blocks/cube075x2x025.mdl",
    "models/hunter/blocks/cube075x3x025.mdl",
    "models/hunter/blocks/cube075x4x025.mdl",
    "models/hunter/blocks/cube1x1x025.mdl",
    "models/hunter/blocks/cube1x2x025.mdl",
    "models/hunter/blocks/cube1x3x025.mdl",
    "models/hunter/blocks/cube1x4x025.mdl",
    "models/hunter/blocks/cube1x5x025.mdl",
    "models/hunter/blocks/cube1x6x025.mdl",
    "models/hunter/blocks/cube1x7x025.mdl",
    "models/hunter/blocks/cube1x8x025.mdl",
    "models/hunter/blocks/cube2x2x025.mdl",
    "models/hunter/blocks/cube2x3x025.mdl",
    "models/hunter/blocks/cube2x4x025.mdl",
    "models/hunter/blocks/cube2x6x025.mdl",
    "models/hunter/blocks/cube2x8x025.mdl",
    "models/hunter/blocks/cube3x3x025.mdl",
    "models/hunter/blocks/cube3x4x025.mdl",
    "models/hunter/blocks/cube3x6x025.mdl",
    "models/hunter/blocks/cube3x8x025.mdl",
    "models/hunter/blocks/cube4x4x025.mdl",
    "models/hunter/blocks/cube4x6x025.mdl",
    "models/hunter/blocks/cube05x05x05.mdl",
    "models/hunter/blocks/cube05x1x05.mdl",
    "models/hunter/blocks/cube05x105x05.mdl",
    "models/hunter/blocks/cube05x2x05.mdl",
    "models/hunter/blocks/cube05x3x05.mdl",
    "models/hunter/blocks/cube05x4x05.mdl",
    "models/hunter/blocks/cube1x1x05.mdl",
    "models/hunter/blocks/cube1x2x05.mdl",
    "models/hunter/blocks/cube1x4x05.mdl",
    "models/hunter/blocks/cube1x6x05.mdl",
    "models/hunter/blocks/cube2x2x05.mdl",
    "models/hunter/blocks/cube2x4x05.mdl",
    "models/hunter/blocks/cube2x6x05.mdl",
    "models/hunter/blocks/cube3x3x05.mdl",
    "models/hunter/blocks/cube4x4x05.mdl",
    "models/hunter/blocks/cube4x6x05.mdl",
    "models/hunter/blocks/cube6x6x05.mdl",
}

-- ===== ПРОПЫ: ДЕКОР =====
local Props_Decor = {
    "models/props_phx/rt_screen.mdl",
    "models/props_c17/FurnitureWashingmachine001a.mdl",
    "models/props_c17/FurnitureToilet001a.mdl",
    "models/props_c17/FurnitureSink001a.mdl",
    "models/props_c17/canister_propane01a.mdl",
    "models/props_c17/GasPipes006a.mdl",
    "models/props_canal/mattpipe.mdl",
    "models/props_borealis/mooring_cleat01.mdl",
    "models/props_borealis/door_wheel001a.mdl",
    "models/props_borealis/borealis_door001a.mdl",
    "models/props_borealis/bluebarrel001.mdl",
    "models/props_c17/canister01a.mdl",
    "models/props_c17/canister02a.mdl",
    "models/props_c17/bench01a.mdl",
    "models/props_c17/chair02a.mdl",
    "models/props_c17/door01_left.mdl",
    "models/props_c17/door02_double.mdl",
    "models/props_c17/concrete_barrier001a.mdl",
    "models/props_phx/construct/concrete_barrier00.mdl",
    "models/props_phx/construct/concrete_barrier01.mdl",
    "models/props_c17/fence01a.mdl",
    "models/props_c17/fence01b.mdl",
    "models/props_c17/fence03a.mdl",
    "models/props_c17/fence02b.mdl",
    "models/props_c17/fence02a.mdl",
    "models/props_c17/FurnitureBathtub001a.mdl",
    "models/props_c17/FurnitureBed001a.mdl",
    "models/props_c17/FurnitureBoiler001a.mdl",
    "models/props_c17/FurnitureChair001a.mdl",
    "models/props_c17/FurnitureCouch001a.mdl",
    "models/props_c17/FurnitureCouch002a.mdl",
    "models/props_c17/FurnitureCupboard001a.mdl",
    "models/props_c17/FurnitureDrawer001a.mdl",
    "models/props_c17/FurnitureDrawer002a.mdl",
    "models/props_c17/FurnitureDrawer003a.mdl",
    "models/props_c17/FurnitureDresser001a.mdl",
    "models/props_c17/FurnitureFireplace001a.mdl",
    "models/props_c17/FurnitureFridge001a.mdl",
    "models/props_c17/FurnitureRadiator001a.mdl",
    "models/props_wasteland/prison_heater001a.mdl",
    "models/props_c17/FurnitureShelf001a.mdl",
    "models/props_c17/FurnitureShelf001b.mdl",
    "models/props_c17/FurnitureShelf002a.mdl",
    "models/props_c17/furnitureStove001a.mdl",
    "models/props_c17/FurnitureTable001a.mdl",
    "models/props_c17/FurnitureTable002a.mdl",
    "models/props_c17/FurnitureTable003a.mdl",
    "models/props_c17/gravestone001a.mdl",
    "models/props_c17/gravestone002a.mdl",
    "models/props_c17/gravestone003a.mdl",
    "models/props_junk/PlasticCrate01a.mdl",
    "models/props_c17/lampShade001a.mdl",
    "models/props_c17/Lockers001a.mdl",
    "models/props_c17/metalladder001.mdl",
    "models/props_c17/metalladder002.mdl",
    "models/props_c17/metalladder002b.mdl",
    "models/props_c17/oildrum001.mdl",
    "models/props_c17/pulleywheels_small01.mdl",
    "models/props_c17/pulleywheels_large01.mdl",
    "models/props_c17/shelfunit01a.mdl",
    "models/props_c17/signpole001.mdl",
    "models/props_combine/breenchair.mdl",
    "models/props_combine/breendesk.mdl",
    "models/props_combine/breenglobe.mdl",
    "models/props_debris/metal_panel01a.mdl",
    "models/props_debris/metal_panel02a.mdl",
    "models/props_docks/dock01_cleat01a.mdl",
    "models/props_doors/door03_slotted_left.mdl",
    "models/props_interiors/BathTub01a.mdl",
    "models/props_interiors/ElevatorShaft_Door01a.mdl",
    "models/props_interiors/Furniture_chair01a.mdl",
    "models/props_interiors/Furniture_chair03a.mdl",
    "models/props_interiors/Furniture_Couch01a.mdl",
    "models/props_interiors/Furniture_Couch02a.mdl",
    "models/props_interiors/Furniture_Desk01a.mdl",
    "models/props_interiors/Furniture_Lamp01a.mdl",
    "models/props_interiors/Furniture_shelf01a.mdl",
    "models/props_interiors/Furniture_Vanity01a.mdl",
    "models/props_interiors/pot01a.mdl",
    "models/props_interiors/pot02a.mdl",
    "models/props_interiors/Radiator01a.mdl",
    "models/props_interiors/refrigerator01a.mdl",
    "models/props_interiors/refrigeratorDoor01a.mdl",
    "models/props_interiors/refrigeratorDoor02a.mdl",
    "models/props_interiors/SinkKitchen01a.mdl",
    "models/props_interiors/VendingMachineSoda01a.mdl",
    "models/props_interiors/VendingMachineSoda01a_door.mdl",
    "models/props_junk/cardboard_box001a.mdl",
    "models/props_junk/cardboard_box002a.mdl",
    "models/props_junk/CinderBlock01a.mdl",
    "models/props_junk/harpoon002a.mdl",
    "models/props_junk/iBeam01a_cluster01.mdl",
    "models/props_junk/iBeam01a.mdl",
    "models/props_junk/meathook001a.mdl",
    "models/props_junk/metal_paintcan001a.mdl",
    "models/props_junk/MetalBucket01a.mdl",
    "models/props_junk/MetalBucket02a.mdl",
    "models/props_junk/metalgascan.mdl",
    "models/props_junk/PropaneCanister001a.mdl",
    "models/props_junk/PushCart01a.mdl",
    "models/props_junk/sawblade001a.mdl",
    "models/props_junk/TrashBin01a.mdl",
    "models/props_junk/TrafficCone001a.mdl",
    "models/props_junk/TrashDumpster02b.mdl",
    "models/props_junk/TrashDumpster01a.mdl",
    "models/props_junk/wood_crate001a.mdl",
    "models/props_junk/wood_crate002a.mdl",
    "models/props_junk/wood_pallet001a.mdl",
    "models/props_lab/blastdoor001a.mdl",
    "models/props_lab/blastdoor001b.mdl",
    "models/props_lab/blastdoor001c.mdl",
    "models/props_lab/filecabinet02.mdl",
    "models/props_lab/kennel_physics.mdl",
    "models/props_lab/lockerdoorleft.mdl",
    "models/props_trainstation/BenchOutdoor01a.mdl",
    "models/props_trainstation/bench_indoor001a.mdl",
    "models/props_trainstation/Ceiling_Arch001a.mdl",
    "models/props_trainstation/mount_connection001a.mdl",
    "models/props_trainstation/TrackSign02.mdl",
    "models/props_trainstation/TrackSign03.mdl",
    "models/props_trainstation/TrackSign07.mdl",
    "models/props_trainstation/TrackSign08.mdl",
    "models/props_trainstation/TrackSign09.mdl",
    "models/props_trainstation/TrackSign10.mdl",
    "models/props_trainstation/traincar_rack001.mdl",
    "models/props_trainstation/trainstation_clock001.mdl",
    "models/props_trainstation/trainstation_ornament002.mdl",
    "models/props_trainstation/trainstation_post001.mdl",
    "models/props_trainstation/trashcan_indoor001a.mdl",
    "models/props_vehicles/tire001a_tractor.mdl",
    "models/props_vehicles/tire001b_truck.mdl",
    "models/props_vehicles/tire001c_car.mdl",
    "models/props_vehicles/apc_tire001.mdl",
    "models/props_wasteland/barricade001a.mdl",
    "models/props_wasteland/barricade002a.mdl",
    "models/props_wasteland/cafeteria_bench001a.mdl",
    "models/props_wasteland/cafeteria_table001a.mdl",
    "models/props_wasteland/controlroom_desk001a.mdl",
    "models/props_wasteland/controlroom_filecabinet001a.mdl",
    "models/props_wasteland/controlroom_filecabinet002a.mdl",
    "models/props_wasteland/controlroom_storagecloset001a.mdl",
    "models/props_wasteland/gaspump001a.mdl",
    "models/props_wasteland/interior_fence001g.mdl",
    "models/props_wasteland/interior_fence002d.mdl",
    "models/props_wasteland/interior_fence002e.mdl",
    "models/props_wasteland/kitchen_counter001b.mdl",
    "models/props_wasteland/kitchen_counter001d.mdl",
    "models/props_wasteland/kitchen_shelf002a.mdl",
    "models/props_wasteland/kitchen_shelf001a.mdl",
    "models/props_wasteland/laundry_basket001.mdl",
    "models/props_wasteland/laundry_cart001.mdl",
    "models/props_wasteland/laundry_cart002.mdl",
    "models/props_wasteland/laundry_dryer002.mdl",
    "models/props_wasteland/laundry_washer001a.mdl",
    "models/props_wasteland/laundry_washer003.mdl",
    "models/props_wasteland/light_spotlight01_lamp.mdl",
    "models/props_wasteland/medbridge_post01.mdl",
    "models/props_wasteland/panel_leverHandle001a.mdl",
    "models/props_wasteland/prison_bedframe001b.mdl",
    "models/props_wasteland/prison_lamp001c.mdl",
    "models/props_wasteland/prison_shelf002a.mdl",
    "models/props_wasteland/wood_fence01a.mdl",
    "models/props_wasteland/wood_fence02a.mdl",
    "models/Gibs/HGIBS.mdl",
    "models/props_c17/BriefCase001a.mdl",
    "models/props_c17/cashregister01a.mdl",
    "models/props_c17/chair_kleiner03a.mdl",
    "models/props_c17/chair_stool01a.mdl",
    "models/props_c17/chair_office01a.mdl",
    "models/props_c17/clock01.mdl",
    "models/props_c17/computer01_keyboard.mdl",
    "models/props_c17/consolebox01a.mdl",
    "models/props_c17/consolebox03a.mdl",
    "models/props_c17/consolebox05a.mdl",
    "models/props_c17/doll01.mdl",
    "models/props_c17/Frame002a.mdl",
    "models/props_c17/metalPot001a.mdl",
    "models/props_c17/metalPot002a.mdl",
    "models/props_c17/playground_teetertoter_stan.mdl",
    "models/props_c17/playgroundTick-tack-toe_block01a.mdl",
    "models/props_c17/playgroundTick-tack-toe_post01.mdl",
    "models/props_c17/streetsign001c.mdl",
    "models/props_c17/streetsign002b.mdl",
    "models/props_c17/streetsign003b.mdl",
    "models/props_c17/streetsign004e.mdl",
    "models/props_c17/streetsign004f.mdl",
    "models/props_c17/streetsign005b.mdl",
    "models/props_c17/streetsign005c.mdl",
    "models/props_c17/streetsign005d.mdl",
    "models/props_c17/SuitCase001a.mdl",
    "models/props_c17/SuitCase_Passenger_Physics.mdl",
    "models/props_c17/tools_wrench01a.mdl",
    "models/props_c17/TrapPropeller_Engine.mdl",
    "models/props_c17/TrapPropeller_Lever.mdl",
    "models/props_c17/tv_monitor01.mdl",
    "models/props_combine/breenbust.mdl",
    "models/props_lab/reciever_cart.mdl",
    "models/props_lab/reciever01d.mdl",
    "models/props_lab/reciever01a.mdl",
    "models/props_lab/reciever01b.mdl",
    "models/props_lab/reciever01c.mdl",
    "models/props_lab/harddrive02.mdl",
    "models/props_lab/frame002a.mdl",
    "models/props_lab/clipboard.mdl",
    "models/props_lab/desklamp01.mdl",
    "models/props_lab/harddrive01.mdl",
    "models/props_lab/huladoll.mdl",
    "models/props_lab/monitor01a.mdl",
    "models/props_lab/monitor01b.mdl",
    "models/props_lab/monitor02.mdl",
    "models/props_lab/partsbin01.mdl",
    "models/props_lab/plotter.mdl",
    "models/props_trainstation/payphone001a.mdl",
    "models/props_vehicles/carparts_axel01a.mdl",
    "models/props_vehicles/carparts_muffler01a.mdl",
    "models/props_trainstation/traincar_seats001.mdl",
    "models/props_vehicles/carparts_wheel01a.mdl",
    "models/props_lab/cactus.mdl",
    "models/props/cs_assault/BarrelWarning.mdl",
    "models/props/cs_assault/camera.mdl",
    "models/props/cs_assault/ChainTrainStationSign.mdl",
    "models/props/cs_assault/ConsolePanelLoadingBay.mdl",
    "models/props/cs_assault/dryer_box.mdl",
    "models/props/cs_assault/duct.mdl",
    "models/props/cs_assault/FireHydrant.mdl",
    "models/props/cs_assault/Floodlight01.mdl",
    "models/props/cs_assault/light_shop2.mdl",
    "models/props/cs_assault/meter.mdl",
    "models/props/cs_assault/NoParking.mdl",
    "models/props/cs_assault/NoStopsSign.mdl",
    "models/props/cs_assault/pylon.mdl",
    "models/props/cs_assault/stoplight.mdl",
    "models/props/cs_assault/streetlight.mdl",
    "models/props/cs_assault/StreetSign02.mdl",
    "models/props/cs_assault/VentilationDuct01.mdl",
    "models/props/cs_assault/wall_vent.mdl",
    "models/props/cs_assault/wirepipe.mdl",
    "models/props/cs_assault/wirespout.mdl",
    "models/props/CS_militia/bar01.mdl",
    "models/props/CS_militia/barstool01.mdl",
    "models/props/CS_militia/bathroomwallhole01_wood_broken.mdl",
    "models/props/CS_militia/boxes_frontroom.mdl",
    "models/props/CS_militia/boxes_garage_lower.mdl",
    "models/props/CS_militia/caseofbeer01.mdl",
    "models/props/CS_militia/circularsaw01.mdl",
    "models/props/CS_militia/couch.mdl",
    "models/props/CS_militia/crate_extrasmallmill.mdl",
    "models/props/CS_militia/crate_stackmill.mdl",
    "models/props/CS_militia/dryer.mdl",
    "models/props/CS_militia/FenceWoodLog01_Short.mdl",
    "models/props/CS_militia/FenceWoodLog03_Long.mdl",
    "models/props/CS_militia/fertilizer.mdl",
    "models/props/CS_militia/food_stack.mdl",
    "models/props/CS_militia/furnace01.mdl",
    "models/props/CS_militia/gun_cabinet.mdl",
    "models/props/CS_militia/haybale_target.mdl",
    "models/props/CS_militia/haybale_target_02.mdl",
    "models/props/CS_militia/haybale_target_03.mdl",
    "models/props/CS_militia/ladderwood.mdl",
    "models/props/CS_militia/lightfixture01.mdl",
    "models/props/CS_militia/light_shop2.mdl",
    "models/props/CS_militia/logpile2.mdl",
    "models/props/CS_militia/mailbox01.mdl",
    "models/props/CS_militia/microwave01.mdl",
    "models/props/CS_militia/militiawindow01.mdl",
    "models/props/CS_militia/militiawindow02_breakable.mdl",
    "models/props/CS_militia/militiawindow02_breakable_frame.mdl",
    "models/props/CS_militia/newspaperstack01.mdl",
    "models/props/CS_militia/oldphone01.mdl",
    "models/props/CS_militia/paintbucket01.mdl",
    "models/props/CS_militia/refrigerator01.mdl",
    "models/props/CS_militia/reloadingpress01.mdl",
    "models/props/CS_militia/reload_scale.mdl",
    "models/props/CS_militia/sawhorse.mdl",
    "models/props/CS_militia/sheetrock_leaning.mdl",
    "models/props/CS_militia/shelves.mdl",
    "models/props/CS_militia/shelves_wood.mdl",
    "models/props/CS_militia/spotlight.mdl",
    "models/props/CS_militia/stove01.mdl",
    "models/props/CS_militia/table_kitchen.mdl",
    "models/props/CS_militia/table_shed.mdl",
    "models/props/CS_militia/television_console01.mdl",
    "models/props/CS_militia/toilet.mdl",
    "models/props/CS_militia/urine_trough.mdl",
    "models/props/CS_militia/wndw01.mdl",
    "models/props/CS_militia/wood_bench.mdl",
    "models/props/CS_militia/wood_table.mdl",
    "models/props/cs_office/Bookshelf1.mdl",
    "models/props/cs_office/coffee_mug.mdl",
    "models/props/cs_office/coffee_mug2.mdl",
    "models/props/cs_office/coffee_mug3.mdl",
    "models/props/cs_office/computer.mdl",
    "models/props/cs_office/computer_caseB.mdl",
    "models/props/cs_office/computer_keyboard.mdl",
    "models/props/cs_office/computer_monitor.mdl",
    "models/props/cs_office/computer_mouse.mdl",
    "models/props/cs_office/Crates_indoor.mdl",
    "models/props/cs_office/Crates_outdoor.mdl",
    "models/props/cs_office/Exit_ceiling.mdl",
    "models/props/cs_office/file_box.mdl",
    "models/props/cs_office/file_cabinet1.mdl",
    "models/props/cs_office/file_cabinet1_group.mdl",
    "models/props/cs_office/file_cabinet2.mdl",
    "models/props/cs_office/file_cabinet3.mdl",
    "models/props/cs_office/Fire_Extinguisher.mdl",
    "models/props/cs_office/Light_security.mdl",
    "models/props/cs_office/offcertificatea.mdl",
    "models/props/cs_office/offcorkboarda.mdl",
    "models/props/cs_office/offinspa.mdl",
    "models/props/cs_office/offinspb.mdl",
    "models/props/cs_office/offinspc.mdl",
    "models/props/cs_office/offinspd.mdl",
    "models/props/cs_office/offpaintinga.mdl",
    "models/props/cs_office/offpaintingb.mdl",
    "models/props/cs_office/offpaintingd.mdl",
    "models/props/cs_office/offpaintinge.mdl",
    "models/props/cs_office/offpaintingf.mdl",
    "models/props/cs_office/sofa.mdl",
    "models/props/cs_office/sofa_chair.mdl",
    "models/props/cs_office/Table_coffee.mdl",
    "models/props/cs_office/Table_meeting.mdl",
    "models/props/cs_office/trash_can.mdl",
    "models/props/de_nuke/light_red1.mdl",
    "models/unconid/pc_models/monitors/lcd_super_ultrawide.mdl",
    "models/unconid/pc_models/monitors/lcd_ultrawide_curved.mdl",
    "models/unconid/pc_models/monitors/lcd_ultrawide_nc.mdl",
    "models/unconid/pc_models/monitors/lcd_acer_16x9.mdl",
    "models/unconid/pc_models/monitors/lcd_lg_4x3.mdl",
}

-- ===== ПАНЕЛЬ ПРОПОВ =====
-- Используем ContentContainer (как стандартный спавн-меню), чтобы:
--   • иконки автоматически выкладывались сеткой по ширине родителя,
--   • PerformLayout родителя корректно пересчитывал размеры,
--   • не было «выезда» иконок за границы вкладки из-за неправильного парента.
local PANEL = {}

function PANEL:Init()
    self.PanelList = vgui.Create("DScrollPanel", self)
    self.PanelList:Dock(FILL)

    -- DListLayout: вертикальный стек, корректно растягивает детей на полную
    -- ширину и уважает Dock(TOP). DIconLayout сюда НЕ подходит — он кладёт
    -- категории в сетку и не даёт им ширину, из-за чего внутренние иконки
    -- не переносятся на новые строки.
    self.Container = vgui.Create("DListLayout", self.PanelList)
    self.Container:Dock(FILL)

    self:BuildList()
end

function PANEL:BuildList()
    self.Container:Clear()

    local categories = {
        {"1) Конструкции",    Props_Constructions},
        {"2) Пластины, кубы", Props_Plates},
        {"3) Декор",          Props_Decor},
    }

    for i, cat in ipairs(categories) do
        local catName, models = cat[1], cat[2]

        local Category = self.Container:Add("DCollapsibleCategory")
        Category:SetExpanded(i == 1) -- первая категория развёрнута по умолчанию
        Category:SetLabel(catName)
        Category:SetCookieName("ZCityProps." .. catName)
        Category:Dock(TOP)

        local Content = vgui.Create("DIconLayout", Category)
        Content:SetSpaceX(2)
        Content:SetSpaceY(2)
        Content:SetBorder(4)
        Category:SetContents(Content)
        Category.ZCityContent = Content

        for _, model in ipairs(models) do
            local Icon = Content:Add("SpawnIcon")
            Icon:SetSize(64, 64)
            Icon:SetModel(model)
            Icon.DoClick = function()
                RunConsoleCommand("gm_spawn", model)
            end
        end

        Content:InvalidateLayout(true)
        Content:SizeToChildren(false, true)
    end

    self.Container:InvalidateLayout(true)
end

function PANEL:PerformLayout(w, h)
    if IsValid(self.PanelList) then
        self.PanelList:SetSize(w, h)
    end

    if IsValid(self.Container) then
        for _, category in ipairs(self.Container:GetChildren()) do
            local content = category.ZCityContent
            if IsValid(content) then
                local width = math.max(0, category:GetWide() - 8)
                content:SetWide(width)
                content:InvalidateLayout(true)
                content:SizeToChildren(false, true)
                category:InvalidateLayout(true)
            end
        end
        self.Container:InvalidateLayout(true)
    end
end

local CreationSheet = vgui.RegisterTable(PANEL, "Panel")

spawnmenu.AddCreationTab("Разрешенные пропы", function()
    return vgui.CreateFromTable(CreationSheet)
end, "icon16/application_view_tile.png", 4)

-- ===== ФИЛЬТРАЦИЯ ВКЛАДОК СОЗДАНИЯ =====
-- 1. Собираем все лишние items (вкладка + panel контента).
-- 2. ПРИНУДИТЕЛЬНО переключаемся на «Разрешенные пропы» ДО закрытия других —
--    иначе DPropertySheet может оставить активной вкладку «Дубликаты»,
--    и её panel будет накладываться поверх наших пропов.
-- 3. Для каждого лишнего item: panel:SetParent(nil) + SetVisible(false) —
--    это убирает контент-panel из рендера и не ломает ContentSearch
--    (self.Search не зануляется, как было бы при :Remove()).
-- 4. CloseTab(tab, false) — удаляет только кнопку таба, panel мы уже
--    отвязали от родителя выручную.
local function FilterCreationTabs()
    if not IsValid(g_SpawnMenu) then return end
    if not IsValid(g_SpawnMenu.CreateMenu) then return end

    local sheet = g_SpawnMenu.CreateMenu

    -- Принудительно делаем нашу вкладку активной, чтобы её panel вышел наверх
    if sheet.SwitchToName then sheet:SwitchToName("Разрешенные пропы") end

    local toRemove = {}
    for _, v in pairs(sheet.Items) do
        if IsValid(v.Tab) and v.Tab:GetText() != "Разрешенные пропы" then
            table.insert(toRemove, v)
        end
    end

    for _, item in ipairs(toRemove) do
        -- Сначала выкидываем panel контента из дерева — чтобы он не рисовался
        -- поверх нашей вкладки. Не используем :Remove() из-за ContentSearch.
        if IsValid(item.Panel) then
            item.Panel:SetVisible(false)
            item.Panel:SetParent(nil)
        end
        if IsValid(item.Tab) then
            sheet:CloseTab(item.Tab, false)
        end
    end

    -- Ещё раз, на всякий случай — после CloseTab активная вкладка могла
    -- сброситься на первую попавшуюся.
    if sheet.SwitchToName then sheet:SwitchToName("Разрешенные пропы") end
    sheet:InvalidateLayout(true)
end

-- ===== ФИЛЬТРАЦИЯ ИНСТРУМЕНТОВ =====
-- Основной подход: перехватываем spawnmenu.AddToolMenuOption при создании.
-- Это надёжнее DOM-обхода: работает в любой версии GMod, не зависит
-- от структуры VGUI (DButton vs DTree_Node) и от момента открытия меню.

if spawnmenu and spawnmenu.AddToolMenuOption then
    local _origAddTool = spawnmenu.AddToolMenuOption
    spawnmenu.AddToolMenuOption = function(tab, category, class, name, icon, ...)
        -- Фильтруем только если игрок с доступом — для остальных всё как обычно
        if HasAccess() and not ALLOWED_TOOLS[class] then return end
        return _origAddTool(tab, category, class, name, icon, ...)
    end
end

-- Запасной DOM-обход: скрывает инструменты уже добавленные до нашего override
-- (например в предыдущей сессии / reload). Поддерживает DButton и DTree_Node.
local function FilterToolPanel()
    if not IsValid(g_SpawnMenu) then return end

    local totalFound = 0

    local function Walk(panel, depth)
        if not IsValid(panel) or depth > 30 then return end
        local mode = panel.Mode or panel.ToolMode or panel.m_Mode
        if mode ~= nil then
            panel:SetVisible(ALLOWED_TOOLS[mode] == true)
            totalFound = totalFound + 1
            return
        end
        for _, child in ipairs(panel:GetChildren()) do
            Walk(child, depth + 1)
        end
    end
    Walk(g_SpawnMenu, 0)

    if totalFound == 0 then return end -- ничего не нашли — override сработал раньше

    print("[ZCity Tools] DOM-фильтр: скрыто/показано " .. totalFound .. " инструментов")

    -- Скрываем пустые DCollapsibleCategory
    local function AnyVisible(panel, depth)
        if not IsValid(panel) or depth > 15 then return false end
        local mode = panel.Mode or panel.ToolMode or panel.m_Mode
        if mode ~= nil then return panel:IsVisible() end
        for _, child in ipairs(panel:GetChildren()) do
            if AnyVisible(child, depth + 1) then return true end
        end
        return false
    end
    local function HideEmpty(panel, depth)
        if not IsValid(panel) or depth > 30 then return end
        if panel:GetClassName() == "DCollapsibleCategory" then
            panel:SetVisible(AnyVisible(panel, 0))
            return
        end
        for _, child in ipairs(panel:GetChildren()) do
            HideEmpty(child, depth + 1)
        end
    end
    HideEmpty(g_SpawnMenu, 0)
    g_SpawnMenu:InvalidateLayout(true)
end

hook.Add("SpawnMenuOpen", "zcity_spawnmenu_filter", function()
    if not HasAccess() then return end
    timer.Simple(0.5, function()
        if not IsValid(g_SpawnMenu) then return end
        FilterCreationTabs()
        FilterToolPanel()
    end)
end)

-- Повторная фильтрация при перезагрузке списка инструментов
hook.Add("PostReloadToolsMenu", "zcity_tools_filter", function()
    if not HasAccess() then return end
    timer.Simple(0.5, FilterToolPanel)
end)
