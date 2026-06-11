--[[---------------------------------------------------------------------------
ZCity RP — отключение стандартного DarkRP-спавна на info_player_start.

Проблема:
DarkRP в GM:PlayerSpawn вызывает hook.Call("PlayerSelectSpawn") и сразу делает
ply:SetPos(...). У ZCity-RP кастомный спавн выставляется отложенно через
timer.Simple(0.2) → ply:SetPos(GetSpawnPos(ply)). Между этими двумя SetPos
есть окно ~0.2 секунды когда игрок физически стоит на info_player_start.
Если timer не успел отработать (rare race / lag / lua error в одном из
вложенных хуков) — игрок остаётся на спавне DarkRP/карты и не телепортируется
на ROLEPLAY_SPAWN.

Решение:
Перехватываем PlayerSelectSpawn С САМОГО ВЫСОКОГО ПРИОРИТЕТА и возвращаем
кастомную позицию сразу. Тогда ply:SetPos в DarkRP-PlayerSpawn использует
наш ROLEPLAY_SPAWN, и даже если отложенный timer.Simple не отработает —
игрок всё равно окажется в правильном месте.
---------------------------------------------------------------------------]]

if not SERVER then return end

local function PickRoleplaySpawnPos(ply)
    -- 1) Если ZCity_RP.GetSpawnPos уже готов — используем его
    if ZCity_RP and ZCity_RP.GetSpawnPos and ZCity_RP.Jobs then
        local ok, pos = pcall(ZCity_RP.GetSpawnPos, ZCity_RP, ply)
        if ok and isvector(pos) and pos ~= vector_origin then
            return pos
        end
    end

    -- 2) Fallback: первая попавшаяся ROLEPLAY_SPAWN точка
    if zb and zb.GetMapPoints then
        local pts = zb.GetMapPoints("ROLEPLAY_SPAWN") or {}
        local picks = {}
        for _, v in pairs(pts) do
            if v.pos then picks[#picks + 1] = v.pos end
        end
        if #picks > 0 then
            return picks[math.random(#picks)]
        end
    end

    -- 3) Fallback fallback: info_player_start (стандартный DarkRP-спавн —
    -- то от чего мы пытаемся уйти, но если своих точек нет и rp_spawn не
    -- проставлен — лучше так чем (0,0,0))
    return nil
end

-- Создаём фейковую entity с GetPos() — формат возврата PlayerSelectSpawn
-- ожидает entity с :GetPos(). Чтобы не плодить prop_physics, делаем шим.
local FakeSpawnEnt = {}
FakeSpawnEnt.__index = FakeSpawnEnt
function FakeSpawnEnt:GetPos() return self._pos end
function FakeSpawnEnt:GetAngles() return self._ang or angle_zero end
function FakeSpawnEnt:IsValid() return true end

local function MakeFakeSpawn(pos, ang)
    return setmetatable({ _pos = pos, _ang = ang }, FakeSpawnEnt)
end

-- HOOK_HIGH чтобы наш хук срабатывал ДО любых других PlayerSelectSpawn,
-- включая дефолтный из DarkRP (gamemode-метод).
hook.Add("PlayerSelectSpawn", "ZCity_RP_OverrideDefaultSpawn", function(ply)
    if not IsValid(ply) then return end
    local pos = PickRoleplaySpawnPos(ply)
    if not pos then return end
    -- Возврат: entity, position. Position имеет приоритет в DarkRP-коде:
    --   ply:SetPos(pos or ent:GetPos())
    return MakeFakeSpawn(pos), pos
end, HOOK_HIGH)

-- На всякий случай: GM:PlayerSpawn в DarkRP использует SetPos(pos) сразу,
-- но кастомный код в sv_roleplay.lua делает SetPos через timer.Simple(0.1).
-- Если кастомный таймер по какой-то причине не сработает — игрок останется
-- там где его поставил DarkRP-PlayerSpawn (а это уже наша точка благодаря
-- хуку выше). Готово.

print("[ZCity RP] Default DarkRP spawn override installed (PlayerSelectSpawn)")


-- ============================================
-- Страховка: если игрок всё-таки оказался на info_player_start
-- (например timer.Simple из RoleplayResetRespawn упал или был отменён) —
-- через 0.5 секунды после спавна телепортируем его на ROLEPLAY_SPAWN.
-- ============================================

local function IsOnInfoPlayerStart(ply)
    if not IsValid(ply) then return false end
    local plyPos = ply:GetPos()
    for _, ent in ipairs(ents.FindByClass("info_player_start")) do
        if IsValid(ent) and plyPos:DistToSqr(ent:GetPos()) < (64 * 64) then
            return true
        end
    end
    return false
end

hook.Add("PlayerSpawn", "ZCity_RP_FixStuckOnDefaultSpawn", function(ply)
    if not IsValid(ply) then return end

    -- Через полсекунды проверяем где игрок. К этому моменту все хуки
    -- (включая отложенный SetPos из sv_roleplay.lua) должны были
    -- отработать. Если он всё ещё на info_player_start — спасаем.
    timer.Simple(0.5, function()
        if not IsValid(ply) or not ply:Alive() then return end
        if not IsOnInfoPlayerStart(ply) then return end

        local pos = PickRoleplaySpawnPos(ply)
        if pos then
            ply:SetPos(pos)
            ply.RP_SpawnPos = pos
            print("[ZCity RP] Player " .. ply:Nick() .. " was stuck on info_player_start — teleported to ROLEPLAY_SPAWN")
        end
    end)
end)
