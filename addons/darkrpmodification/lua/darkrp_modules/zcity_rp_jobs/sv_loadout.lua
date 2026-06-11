--[[---------------------------------------------------------------------------
ZCity RP — назначение homigrad-класса, радиочастоты и армора при спавне
---------------------------------------------------------------------------
DarkRP сам выдаёт оружие/модель/health согласно настройкам джоба в jobs.lua.
Здесь мы дополняем: устанавливаем homigrad PlayerClass + ставим радиочастоту
рации + надеваем армор. Это всё что было в sv_roleplay.lua PlayerSpawn-хуке.
---------------------------------------------------------------------------]]
if not SERVER then return end

-- ============================================================================
-- Хелпер для установки NWString "RoleplayJob" из текущей DarkRP-команды
-- ============================================================================
local function syncRoleplayJob(ply)
    if not IsValid(ply) then return end
    local teamID = ply:Team()
    local jobName = (RPExtraTeams and RPExtraTeams[teamID] and RPExtraTeams[teamID].name) or ""
    if jobName == "" then return end

    ply:SetNWString("RoleplayJob", jobName)
    ply.RoleplayJob = jobName

    local jobTbl = RPExtraTeams and RPExtraTeams[teamID]
    if jobTbl and jobTbl.color and zb and zb.GiveRole then
        zb.GiveRole(ply, jobName, jobTbl.color)

        -- Также синхронизируем цвет в NWVector (нужен scoreboard)
        ply:SetNWVector("RoleplayJobColor",
            Vector(jobTbl.color.r/255, jobTbl.color.g/255, jobTbl.color.b/255))
    end
end

-- ============================================================================
-- При смене джоба: сразу устанавливаем NWString. Модель/одежда не трогаем
-- (см. флаг RP_KeepCurrentSkin).
-- ============================================================================
hook.Add("OnPlayerChangedTeam", "ZCity_RP_SetJobNWString", syncRoleplayJob)

-- При спавне (включая первый): убедимся что RoleplayJob выставлен
hook.Add("PlayerSpawn", "ZCity_RP_SetJobNWStringOnSpawn", function(ply)
    timer.Simple(0.1, function() syncRoleplayJob(ply) end)
end)

-- При первом коннекте — тоже (на случай если PlayerSpawn ещё не отработал)
hook.Add("PlayerInitialSpawn", "ZCity_RP_SetJobNWStringInitial", function(ply)
    timer.Simple(0.5, function() syncRoleplayJob(ply) end)
    timer.Simple(2, function() syncRoleplayJob(ply) end)
end)

-- ============================================================================
-- Хук на PlayerSetModel — блокируем смену модели если игрок жив и сменил джоб
-- через RP-меню (RP_KeepCurrentSkin = true). Снимается флаг при PlayerSpawn.
-- ============================================================================
hook.Add("PlayerSetModel", "ZCity_RP_KeepCurrentSkin", function(ply)
    if not IsValid(ply) then return end
    if ply.RP_KeepCurrentSkin then
        return true -- блокируем смену модели до следующего респавна
    end
end)

hook.Add("PlayerSpawn", "ZCity_RP_ClearKeepSkinFlag", function(ply)
    if not IsValid(ply) then return end
    ply.RP_KeepCurrentSkin = nil -- при респавне новая модель применяется как обычно
end)

