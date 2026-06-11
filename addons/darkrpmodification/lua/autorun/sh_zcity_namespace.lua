--[[---------------------------------------------------------------------------
ZCity_RP — namespace, имитирующий старый MODE из gamemodes/zcity-roleplay
---------------------------------------------------------------------------
Старый код roleplay-режима всё построен на:
    local MODE = MODE
    MODE.Jobs[name] = {...}
    MODE:AddMoney(ply, amt)
    MODE.CityTaxRate = ...
    CurrentRound().Jobs[name]
    round:GetSpawnPos(ply)
    и т.д.

Скрипт миграции заменил `MODE` на `ZCity_RP`. Здесь определяем ZCity_RP так,
чтобы все эти вызовы работали поверх DarkRP-API (ply:addMoney, getDarkRPVar и т.д.).

Загружается раньше всех остальных файлов модуля zcity_rp_core (см. имя 'sh_zcity_rp_namespace').
---------------------------------------------------------------------------]]

ZCity_RP = ZCity_RP or {}

-- Привязываем MODE к ZCity_RP чтобы старый код вида
--   MODE.Jobs = {...}
--   function MODE:AddMoney(...) ... end
-- писал прямо в ZCity_RP. Это убирает необходимость переписывать каждое
-- упоминание MODE в мигрированных файлах.
MODE = ZCity_RP

-- Совместимость со старым raund-API
ZCity_RP.name             = "roleplay"
ZCity_RP.PrintName        = "Roleplay"
ZCity_RP.randomSpawns     = false
ZCity_RP.ROUND_TIME       = 999999999
ZCity_RP.LootSpawn        = false
ZCity_RP.ForBigMaps       = true
ZCity_RP.Chance           = 1
ZCity_RP.Lootables        = {}
ZCity_RP.LootTable        = {}
ZCity_RP.Jobs             = ZCity_RP.Jobs or {}

-- City-механика (война/комендантский час/казна) — глобальные переменные
ZCity_RP.CityTaxRate              = ZCity_RP.CityTaxRate or 10
ZCity_RP.CityTreasury             = ZCity_RP.CityTreasury or 0
ZCity_RP.CityRules                = ZCity_RP.CityRules or "Правила города не установлены"
ZCity_RP.TreasuryRobberyAvailable = true
ZCity_RP.NextTreasuryRobbery      = 0
ZCity_RP.IsWarActive              = false
ZCity_RP.IsCurfewActive           = false
ZCity_RP.CurfewReason             = ""
ZCity_RP.NextWarTime              = 0
ZCity_RP.NextCurfewTime           = 0
ZCity_RP.NextSalaryPayment        = 0
ZCity_RP.RoleplayPoints           = {}
ZCity_RP.SafeZoneRadius           = 600

--[[---------------------------------------------------------------------------
Деньги — пробрасываем на DarkRP-кошелёк (ply:addMoney / canAfford / getDarkRPVar)
---------------------------------------------------------------------------]]

if SERVER then
    util.AddNetworkString("roleplay_sync_money") -- старое сетевое сообщение нужно для cl_roleplay HUD

    function ZCity_RP:AddMoney(ply, amount, reason, targetPly)
        if not IsValid(ply) then return end
        if not ply.addMoney then return end
        ply:addMoney(amount)
        local money = ply:getDarkRPVar("money") or 0
        ply.RoleplayMoney = money

        -- Совместимость со старым клиентским HUD (cl_roleplay.lua слушает roleplay_sync_money)
        net.Start("roleplay_sync_money")
        net.WriteInt(money, 32)
        net.Send(ply)

        -- Лог-хук для XGUI/Discord-логгера (как в старом roleplay)
        hook.Run("RoleplayMoneyChange", ply, amount, reason or "add", targetPly)
        return money
    end

    function ZCity_RP:TakeMoney(ply, amount, reason, targetPly)
        if not IsValid(ply) then return false end
        if not ply.canAfford then return false end
        if not ply:canAfford(amount) then return false end
        ply:addMoney(-amount)
        ply.RoleplayMoney = ply:getDarkRPVar("money") or 0

        net.Start("roleplay_sync_money")
        net.WriteInt(ply.RoleplayMoney, 32)
        net.Send(ply)

        hook.Run("RoleplayMoneyChange", ply, -amount, reason or "take", targetPly)
        return true
    end

    function ZCity_RP:GetMoney(ply)
        if not IsValid(ply) then return 0 end
        return ply:getDarkRPVar("money") or 0
    end

    -- Дополнительно: ловим прямые DarkRP-изменения денег и пробрасываем игроку
    -- (например, когда другой плагин/админ выдаёт деньги через DarkRP.payPlayer)
    hook.Add("playerWalletChanged", "ZCity_RP_SyncOldRoleplayMoney", function(ply, diff, oldAmount)
        if not IsValid(ply) then return end
        local newAmount = (oldAmount or 0) + (diff or 0)
        ply.RoleplayMoney = newAmount
        net.Start("roleplay_sync_money")
        net.WriteInt(math.floor(newAmount), 32)
        net.Send(ply)
    end)
else
    function ZCity_RP:GetMoney(ply)
        ply = ply or LocalPlayer()
        if not IsValid(ply) or not ply.getDarkRPVar then return 0 end
        return ply:getDarkRPVar("money") or 0
    end
end

--[[---------------------------------------------------------------------------
Spawn helpers — большинство тоже через DarkRP
---------------------------------------------------------------------------]]

function ZCity_RP:GetSpawnPos(ply)
    if not IsValid(ply) then return vector_origin end
    return ply:GetPos()
end

function ZCity_RP:GetPlySpawn(ply)
    return self:GetSpawnPos(ply)
end

function ZCity_RP:GetTeamSpawn()
    return {}, {}
end

-- Пустые методы которые могут вызываться (no-op) — оставляем тут чтобы старый код не падал
function ZCity_RP:Intermission()    end
function ZCity_RP:RoundStart()      end
function ZCity_RP:RoundThink()      end
function ZCity_RP:EndRound()        end
function ZCity_RP:GiveEquipment()   end
function ZCity_RP:CheckAlivePlayers() end
function ZCity_RP:ShouldRoundEnd()  return false end
function ZCity_RP:CanSpawn()        return true  end
function ZCity_RP:CanLaunch()       return true  end
function ZCity_RP:GetLootTable()    return {}    end
function ZCity_RP.GuiltCheck(att, vic, add, harm, amt) return 0, false end

print("[ZCity RP] ZCity_RP namespace ready (server=" .. tostring(SERVER) .. ")")
