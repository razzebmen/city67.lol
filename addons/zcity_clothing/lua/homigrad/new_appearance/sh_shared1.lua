hg.Appearance = hg.Appearance or {}
hg.PointShop = hg.PointShop or {}
local PLUGIN = hg.PointShop
PLUGIN.Items = PLUGIN.Items or {}

local allowed = {
    ' ',
    'а', 'б', 'в', 'г', 'д', 'е', 'ё', 'ж', 'з', 'и', 'й', 'к', 'л', 'м', 'н', 'о', 'п', 'р', 'с', 'т', 'у', 'ф', 'х', 'ц', 'ч', 'ш', 'щ', 'ъ', 'ы', 'ь', 'э', 'ю', 'я',
    'А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ё', 'Ж', 'З', 'И', 'Й', 'К', 'Л', 'М', 'Н', 'О', 'П', 'Р', 'С', 'Т', 'У', 'Ф', 'Х', 'Ц', 'Ч', 'Ш', 'Щ', 'Ъ', 'Ы', 'Ь', 'Э', 'Ю', 'Я',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
}

local function IsInvalidName(name)
    local trimmedName = string.Trim(name)
    if trimmedName == "" then return true end
    if #trimmedName < 2 then return true end
    if utf8.len(name) > 25 then return true end
    local symblos = utf8.len(name)
    for k = 1, symblos do
        if not table.HasValue(allowed, utf8.GetChar(name, k)) then return true end
    end
    local ret = hook.Run("ZB_IsInvalidName", name)
    if ret ~= nil then return ret end
    return false
end
hg.Appearance.IsInvalidName = IsInvalidName

