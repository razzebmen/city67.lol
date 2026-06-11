if SERVER then AddCSLuaFile() end
ENT.Base = "ent_hg_grenade"
ENT.Spawnable = false
ENT.Model = "models/weapons/w_eq_fraggrenade_thrown.mdl"
ENT.spoon = false
ENT.timeToBoom = 5
ENT.Fragmentation = 350 * 2 -- 450 уже страшно
ENT.BlastDis = 5 --meters
ENT.Penetration = 7