local function applyZCityRoleData(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not ply.getDarkRPVar then return end

    local jobName = (team and team.GetName(ply:Team())) or ""
    if jobName == "" then return end

    -- 1. Homigrad PlayerClass
    local class = ZCity_JobToClass and ZCity_JobToClass[jobName]
    if class and ply.SetPlayerClass then
        ply:SetPlayerClass(class, {bNoEquipment = true})
    end

    -- 2. Радиочастота для рации (weapon_walkie_talkie)
    local freq = ZCity_JobRadio and ZCity_JobRadio[jobName]
    if freq then
        timer.Simple(0.1, function()
            if not IsValid(ply) then return end
            local wep = ply:GetWeapon("weapon_walkie_talkie")
            if IsValid(wep) then
                wep.Frequency = freq
            end
        end)
    end

    -- 3. Армор через homigrad hg.AddArmor
    local armor = ZCity_JobArmor and ZCity_JobArmor[jobName]
    if armor and hg and hg.AddArmor then
        timer.Simple(0.2, function()
            if IsValid(ply) and ply:Alive() then
                hg.AddArmor(ply, armor)
            end
        end)
    end

    -- 4. Совместимость со старым кодом zcity (RoleplayJob NWString)
    ply:SetNWString("RoleplayJob", jobName)
    ply.RoleplayJob = jobName

    -- 5. Цвет роли через zb.GiveRole (homigrad использует это для именных тегов)
    local jobTbl = RPExtraTeams and RPExtraTeams[ply:Team()]
    if jobTbl and jobTbl.color and zb and zb.GiveRole then
        zb.GiveRole(ply, jobName, jobTbl.color)
    end

    -- 6. Сохраняем точку спавна для логики «зоны защиты от доставания оружия»
    ply.RP_SpawnPos = ply:GetPos()

    -- 7. ГАРАНТИЯ: проверяем что DarkRP-оружие из jobs.lua реально выдалось.
    -- Иногда homigrad-классы вызывают StripWeapons в OnSpawn, что отбирает то
    -- что DarkRP дал секундой раньше. Пере-выдаём через timer:
    timer.Simple(0.3, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local jt = ply.getJobTable and ply:getJobTable()
        if not jt or not jt.weapons then return end

        for _, weaponClass in ipairs(jt.weapons) do
            if not ply:HasWeapon(weaponClass) then
                local wep = ply:Give(weaponClass)
                if IsValid(wep) then
                    -- Пополняем боезапас 2 обоймы
                    if wep.Primary and wep.Primary.Ammo then
                        local clipSize = wep.Primary.ClipSize or 30
                        if clipSize > 0 then
                            ply:GiveAmmo(clipSize * 2, wep.Primary.Ammo, true)
                        end
                    end
                    -- Радиочастота (если это рация)
                    if weaponClass == "weapon_walkie_talkie" and freq then
                        wep.Frequency = freq
                    end
                end
            end
        end

        -- Базовое оружие homigrad: руки и фонарь — даём всегда
        if not ply:HasWeapon("weapon_hands_sh") then
            ply:Give("weapon_hands_sh")
        end
    end)
end

-- DarkRP вызывает PlayerLoadout после установки джоба и выдачи оружия.
-- Мы вешаемся ПОСЛЕ него (через timer на 0.05с) чтобы не ломать DarkRP-выдачу.
hook.Add("PlayerLoadout", "ZCity_RP_ApplyClassAndArmor", function(ply)
    timer.Simple(0.05, function() applyZCityRoleData(ply) end)
end)

-- НЕ применяем класс при OnPlayerChangedTeam — иначе модель/одежда сменится
-- сразу до респавна. Игрок должен видеть старую модель пока не умрёт и не
-- заспавнится с новой профессией. PlayerLoadout вызывается при респавне и
-- применяет всё нужное.

-- ============================================================================
-- VIP-перк: на работе Бандит выдаётся оружие, которое раньше было базовым.
-- Базовый бандит (jobs.lua) теперь без оружия — sogknife + mp-80 даёт только
-- этот хук, и только если игрок в группе "vip".
-- ============================================================================
local VIP_BANDIT_WEAPONS = { "weapon_sogknife", "weapon_mp-80" }

local function giveVipBanditWeapons(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not TEAM_BANDIT or ply:Team() ~= TEAM_BANDIT then return end
    if string.lower(ply:GetUserGroup() or "") ~= "vip" then return end

    for _, cls in ipairs(VIP_BANDIT_WEAPONS) do
        if not ply:HasWeapon(cls) then
            local wep = ply:Give(cls)
            -- Пополняем боезапас 2 обоймами (как в общем "гаранте" выше)
            if IsValid(wep) and wep.Primary and wep.Primary.Ammo then
                local clip = wep.Primary.ClipSize or 30
                if clip > 0 then
                    ply:GiveAmmo(clip * 2, wep.Primary.Ammo, true)
                end
            end
        end
    end
end

-- Дёргаем ПОСЛЕ applyZCityRoleData (timer 0.3) — берём 0.4с, чтобы базовый
-- лоадаут (включая гарант пере-выдачи из jt.weapons) уже отработал.
hook.Add("PlayerLoadout", "ZCity_RP_VIPBanditWeapons", function(ply)
    timer.Simple(0.4, function() giveVipBanditWeapons(ply) end)
end)

print("[ZCity RP] Job loadout module loaded")
