--[[---------------------------------------------------------------------------
ZCity RP — CurrentRound() shim
---------------------------------------------------------------------------
Зачем:
  Геймод zcity больше не запускается (мы перешли на DarkRP).
  Но папка lua/homigrad/ содержит много кода с проверками
    CurrentRound().name == "roleplay"
    CurrentRound() and CurrentRound().name == "coop"
    if CurrentRound and CurrentRound().name == "..." then
  без полного guard'а на nil. Чтобы их не переписывать (и не ломать движок),
  выдаём глобально функцию CurrentRound(), которая всегда возвращает таблицу
  с name = "roleplay". Все RP-ветки сработают корректно, остальные (hmcd/coop/
  defense/fear) тихо пропустятся.

Также: zb.ROUND_STATE = 1 (раунд "идёт") и zb.CROUND = "roleplay".

Безопасно подгружать через autorun darkrpmodification/lua/autorun/ — будет
загружено и до homigrad/, и до DarkRP.
---------------------------------------------------------------------------]]

zb = zb or {}
zb.ROUND_STATE = 1            -- 1 = round active (homigrad ожидает это)
zb.CROUND      = "roleplay"
zb.CROUND_MAIN = "roleplay"
zb.modes       = zb.modes or {}

-- ZCity_RP — основной namespace (определяется в sh_zcity_namespace.lua, autorun).
-- Загружается раньше нас по алфавиту: namespace < round_shim.
-- На случай если порядок поменяется — гарантируем существование.
ZCity_RP = ZCity_RP or {}
ZCity_RP.name        = ZCity_RP.name or "roleplay"
ZCity_RP.PrintName   = ZCity_RP.PrintName or "Roleplay"
ZCity_RP.randomSpawns = ZCity_RP.randomSpawns or false

-- MODE — псевдоним для совместимости со старым кодом (MODE.Jobs = ..., function MODE:AddMoney(...))
MODE = ZCity_RP

-- Singleton round-таблица — теперь это сам ZCity_RP, чтобы вся state в одной таблице.
-- Заглушки ставим только если их нет (namespace их уже задаёт).
local R = ZCity_RP
R.CanSpawn      = R.CanSpawn      or function(self, ply) return true end
R.CanLaunch     = R.CanLaunch     or function(self) return true end
R.ShouldRoundEnd = R.ShouldRoundEnd or function(self) return false end
R.GetTeamSpawn  = R.GetTeamSpawn  or function(self) return {}, {} end
R.GetSpawnPos   = R.GetSpawnPos   or function(self, ply) return ply and ply:GetPos() or vector_origin end
R.GetPlySpawn   = R.GetPlySpawn   or function(self, ply) return ply and ply:GetPos() or vector_origin end
R.GetLootTable  = R.GetLootTable  or function(self) return {} end
R.Intermission  = R.Intermission  or function(self) end
R.RoundStart    = R.RoundStart    or function(self) end
R.RoundThink    = R.RoundThink    or function(self) end
R.EndRound      = R.EndRound      or function(self) end
R.GiveEquipment = R.GiveEquipment or function(self) end
R.GuiltCheck    = R.GuiltCheck    or function(att, vic, add, harm, amt) return 0, false end
R.Jobs          = R.Jobs          or {}
R.LootTable     = R.LootTable     or {}
R.Lootables     = R.Lootables     or {}

zb.modes["roleplay"] = R

-- Главный shim: CurrentRound() / CurrentRound
function CurrentRound()
    return R
end

-- Дополнительные функции, которые могут проверяться (без вызова)
zb.ModesChances = zb.ModesChances or {}
zb.ModesChances["roleplay"] = 1

zb.Points = zb.Points or {}
-- Заглушки для всех point-групп, которые упоминаются в режимах.
-- Без них некоторые функции типа zb.GetMapPoints(...) возвращают nil → ошибки.
local STUB_POINT_GROUPS = {
    "ROLEPLAY_SPAWN", "Spawnpoint",
    "RP_Civilian", "RP_Police", "RP_SWAT", "RP_Mayor", "RP_ChiefPolice",
    "RP_Bandit", "RP_GunDealer", "RP_ISISSoldier", "RP_ISISLeader", "RP_Medic",
}
for _, name in ipairs(STUB_POINT_GROUPS) do
    if not zb.Points[name] then
        zb.Points[name] = { Name = name, Color = Color(120, 120, 120) }
    end
end

-- zb.GetMapPoints — если homigrad/initpost зависит от него, а он не определён.
zb.GetMapPoints = zb.GetMapPoints or function(name) return {} end

-- zb.SendDoors / SaveDoors / Doors — зависимости из sv_roleplay; делаем no-op
zb.Doors = zb.Doors or {}
zb.SendDoors = zb.SendDoors or function() end
zb.SaveDoors = zb.SaveDoors or function() end

-- zb.GiveRole — заглушка (homigrad/новый порт может назначать роль вручную)
zb.GiveRole = zb.GiveRole or function(ply, role, color)
    if not IsValid(ply) then return end
    ply:SetNWString("zb_role", role or "")
    if color then
        ply:SetNWVector("zb_role_color", Vector(color.r/255, color.g/255, color.b/255))
    end
end

-- zb:CheckTeams / CheckAlive / CheckPlaying (нужны для homigrad)
function zb:CheckTeams()
    local tbl = {}
    for i, info in pairs(team.GetAllTeams()) do tbl[i] = {} end
    for _, ply in player.Iterator() do
        local t = ply:Team()
        tbl[t] = tbl[t] or {}
        tbl[t][#tbl[t] + 1] = ply
    end
    return tbl
end

function zb:CheckAlive(incapacitatedcheck)
    local tbl = {}
    for _, ply in player.Iterator() do
        if not ply:Alive() then continue end
        if incapacitatedcheck and ply.organism and ply.organism.incapacitated then continue end
        tbl[#tbl + 1] = ply
    end
    return tbl
end

function zb:CheckAliveTeams(incapacitatedcheck)
    local tbl = {}
    for i, info in pairs(team.GetAllTeams()) do
        if i == TEAM_UNASSIGNED or i == TEAM_SPECTATOR then continue end
        tbl[i] = {}
    end
    for _, ply in player.Iterator() do
        if not ply:Alive() then continue end
        if incapacitatedcheck and ply.organism and ply.organism.incapacitated then continue end
        local t = ply:Team()
        tbl[t] = tbl[t] or {}
        tbl[t][#tbl[t] + 1] = ply
    end
    return tbl
end

function zb:CheckPlaying()
    local tbl = {}
    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        if not ply:Alive() then continue end
        tbl[#tbl + 1] = ply
    end
    return tbl
end

-- BalancedChoice — homigrad использует zb:BalancedChoice(0, 1) для распределения команд
function zb:BalancedChoice(team1, team2)
    return team1 -- В RP это не используется, всегда возвращаем первую команду
end

-- FurthestFromEveryone — заглушка
function zb:FurthestFromEveryone(chooseTbl, restrictTbl, func, iStart, iEnd)
    if chooseTbl and not table.IsEmpty(chooseTbl) then
        return table.Random(chooseTbl)
    end
    return vector_origin
end

function zb:GetRandomSpawn(target, spawns)
    if spawns and not table.IsEmpty(spawns) then
        return table.Random(spawns)
    end
    return vector_origin
end

function zb:GetTeamSpawn(ply)
    return ply and ply:GetPos() or vector_origin
end

print("[ZCity RP] CurrentRound() shim loaded — homigrad может работать без zcity-gamemode")