local function GenerateRandomName(iSex)
    local sex = iSex or math.random(1, 2)
    local randomName = hg.Appearance.RandomNames[sex][math.random(1, #hg.Appearance.RandomNames[sex])]
    return randomName
end
hg.Appearance.GenerateRandomName = GenerateRandomName

local access = {}

local hg_appearance_access_for_all = ConVarExists("hg_appearance_access_for_all") and GetConVar("hg_appearance_access_for_all") or CreateConVar("hg_appearance_access_for_all", 1, {FCVAR_REPLICATED, FCVAR_NEVER_AS_STRING, FCVAR_ARCHIVE}, "Toggle free items in appearance for everyone", 0, 1)

if SERVER then
    cvars.AddChangeCallback("hg_appearance_access_for_all", function(convar_name, value_old, value_new) SetGlobalBool("hg_appearance_access_for_all", hg_appearance_access_for_all:GetBool()) end)
    SetGlobalBool("hg_appearance_access_for_all", hg_appearance_access_for_all:GetBool())
end

local function GetAccessToAll(ply)
    return GetGlobalBool("hg_appearance_access_for_all") or ply:IsSuperAdmin() or ply:IsAdmin() or access[ply:SteamID()]
end
hg.Appearance.GetAccessToAll = GetAccessToAll

local PlayerModels = {
    [1] = {},
    [2] = {}
}

local function AppAddModel(strName, strMdl, bFemale, tSubmaterialSlots)
    PlayerModels[bFemale and 2 or 1][strName] = {
        mdl = strMdl,
        submatSlots = tSubmaterialSlots,
        sex = bFemale
    }
end

AppAddModel("Male 01", "models/zcityadodser/m/male_01.mdl", false, {
    main = "models/humans/male/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Male 02", "models/zcityadodser/m/male_02.mdl", false, {
    main = "models/humans/male/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Male 03", "models/zcityadodser/m/male_03.mdl", false, {
    main = "models/humans/male/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Male 04", "models/zcityadodser/m/male_04.mdl", false, {
    main = "models/humans/male/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Male 05", "models/zcityadodser/m/male_05.mdl", false, {
    main = "models/humans/male/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Male 06", "models/zcityadodser/m/male_06.mdl", false, {
    main = "models/humans/male/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Male 07", "models/zcityadodser/m/male_07.mdl", false, {
    main = "models/humans/male/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Male 08", "models/zcityadodser/m/male_08.mdl", false, {
    main = "models/humans/male/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Male 09", "models/zcityadodser/m/male_09.mdl", false, {
    main = "models/humans/male/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})

AppAddModel("Female 01", "models/zcityadodser/f/female_01.mdl", true, {
    main = "models/humans/female/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Female 02", "models/zcityadodser/f/female_02.mdl", true, {
    main = "models/humans/female/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Female 03", "models/zcityadodser/f/female_03.mdl", true, {
    main = "models/humans/female/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Female 04", "models/zcityadodser/f/female_04.mdl", true, {
    main = "models/humans/female/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Female 05", "models/zcityadodser/f/female_07.mdl", true, {
    main = "models/humans/female/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})
AppAddModel("Female 06", "models/zcityadodser/f/female_06.mdl", true, {
    main = "models/humans/female/group01/players_sheet",
    pants = "distac/gloves/pants",
    boots = "distac/gloves/cross",
    hands = "distac/gloves/hands"
})

hg.Appearance.PlayerModels = PlayerModels

hg.Appearance.FuckYouModels = {{}, {}}
for name, tbl in pairs(hg.Appearance.PlayerModels[1]) do
    hg.Appearance.FuckYouModels[1][tbl.mdl] = tbl
end
for name, tbl in pairs(hg.Appearance.PlayerModels[2]) do
    hg.Appearance.FuckYouModels[2][tbl.mdl] = tbl
end

hg.Appearance.Clothes = {}
hg.Appearance.Clothes[1] = {
    normal          = "models/humans/male/group01/normal",
    formal          = "models/humans/male/group01/formal",
    plaid           = "models/humans/male/group01/plaid",
    striped         = "models/humans/male/group01/striped",
    young           = "models/humans/male/group01/young",
    cold            = "models/humans/male/group01/cold",
    casual          = "models/humans/male/group01/casual",
    sweater_xmas    = "models/humans/male/group01/sweater",
    worker          = "models/humans/male/group01/worker",
    bomber_jacket1  = "models/humans/male/group01/bomberjacket1",
    camo_variant2   = "models/humans/male/group01/camo2",
    pilot_jacket    = "models/humans/male/group01/pilotjacket",
    tactical_outfit = "models/humans/male/group01/tacticalgop",     
    hussar_jacket   = "models/humans/male/group01/hussar",
    Tshirt3         = "models/humans/male/group01/bersk",           
    leather_jacket  = "models/humans/male/group01/jacket",
    Tshirt1         = "models/humans/male/group01/promised",        
    Tshirt2         = "models/humans/male/group01/simon",
    alpha_bomber    = "models/humans/male/group01/alphaindustry",
    alpha_hoodie    = "models/humans/male/group01/alphahoodie",
    lonsdale_hoodie = "models/humans/male/group01/LondsdaleHoodie", 
    golden_adidas   = "models/humans/male/group01/goldenadidas",
    wagner_group    = "models/humans/male/group01/wagner",
    russian_army    = "models/humans/male/group01/russianarmy",
	Hello_Kitty     = "models/humans/male/group01/hello_kitty",
	Office_Worker   = "models/humans/male/group01/OfficeWorker",
	Security_Officer= "models/humans/male/group01/Security_Officer",
	Zcity_Hoodie    = "models/humans/male/group01/zcityhoodie",
	Flecktarn       = "models/humans/male/group01/flecktarn",
	Hawaiian_Shirt  = "models/humans/male/group01/tommy", 
	Hawaiian_Shirt2 = "models/humans/male/group01/Hawaiian1", 
	Sadsalat        = "models/humans/male/group01/sadsalat", 
	Army_Shirt      = "models/humans/male/group01/armyshirt", 
	Lambda          = "models/humans/male/group01/lambda",
	bean            = "models/humans/male/group01/bean",
	y2k             = "models/humans/male/group01/y2k",
	medic1          = "models/humans/male/group01/medic1",
	antisocial          = "models/humans/male/group01/antisocial",
	peacefulhooligan          = "models/humans/male/group01/peacefulhooligan",	
	polska          = "models/humans/male/group01/polska",	
}
hg.Appearance.Clothes[2] = {
    normal = "models/humans/female/group01/normal",
    formal = "models/humans/female/group01/formal",
    plaid = "models/humans/female/group01/plaid",
    striped = "models/humans/female/group01/striped",
    young = "models/humans/female/group01/young",
    cold = "models/humans/female/group01/cold",
    casual = "models/humans/female/group01/casual",
    sweater_xmas = "models/humans/female/group01/sweater",
	adidas_tracksuit = "models/humans/female/group01/adidas",
	Tshirt1 = "models/humans/female/group01/flowers",
	Tshirt2 = "models/humans/female/group01/skullshirt",
	Tshirt3 = "models/humans/female/group01/skeletal",
	Tshirt4 = "models/humans/female/group01/redskull",
	Hawaiian_Shirt1 = "models/humans/female/group01/Hawaiian1",
	swiss   = "models/humans/female/group01/swiss",
}

hg.Appearance.ClothesDesc = {
    normal = { desc = "Garry's Mod default citizen outfit" },
    formal = { desc = "from orignial Jack's Homicide gamemode.\nForever." },
    plaid = { desc = "from orignial Jack's Homicide gamemode.\nForever." },
    striped = { desc = "from orignial Jack's Homicide gamemode.\nForever." },
    young = { desc = "from orignial Jack's Homicide gamemode.\nForever." },
    cold = { desc = "from orignial Jack's Homicide gamemode.\nForever." },
    casual = { desc = "from orignial Jack's Homicide gamemode.\nForever." },
    sweater_xmas = {
        desc = "by Wontairr from steam workshop\nRMB to open link",
        link = "https://steamcommunity.com/sharedfiles/filedetails/?id=3621630161"
    },
    worker = {
        desc = "by Chervo93 from steam workshop\nRMB to open link",
        link = "https://steamcommunity.com/sharedfiles/filedetails/?id=3540506879"
    },
}

hg.Appearance.FacemapsSlots = hg.Appearance.FacemapsSlots or {}
hg.Appearance.FacemapsModels = hg.Appearance.FacemapsModels or {}

local function AddFacemap(matOverride, strName, matMaterial, model)
    hg.Appearance.FacemapsSlots[matOverride] = hg.Appearance.FacemapsSlots[matOverride] or {}
    local tbl = hg.Appearance.FacemapsSlots[matOverride]
    tbl[strName] = matMaterial
    if model then hg.Appearance.FacemapsModels[model] = matOverride end
end

local female01facemap = "models/humans/female/group01/joey_facemap"
AddFacemap(female01facemap, "Default", "", "models/zcityadodser/f/female_01.mdl")
AddFacemap(female01facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/joey_facemap")
for i = 2, 6 do
    AddFacemap(female01facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/joey_facemap" .. i)
end

local female02facemap = "models/humans/female/group01/kanisha_cylmap"
AddFacemap(female02facemap, "Default", "", "models/zcityadodser/f/female_02.mdl")
AddFacemap(female02facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/kanisha_cylmap")
for i = 2, 6 do
    AddFacemap(female02facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/kanisha_cylmap" .. i)
end

local female03facemap = "models/humans/female/group01/kim_facemap"
AddFacemap(female03facemap, "Default", "", "models/zcityadodser/f/female_03.mdl")
AddFacemap(female03facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/kim_facemap")
AddFacemap(female03facemap, "Face 5", "models/bloo_ltcom_zel/citizens/facemaps/kim_facemap6")
for i = 2, 4 do
    AddFacemap(female03facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/kim_facemap" .. i)
end

local female04facemap = "models/humans/female/group01/chau_facemap"
AddFacemap(female04facemap, "Default", "", "models/zcityadodser/f/female_04.mdl")
AddFacemap(female04facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/chau_facemap")
for i = 2, 6 do
    AddFacemap(female04facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/chau_facemap" .. i)
end

local female05facemap = "models/humans/female/group01/miranda_facemap"
AddFacemap(female05facemap, "Default", "", "models/zcityadodser/f/female_07.mdl")
AddFacemap(female05facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/miranda_facemap")
for i = 2, 6 do
    AddFacemap(female05facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/miranda_facemap" .. i)
end

local female06facemap = "models/humans/female/group01/lake_facemap"
AddFacemap(female06facemap, "Default", "", "models/zcityadodser/f/female_06.mdl")
AddFacemap(female06facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/lake_facemap")
for i = 2, 6 do
    AddFacemap(female06facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/lake_facemap" .. i)
end

local male01facemap = "models/humans/male/group01/van_facemap"
AddFacemap(male01facemap, "Default", "", "models/zcityadodser/m/male_01.mdl")
AddFacemap(male01facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/van_facemap")
for i = 2, 9 do
    AddFacemap(male01facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/van_facemap" .. i)
end

local male02facemap = "models/humans/male/group01/ted_facemap"
AddFacemap(male02facemap, "Default", "", "models/zcityadodser/m/male_02.mdl")
AddFacemap(male02facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/ted_facemap")
for i = 2, 9 do
    AddFacemap(male02facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/ted_facemap" .. i)
end

local male03facemap = "models/humans/male/group01/joe_facemap"
AddFacemap(male03facemap, "Default", "", "models/zcityadodser/m/male_03.mdl")
AddFacemap(male03facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/joe_facemap")
for i = 2, 9 do
    AddFacemap(male03facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/joe_facemap" .. i)
end

local male04facemap = "models/humans/male/group01/eric_facemap"
AddFacemap(male04facemap, "Default", "", "models/zcityadodser/m/male_04.mdl")
AddFacemap(male04facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/eric_facemap")
for i = 2, 9 do
    AddFacemap(male04facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/eric_facemap" .. i)
end

local male05facemap = "models/humans/male/group01/art_facemap"
AddFacemap(male05facemap, "Default", "", "models/zcityadodser/m/male_05.mdl")
AddFacemap(male05facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/art_facemap")
for i = 2, 9 do
    AddFacemap(male05facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/art_facemap" .. i)
end

local male06facemap = "models/humans/male/group01/sandro_facemap"
AddFacemap(male06facemap, "Default", "", "models/zcityadodser/m/male_06.mdl")
AddFacemap(male06facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/sandro_facemap")
for i = 2, 10 do
    AddFacemap(male06facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/sandro_facemap" .. i)
end

local male07facemap = "models/humans/male/group01/mike_facemap"
AddFacemap(male07facemap, "Default", "", "models/zcityadodser/m/male_07.mdl")
AddFacemap(male07facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/mike_facemap")
for i = 2, 8 do
    AddFacemap(male07facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/mike_facemap" .. i)
end

local male08facemap = "models/humans/male/group01/vance_facemap"
AddFacemap(male08facemap, "Default", "", "models/zcityadodser/m/male_08.mdl")
AddFacemap(male08facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/vance_facemap")
for i = 2, 9 do
    AddFacemap(male08facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/vance_facemap" .. i)
end

local male09facemap = "models/humans/male/group01/erdim_cylmap"
AddFacemap(male09facemap, "Default", "", "models/zcityadodser/m/male_09.mdl")
AddFacemap(male09facemap, "Face 1", "models/bloo_ltcom_zel/citizens/facemaps/erdim_facemap")
for i = 2, 11 do
    AddFacemap(male09facemap, "Face " .. i, "models/bloo_ltcom_zel/citizens/facemaps/erdim_facemap" .. i)
end

hg.Appearance.Bodygroups = hg.Appearance.Bodygroups or {
    TORSO = { [1] = {}, [2] = {} },
    LEGS = { [1] = {}, [2] = {} },
    HANDS = {
        [1] = { ["None"] = {"hands", false} },
        [2] = { ["None"] = {"hands", false} },
    },
    gloves2 = { [1] = {}, [2] = {} },
}

local function AppAddBodygroup(strBodyGroup, strName, strStringID, bFemale, bPointShop, bDonateOnly, fCost, psModel, psBodygroups, psSubmats, psStrNameOveride)
    local pointShopID = "Standard_BodyGroups_" .. (psStrNameOveride or strName)
    hg.Appearance.Bodygroups[strBodyGroup] = hg.Appearance.Bodygroups[strBodyGroup] or {}
    hg.Appearance.Bodygroups[strBodyGroup][bFemale and 2 or 1] = hg.Appearance.Bodygroups[strBodyGroup][bFemale and 2 or 1] or {}
    hg.Appearance.Bodygroups[strBodyGroup][bFemale and 2 or 1][strName] = {
        strStringID,
        bPointShop,
        ID = pointShopID
    }
    PLUGIN:CreateItem(pointShopID, string.NiceName(strName), psModel or "models/zcity/gloves/degloves.mdl", psBodygroups, 0, Vector(0, 0, 0), fCost, bDonateOnly, psSubmats or {})
end

local function AddBodygroupsFunc()
    AppAddBodygroup("HANDS", "Gloves", "reggloves_FIN_M", false, true, true, 300, "models/zcity/gloves/degloves.mdl", 0)
    AppAddBodygroup("HANDS", "Gloves", "reggloves_FIN_F", true, true, true, 300, "models/zcity/gloves/degloves.mdl", 0)
    AppAddBodygroup("HANDS", "Gloves fingerless", "reggloves_outFIN_M", false, true, true, 300, "models/zcity/gloves/degloves.mdl", 1)
    AppAddBodygroup("HANDS", "Gloves fingerless", "reggloves_outFIN_F", true, true, true, 300, "models/zcity/gloves/degloves.mdl", 1)
    AppAddBodygroup("HANDS", "Skilet", "sceletgloves_FIN_M", false, true, true, 399, "models/zcity/gloves/degloves.mdl", 0, { [0] = "distac/gloves/sceletgloves" })
    AppAddBodygroup("HANDS", "Skilet", "sceletgloves_FIN_F", true, true, true, 399, "models/zcity/gloves/degloves.mdl", 0, { [0] = "distac/gloves/sceletgloves" })
    AppAddBodygroup("HANDS", "Skilet fingerless", "sceletgloves_outFIN_M", false, true, true, 399, "models/zcity/gloves/degloves.mdl", 1, { [0] = "distac/gloves/sceletgloves" })
    AppAddBodygroup("HANDS", "Skilet fingerless", "sceletgloves_outFIN_F", true, true, true, 399, "models/zcity/gloves/degloves.mdl", 1, { [0] = "distac/gloves/sceletgloves" })
    AppAddBodygroup("HANDS", "Winter", "wingloves_FIN_M", false, true, true, 300, "models/zcity/gloves/degloves.mdl", 2, nil, "Bikers")
    AppAddBodygroup("HANDS", "Winter", "wingloves_FIN_F", true, true, true, 300, "models/zcity/gloves/degloves.mdl", 2, nil, "Bikers")
    AppAddBodygroup("HANDS", "Winter fingerless", "wingloves_outFIN_M", false, true, true, 300, "models/zcity/gloves/degloves.mdl", 3, nil, "Bikers fingerless")
    AppAddBodygroup("HANDS", "Winter fingerless", "wingloves_outFIN_F", true, true, true, 300, "models/zcity/gloves/degloves.mdl", 3, nil, "Bikers fingerless")
    AppAddBodygroup("HANDS", "Bikers gloves", "biker_gloves_M", false, true, true, 300, "models/zcity/gloves/degloves.mdl", 5)
    AppAddBodygroup("HANDS", "Bikers gloves", "biker_gloves_F", true, true, true, 300, "models/zcity/gloves/degloves.mdl", 5)
    AppAddBodygroup("HANDS", "Bikers wool", "bikerwool_gloves_M", false, true, true, 399, "models/zcity/gloves/degloves.mdl", 6, nil)
    AppAddBodygroup("HANDS", "Bikers wool", "bikerwool_gloves_F", true, true, true, 399, "models/zcity/gloves/degloves.mdl", 6, nil)
    AppAddBodygroup("HANDS", "Wool fingerless", "wool_glove_M", false, true, true, 300, "models/zcity/gloves/degloves.mdl", 7, nil)
    AppAddBodygroup("HANDS", "Wool fingerless", "wool_gloves_F", true, true, true, 300, "models/zcity/gloves/degloves.mdl", 7, nil)
    AppAddBodygroup("HANDS", "Mitten wool", "mittenwool_M", false, true, true, 300, "models/zcity/gloves/degloves.mdl", 8, nil)
    AppAddBodygroup("HANDS", "Mitten wool", "mittenwool_F", true, true, true, 300, "models/zcity/gloves/degloves.mdl", 8, nil)

    AppAddBodygroup("TORSO", "Standard Top", "male_standart_top.smd", false, false, false, 0, nil, 0)
    AppAddBodygroup("TORSO", "Wide Top", "male_standart_top_wide.smd", false, false, false, 0, nil, 0)
    AppAddBodygroup("TORSO", "Wide More Top", "male_standart_top_wide_more.smd", false, false, false, 0, nil, 0)
    AppAddBodygroup("TORSO", "T-Shirt", "male_standart_tshirt.smd", false, false, false, 0, nil, 0)
	AppAddBodygroup("TORSO", "Closed Collar", "male_standart_closed_collar.smd", false, false, false, 0, nil, 0)
    AppAddBodygroup("HANDS", "T-Shirt Hands", "handsfortshirt", false, false, false, 0, nil, 0)
    AppAddBodygroup("HANDS", "Robotic Hand", "robotichands", false, false, false, 0, nil, 0)
	AppAddBodygroup("HANDS", "Medical Gloves", "medical_gloves", false, false, false, 0, nil, 0)
	AppAddBodygroup("TORSO", "Odessa Jacket", "male_odessa_jacket.smd", false, false, false, 0, nil, 0)
	AppAddBodygroup("TORSO", "Robotic Arm", "male_robotic_arm.smd", false, false, false, 0, nil, 0)

    AppAddBodygroup("LEGS", "Standard Bottom", "male_reference_bottom.smd", false, false, false, 0, nil, 0)
    AppAddBodygroup("LEGS", "Wide Bottom", "male_reference_wide_bottom.smd", false, false, false, 0, nil, 0)
    AppAddBodygroup("LEGS", "Boots", "male_reference_boots.smd", false, false, false, 0, nil, 0)
    AppAddBodygroup("LEGS", "Shorts", "male_reference_bottom_shorts.smd", false, false, false, 0, nil, 0)
    AppAddBodygroup("LEGS", "Boots Wider", "male_reference_boots_wider.smd", false, false, false, 0, nil, 0)

    AppAddBodygroup("TORSO", "Standard Top", "female_standart_top.smd", true, false, false, 0, nil, 0)
    AppAddBodygroup("TORSO", "Wide Top", "female_standart_top_wide.smd", true, false, false, 0, nil, 0)
    AppAddBodygroup("TORSO", "Wide More Top", "female_standart_top_wide_more.smd", true, false, false, 0, nil, 0)
    AppAddBodygroup("TORSO", "Mossman Jacket", "female_mossman_jacket.smd", true, false, false, 0, nil, 0)

    AppAddBodygroup("LEGS", "Standard Bottom", "female_reference_bottom.smd", true, false, false, 0, nil, 0)
    AppAddBodygroup("LEGS", "Wide Bottom", "female_reference_wide_bottom.smd", true, false, false, 0, nil, 0)
    AppAddBodygroup("LEGS", "Boots", "female_reference_boots.smd", true, false, false, 0, nil, 0)
end
hook.Add("ZPointshopLoaded", "AddBodygroups", AddBodygroupsFunc)

hg.Appearance.SkeletonAppearanceTable = {
    AModel = "Male 07",
    AClothes = { main = "normal" },
    AName = "John Z-City",
    AColor = Color(180, 0, 0),
    AAttachments = {},
    ABodygroups = {},
    AFacemap = "Default"
}

function hg.Appearance.GetRandomAppearance()
    local randomAppearance = table.Copy(hg.Appearance.SkeletonAppearanceTable)
    local iSex = math.random(1, 2)
    local tMdl, str = table.Random(PlayerModels[iSex])
    randomAppearance.AModel = str
    _, str = table.Random(hg.Appearance.Clothes[iSex])
    randomAppearance.AClothes = {
        main = str,
        pants = str,
        boots = str
    }
    randomAppearance.AName = GenerateRandomName(iSex)
    randomAppearance.AColor = ColorRand(false)
    for i = 1, 1 do
        local data, k = table.Random(hg.Accessories or {})
        for ii, name in ipairs(randomAppearance.AAttachments) do
            if hg.Accessories[name] and hg.Accessories[name].placement == data.placement then k = "none" end
        end
        if data.disallowinappearance then k = "none" end
        randomAppearance.AAttachments[i] = k
    end
    local _, facemap = table.Random(hg.Appearance.FacemapsSlots[hg.Appearance.FacemapsModels[tMdl.mdl]] or {})
    randomAppearance.AFacemap = facemap
    return randomAppearance
end

hg.Appearance.ValidateFunctions = {
    AModel = function(str)
        if not isstring(str) then return false end
        if not PlayerModels[1][str] and not PlayerModels[2][str] then return false end
        return true
    end,
    AClothes = function(tbl)
        if not istable(tbl) then return false end
        if table.Count(tbl) > 3 then return false end
        return true
    end,
    AName = function(str)
        if not isstring(str) then return false end
        return not IsInvalidName(str)
    end,
    AColor = function(clr)
        return true
    end,
    AAttachments = function(tbl)
        if not istable(tbl) then return false end
        if table.Count(tbl) > 3 then return false, "Too many" end
        local occupatedSlots = {}
        for k, v in ipairs(tbl) do
            if not hg.Accessories[v] then continue end
            if occupatedSlots[hg.Accessories[v].placement] then
                tbl[k] = ""
                continue
            end
            if hg.Accessories[v].placement then occupatedSlots[hg.Accessories[v].placement] = true end
        end
        return true
    end,
    ABodygroups = function(tbl)
        if not istable(tbl) then return false end
        if table.Count(tbl) > 3 then return false end
        return true
    end,
    AFacemap = function(str) if not isstring(str) then return false end end
}

local function AppearanceValidater(tblAppearance)
    local VaildFuncs = hg.Appearance.ValidateFunctions
    local bValidAModel = VaildFuncs.AModel(tblAppearance.AModel)
    local bValidAClothes = VaildFuncs.AClothes(tblAppearance.AClothes)
    local bValidAName = VaildFuncs.AName(tblAppearance.AName)
    local bValidAColor = VaildFuncs.AColor(tblAppearance.AColor)
    local bValidAAttachments = VaildFuncs.AAttachments(tblAppearance.AAttachments)
    if bValidAModel and bValidAClothes and bValidAName and bValidAColor and bValidAAttachments then return true end
    return false
end
hg.Appearance.AppearanceValidater = AppearanceValidater

function ThatPlyIsFemale(ply)
    ply.CahceModel = ply.CahceModel or ""
    if ply.CahceModel == ply:GetModel() then return ply.bSex end
    local tSubModels = ply:GetSubModels()
    if not tSubModels then return false end
    ply.CahceModel = ply:GetModel()
    for i = 1, #tSubModels do
        local name = tSubModels[i]["name"]
        if name == "models/m_anm.mdl" then
            ply.bSex = false
            return false
        end
        if name == "models/f_anm.mdl" then
            ply.bSex = true
            return true
        end
    end
    return false
end

local plymeta = FindMetaTable("Player")           
function plymeta:GetZCAppearanceSubSlots()       ---new functionnnnnnnn sex
    local tMdl = hg.Appearance.FuckYouModels[1][self:GetModel()] or hg.Appearance.FuckYouModels[2][self:GetModel()]
    local mats = self:GetMaterials()
    local slots = {}
    if istable(tMdl) then
        for k, v in pairs(tMdl.submatSlots) do
            local slot = 0
            for i = 1, #mats do
                if mats[i] == v then slot = i - 1 break end
            end
            slots[#slots + 1] = slot
        end
    end
    return slots
end

local entmeta = FindMetaTable("Entity")
function entmeta:GetZCSubMaterialIndexByName(strName)
    local mats = self:GetMaterials()
    local id = nil
    for i = 1, #mats do
        if mats[i] == strName then
            id = i - 1
            break
        end
    end
    return id
end  ---- why sadsalat sad, why not happysalat