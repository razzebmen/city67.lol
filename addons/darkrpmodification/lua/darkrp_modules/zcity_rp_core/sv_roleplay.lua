-- [ZCITY_PORT] Файл автоматически мигрирован из gamemodes/zcity/.../modes/roleplay/sv_roleplay.lua
-- Источник: _backup_20260522_182916/zcity/gamemode/modes/roleplay/
-- Все обращения к CurrentRound()/MODE/round заменены на ZCity_RP.
-- ZCity_RP — это таблица-обёртка, имитирующая старый MODE-namespace,
--           содержит Jobs, AddMoney, TakeMoney, GetMoney, CityTaxRate и т.д.
-- Реализация в darkrp_modules/zcity_rp_core/sh_zcity_rp_namespace.lua

-- [ZCITY_PORT] Безопасный bootstrap (см. sh_roleplay.lua)
ZCity_RP = ZCity_RP or {}
MODE = ZCity_RP

MODE.randomSpawns = ROLEPLAY_RANDOM_SPAWNS or true

-- БЕСКОНЕЧНЫЙ РЕЖИМ - нет ограничения по времени
MODE.ROUND_TIME = 999999999

-- Настройки режима
MODE.LootSpawn = false
MODE.ForBigMaps = true
MODE.Chance = 1

-- Таблица лута для режима (отключена)
MODE.Lootables = {}

-- Таблица профессий
MODE.Jobs = {
    ["Гражданский"] = {
        pointGroup = "RP_Civilian",
        color = Color(80, 180, 100),
        salary = 100,
        weapons = {},
        playerClass = "Refugee",
        useAppearance = true,
        limit = 0 -- Без ограничений
    },
    ["Полицейский"] = {
        pointGroup = "RP_Police",
        color = Color(60, 120, 200),
        salary = 250,
        weapons = {
            "weapon_glock17",
            "weapon_hg_tonfa",
            "weapon_handcuffs_key",
            "weapon_handcuffs",
            "weapon_taser",
            "weapon_medkit_sh",
            "weapon_walkie_talkie"
        },
        playerClass = "police",
        radioFrequency = 100.5,
        models = {
            "models/monolithservers/mpd/male_01.mdl",
            "models/monolithservers/mpd/male_03.mdl",
            "models/monolithservers/mpd/male_04_2.mdl",
            "models/monolithservers/mpd/male_05.mdl",
            "models/monolithservers/mpd/male_07_2.mdl",
            "models/monolithservers/mpd/male_08.mdl",
            "models/monolithservers/mpd/male_09_2.mdl"
        },
        limit = 10
    },
    ["Спецназ"] = {
        pointGroup = "RP_SWAT",
        color = Color(40, 80, 140),
        salary = 350,
        weapons = {
            "weapon_glock17",
            "weapon_handcuffs_key",
            "weapon_handcuffs",
            "weapon_ram",
            "weapon_melee",
            "weapon_m4a1",
            "weapon_medkit_sh",
            "weapon_walkie_talkie"
        },
        playerClass = "swat",
        armor = {"ent_armor_vest2", "ent_armor_helmet5"},
        radioFrequency = 100.5,
        models = {
            "models/css_seb_swat/css_swat.mdl"
        },
        limit = 5
    },
    ["Мэр"] = {
        pointGroup = "RP_Mayor",
        color = Color(200, 160, 60),
        salary = 500,
        weapons = {
            "weapon_deagle",
            "weapon_medkit_sh",
            "weapon_handcuffs_key",
            "weapon_handcuffs",
            "weapon_walkie_talkie"
        },
        armor = {"ent_armor_vest2"},
        radioFrequency = 100.5,
        models = {
            "models/player/breen.mdl"
        },
        limit = 1
    },
    ["Глава Полиции"] = {
        pointGroup = "RP_ChiefPolice",
        color = Color(80, 100, 180),
        salary = 400,
        weapons = {
            "weapon_deagle",
            "weapon_medkit_sh",
            "weapon_handcuffs_key",
            "weapon_handcuffs",
            "weapon_walkie_talkie"
        },
        playerClass = "police",
        armor = {"ent_armor_vest2"},
        radioFrequency = 100.5,
        models = {
            "models/monolithservers/mpd/male_01.mdl"
        },
        limit = 1
    },
    ["Бандит"] = {
        pointGroup = "RP_Bandit",
        color = Color(180, 60, 60),
        salary = 150,
        weapons = {"weapon_sogknife", "weapon_mp-80"},
        playerClass = "terrorist",
        limit = 15
    },
    ["Продавец Оружия"] = {
        pointGroup = "RP_GunDealer",
        color = Color(140, 100, 60),
        salary = 300,
        weapons = {},
        playerClass = "Refugee",
        models = {
            "models/player/Group01/male_03.mdl",
            "models/player/Group01/male_08.mdl",
            "models/player/Group01/male_09.mdl"
        },
        limit = 2
    },
    ["Солдат ЦАХАЛ"] = {
        pointGroup = "RP_ISISSoldier",
        color = Color(120, 40, 40),
        salary = 200,
        weapons = {
            "weapon_makarov",
            "weapon_akm",
            "weapon_bandage_sh",
            "weapon_painkillers",
            "weapon_walkie_talkie",
            "weapon_sogknife"
        },
        playerClass = "isis",
        armor = {"ent_armor_vest1", "ent_armor_helmet5"},
        radioFrequency = 88.8,
        limit = 10
    },
    ["Глава ЦАХАЛ"] = {
        pointGroup = "RP_ISISLeader",
        color = Color(100, 20, 20),
        salary = 400,
        weapons = {
            "weapon_deagle",
            "weapon_akm",
            "weapon_hg_type59_tpik",
            "weapon_bigbandage_sh",
            "weapon_painkillers",
            "weapon_walkie_talkie"
        },
        playerClass = "isis",
        armor = {"ent_armor_vest1", "ent_armor_helmet5"},
        radioFrequency = 88.8,
        limit = 1
    },
    ["Медик"] = {
        pointGroup = "RP_Medic",
        color = Color(60, 180, 100),
        salary = 200,
        weapons = {
            "weapon_bigbandage_sh",
            "weapon_bandage_sh",
            "weapon_medkit_sh",
            "weapon_painkillers",
            "weapon_naloxone",
            "weapon_adrenaline",
            "weapon_morphine",
        },
        playerClass = "medic_rp",
        limit = 5
    }
}

-- Сетевые сообщения
util.AddNetworkString("roleplay_start")
util.AddNetworkString("roleplay_select_job")
util.AddNetworkString("roleplay_respawn_timer")
util.AddNetworkString("roleplay_job_error")
util.AddNetworkString("roleplay_job_success")
util.AddNetworkString("roleplay_job_counts")
util.AddNetworkString("roleplay_request_job_counts")
util.AddNetworkString("roleplay_sync_money")
util.AddNetworkString("roleplay_give_money")
util.AddNetworkString("roleplay_money_message")
util.AddNetworkString("roleplay_salary_message")
util.AddNetworkString("roleplay_error_message")
util.AddNetworkString("roleplay_mayor_menu")
util.AddNetworkString("roleplay_set_tax")
util.AddNetworkString("roleplay_set_rules")
util.AddNetworkString("roleplay_sync_city_data")
util.AddNetworkString("roleplay_rob_treasury")

-- Сетевое сообщение для цветных сообщений в чат
util.AddNetworkString("roleplay_colored_message")
util.AddNetworkString("roleplay_robbery_start")
util.AddNetworkString("roleplay_robbery_cancel")

-- Сетевые сообщения для системы войны
util.AddNetworkString("roleplay_declare_war")
util.AddNetworkString("roleplay_war_message")

-- Сетевые сообщения для системы комендантского часа
util.AddNetworkString("roleplay_declare_curfew")
util.AddNetworkString("roleplay_curfew_message")

-- Обработчик передачи денег
net.Receive("roleplay_give_money", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    local target = net.ReadEntity()
    local amount = net.ReadInt(32)
    
    -- Проверки
    if not IsValid(ply) or not ply:Alive() then return end
    if not IsValid(target) or not target:IsPlayer() or not target:Alive() then
        net.Start("roleplay_error_message")
        net.WriteString("Игрок недоступен")
        net.Send(ply)
        return
    end
    
    -- Проверка расстояния (5 метров)
    if ply:GetPos():Distance(target:GetPos()) > 500 then
        net.Start("roleplay_error_message")
        net.WriteString("Игрок слишком далеко")
        net.Send(ply)
        return
    end
    
    -- Проверка суммы
    if amount <= 0 then
        net.Start("roleplay_error_message")
        net.WriteString("Неверная сумма")
        net.Send(ply)
        return
    end
    
    ply.RoleplayMoney = ply.RoleplayMoney or 5000
    
    if ply.RoleplayMoney < amount then
        net.Start("roleplay_error_message")
        net.WriteString("Недостаточно денег")
        net.Send(ply)
        return
    end
    
    -- Анимация передачи денег (только отправитель)
    ply:DoAnimationEvent(ACT_GMOD_GESTURE_MELEE_SHOVE_1HAND)
    
    -- Уведомляем систему логов о P2P-переводе
    hook.Run("ZLogs_P2PTransfer", ply, target, amount)

    -- Переводим деньги
    round:TakeMoney(ply, amount)
    round:AddMoney(target, amount)
    
    -- Цветное сообщение отправителю
    net.Start("roleplay_money_message")
    net.WriteBool(true) -- true = отправитель
    net.WriteString(target:Nick())
    net.WriteInt(amount, 32)
    net.Send(ply)

    -- Цветное сообщение получателю
    net.Start("roleplay_money_message")
    net.WriteBool(false) -- false = получатель
    net.WriteString(ply:Nick())
    net.WriteInt(amount, 32)
    net.Send(target)
end)

-- Обработчик запроса количества игроков по профессиям
net.Receive("roleplay_request_job_counts", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    local counts = {}
    
    -- Подсчитываем игроков по профессиям
    for jobName, jobData in pairs(round.Jobs) do
        counts[jobName] = {
            current = 0,
            limit = jobData.limit or 0
        }
    end
    
    for _, p in player.Iterator() do
        if p:Team() ~= TEAM_SPECTATOR and p.RoleplayJob then
            if counts[p.RoleplayJob] then
                counts[p.RoleplayJob].current = counts[p.RoleplayJob].current + 1
            end
        end
    end
    
    net.Start("roleplay_job_counts")
    net.WriteTable(counts)
    net.Send(ply)
end)

-- Таблица дружественных классов
local friendlytable = {
    {"Citizen", "Refugee", "Rebel"},
}

hg.FriendlyClasses = hg.FriendlyClasses or {}

for i, tbl in ipairs(friendlytable) do
    for j, class in ipairs(tbl) do
        hg.FriendlyClasses[class] = hg.FriendlyClasses[class] or {}
        for k, class2 in ipairs(tbl) do
            hg.FriendlyClasses[class][class2] = true
        end
    end
end

-- Проверка вины при атаке союзников (отключена)
function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
    return 0, false -- Система кармы отключена в режиме roleplay
end

-- Таблица лута
MODE.LootTable = {
    [1] = {1, {
        {5, "ent_ammo_9x19mmparabellum"},
        {4, "weapon_bigconsumable"},
        {4, "weapon_painkillers"},
        {4, "weapon_bigbandage_sh"},
        {3, "weapon_medkit_sh"},
        {2, "weapon_hk_usp"},
        {2, "weapon_mini14"},
        {1, "ent_ammo_5.56x45mm"},
    }},
}

function MODE:GetLootTable()
    return self.LootTable[1][2]
end

-- ============================================
-- СИСТЕМА УПРАВЛЕНИЯ ГОРОДОМ
-- ============================================

-- Инициализация данных города
MODE.CityTaxRate = MODE.CityTaxRate or 10 -- Процент налога (10-50%)
MODE.CityTreasury = MODE.CityTreasury or 0 -- Казна города
MODE.CityRules = MODE.CityRules or "Правила города не установлены" -- Правила города
MODE.TreasuryRobberyAvailable = MODE.TreasuryRobberyAvailable or true -- Доступно ли ограбление
MODE.NextTreasuryRobbery = MODE.NextTreasuryRobbery or 0 -- Время следующего доступного ограбления
MODE.IsWarActive = MODE.IsWarActive or false -- Состояние войны

-- Обработчик открытия меню мэра
net.Receive("roleplay_mayor_menu", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    local jobName = ply.RoleplayJob or "Гражданский"
    if jobName ~= "Мэр" then
        net.Start("roleplay_error_message")
        net.WriteString("Только мэр может управлять городом")
        net.Send(ply)
        return
    end
    
    -- Отправляем текущие данные города
    net.Start("roleplay_sync_city_data")
    net.WriteInt(round.CityTaxRate, 8)
    net.WriteInt(round.CityTreasury, 32)
    net.WriteString(round.CityRules)
    net.Send(ply)
end)

-- Обработчик установки налога
net.Receive("roleplay_set_tax", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    local jobName = ply.RoleplayJob or "Гражданский"
    if jobName ~= "Мэр" then return end
    
    local taxRate = net.ReadInt(8)
    taxRate = math.Clamp(taxRate, 10, 50) -- Минимум 10%, максимум 50%
    
    round.CityTaxRate = taxRate
    SetGlobalInt("CityTaxRate", taxRate)
    
    -- Уведомляем всех игроков
    for _, p in player.Iterator() do
        if p:Team() ~= TEAM_SPECTATOR then
            net.Start("roleplay_sync_city_data")
            net.WriteInt(round.CityTaxRate, 8)
            net.WriteInt(round.CityTreasury, 32)
            net.WriteString(round.CityRules)
            net.Send(p)
        end
    end
end)

-- Обработчик установки правил
net.Receive("roleplay_set_rules", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    local jobName = ply.RoleplayJob or "Гражданский"
    if jobName ~= "Мэр" then return end
    
    local rules = net.ReadString()
    round.CityRules = rules
    SetGlobalString("CityRules", rules)
    
    -- Уведомляем всех игроков
    for _, p in player.Iterator() do
        if p:Team() ~= TEAM_SPECTATOR then
            net.Start("roleplay_sync_city_data")
            net.WriteInt(round.CityTaxRate, 8)
            net.WriteInt(round.CityTreasury, 32)
            net.WriteString(round.CityRules)
            net.Send(p)
        end
    end
end)

-- Обработчик ограбления казны
net.Receive("roleplay_rob_treasury", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    local jobName = ply.RoleplayJob or "Гражданский"
    if jobName ~= "Глава ЦАХАЛ" then
        net.Start("roleplay_error_message")
        net.WriteString("Только Глава ЦАХАЛ может ограбить казну")
        net.Send(ply)
        return
    end
    
    -- Проверяем доступность ограбления
    if CurTime() < round.NextTreasuryRobbery then
        local timeLeft = math.ceil(round.NextTreasuryRobbery - CurTime())
        net.Start("roleplay_error_message")
        net.WriteString("Казна недоступна для ограбления. Осталось: " .. timeLeft .. " сек")
        net.Send(ply)
        return
    end
    
    -- Проверяем, есть ли деньги в казне
    if round.CityTreasury <= 0 then
        net.Start("roleplay_error_message")
        net.WriteString("В казне нет денег")
        net.Send(ply)
        return
    end
    
    -- Проверяем, не идёт ли уже ограбление
    if ply.RobbingTreasury then
        net.Start("roleplay_error_message")
        net.WriteString("Вы уже грабите казну!")
        net.Send(ply)
        return
    end
    
    -- Начинаем ограбление
    ply.RobbingTreasury = true
    ply.RobberyStartTime = CurTime()
    ply.RobberyEndTime = CurTime() + 30 -- 30 секунд
    
    -- Отправляем начало ограбления игроку
    net.Start("roleplay_robbery_start")
    net.WriteFloat(30) -- Длительность
    net.Send(ply)
    
    -- Уведомляем всех о начале ограбления
    for _, p in player.Iterator() do
        if p:Team() ~= TEAM_SPECTATOR then
            net.Start("roleplay_colored_message")
            net.WriteString("robbery_started")
            net.WriteString(ply:Nick())
            net.Send(p)
        end
    end
    
    -- Таймер для завершения ограбления
    timer.Create("RobberyTimer_" .. ply:SteamID(), 30, 1, function()
        if not IsValid(ply) or not ply:Alive() or not ply.RobbingTreasury then return end
        
        -- Успешное ограбление
        ply.RobbingTreasury = false
        
        local stolenAmount = round.CityTreasury
        round.CityTreasury = 0
        SetGlobalInt("CityTreasury", 0)
        
        -- Находим всех участников ЦАХАЛ
        local isisMembers = {}
        for _, p in player.Iterator() do
            if p:Team() ~= TEAM_SPECTATOR and p:Alive() then
                local job = p.RoleplayJob or "Гражданский"
                if job == "Глава ЦАХАЛ" or job == "Солдат ЦАХАЛ" then
                    table.insert(isisMembers, p)
                end
            end
        end
        
        -- Распределяем деньги
        if #isisMembers > 0 then
            local leaderShare = math.floor(stolenAmount * 0.5)
            round:AddMoney(ply, leaderShare, "isis_rob")

            local remainingAmount = stolenAmount - leaderShare
            local sharePerMember = math.floor(remainingAmount / #isisMembers)

            for _, member in ipairs(isisMembers) do
                round:AddMoney(member, sharePerMember, "isis_rob")
                
                if member ~= ply then
                    net.Start("roleplay_colored_message")
                    net.WriteString("robbery_member")
                    net.WriteInt(sharePerMember, 32)
                    net.Send(member)
                else
                    net.Start("roleplay_colored_message")
                    net.WriteString("robbery_leader")
                    net.WriteInt(leaderShare + sharePerMember, 32)
                    net.Send(member)
                end
            end
        end
        
        -- Устанавливаем кулдаун 5 минут
        round.NextTreasuryRobbery = CurTime() + 300
        SetGlobalInt("NextTreasuryRobbery", round.NextTreasuryRobbery)
        
        -- Уведомляем всех об успешном ограблении
        for _, p in player.Iterator() do
            if p:Team() ~= TEAM_SPECTATOR then
                net.Start("roleplay_colored_message")
                net.WriteString("robbery_success")
                net.WriteInt(stolenAmount, 32)
                net.Send(p)
            end
        end
    end)
end)

-- ============================================
-- СИСТЕМА ОБЪЯВЛЕНИЯ ВОЙНЫ
-- ============================================

-- Обработчик объявления/окончания войны
net.Receive("roleplay_declare_war", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    -- Проверяем, что игрок - Глава ЦАХАЛ
    local jobName = ply.RoleplayJob or "Гражданский"
    if jobName ~= "Глава ЦАХАЛ" then
        net.Start("roleplay_error_message")
        net.WriteString("Только Глава ЦАХАЛ может управлять войной")
        net.Send(ply)
        return
    end
    
    -- Проверяем, жив ли игрок
    if not ply:Alive() then
        net.Start("roleplay_error_message")
        net.WriteString("Вы должны быть живы для управления войной")
        net.Send(ply)
        return
    end
    
    -- Читаем состояние войны (true = объявить, false = закончить)
    local declareWar = net.ReadBool()
    
    -- Если пытаемся объявить войну
    if declareWar then
        -- Проверяем, не идет ли уже война
        if round.IsWarActive then
            net.Start("roleplay_error_message")
            net.WriteString("Война уже объявлена!")
            net.Send(ply)
            return
        end

        -- Проверяем, не идёт ли комендантский час
        if round.IsCurfewActive then
            net.Start("roleplay_error_message")
            net.WriteString("Нельзя объявить войну во время комендантского часа!")
            net.Send(ply)
            return
        end

        -- Проверяем кулдаун после предыдущей войны
        if round.NextWarTime and CurTime() < round.NextWarTime then
            local timeLeft = math.ceil(round.NextWarTime - CurTime())
            local minutes  = math.floor(timeLeft / 60)
            local seconds  = timeLeft % 60
            net.Start("roleplay_error_message")
            net.WriteString(string.format("Война недоступна. Попробуйте через %d:%02d", minutes, seconds))
            net.Send(ply)
            return
        end
        
        -- Проверяем, есть ли живой мэр
        local mayorAlive = false
        for _, p in player.Iterator() do
            if p:Team() ~= TEAM_SPECTATOR and p:Alive() then
                local pJobName = p.RoleplayJob or "Гражданский"
                if pJobName == "Мэр" then
                    mayorAlive = true
                    break
                end
            end
        end
        
        if not mayorAlive then
            net.Start("roleplay_error_message")
            net.WriteString("Нельзя объявить войну: в городе нет мэра!")
            net.Send(ply)
            return
        end
        
        -- Устанавливаем состояние войны
        round.IsWarActive = true
        SetGlobalBool("IsWarActive", true)
        
        -- Создаем таймер на 10 минут
        timer.Create("WarTimer", 600, 1, function()
            if not round or round.name ~= "roleplay" then return end
            
            -- Автоматически заканчиваем войну через 10 минут
            round.IsWarActive = false
            SetGlobalBool("IsWarActive", false)

            -- Кулдаун 15 минут на следующую войну
            round.NextWarTime = CurTime() + 900
            
            -- Уведомляем всех игроков об окончании войны
            for _, p in player.Iterator() do
                if p:Team() ~= TEAM_SPECTATOR then
                    net.Start("roleplay_war_message")
                    net.WriteBool(false)
                    net.WriteInt(0, 32)
                    net.Send(p)
                end
            end
        end)
    else
        -- Если пытаемся закончить войну
        -- Проверяем, идет ли война
        if not round.IsWarActive then
            net.Start("roleplay_error_message")
            net.WriteString("Война не объявлена!")
            net.Send(ply)
            return
        end
        
        -- Устанавливаем состояние войны
        round.IsWarActive = false
        SetGlobalBool("IsWarActive", false)

        -- Кулдаун 15 минут на следующую войну
        round.NextWarTime = CurTime() + 900
        
        -- Удаляем таймер
        if timer.Exists("WarTimer") then
            timer.Remove("WarTimer")
        end
    end
    
    -- Уведомляем всех игроков о смене состояния войны
    for _, p in player.Iterator() do
        if p:Team() ~= TEAM_SPECTATOR then
            net.Start("roleplay_war_message")
            net.WriteBool(declareWar)
            net.WriteInt(declareWar and 600 or 0, 32)
            net.Send(p)
        end
    end
end)

-- ============================================
-- СИСТЕМА КОМЕНДАНТСКОГО ЧАСА
-- ============================================

-- Вспомогательная функция отмены комендантского часа
local function CancelCurfew(reason)
    local round = ZCity_RP -- [ZCITY_PORT]
    if not round.IsCurfewActive then return end

    round.IsCurfewActive = false
    round.CurfewReason   = ""
    SetGlobalBool("IsCurfewActive", false)
    SetGlobalString("CurfewReason", "")

    round.NextCurfewTime = CurTime() + 600

    if timer.Exists("CurfewTimer") then
        timer.Remove("CurfewTimer")
    end

    for _, p in player.Iterator() do
        if p:Team() ~= TEAM_SPECTATOR then
            net.Start("roleplay_curfew_message")
            net.WriteBool(false)
            net.WriteInt(0, 32)
            net.WriteString(reason or "")
            net.Send(p)
        end
    end
end
net.Receive("roleplay_declare_curfew", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]

    -- Только мэр может объявить комендантский час
    local jobName = ply.RoleplayJob or "Гражданский"
    if jobName ~= "Мэр" then
        net.Start("roleplay_error_message")
        net.WriteString("Только мэр может объявить комендантский час")
        net.Send(ply)
        return
    end

    if not ply:Alive() then
        net.Start("roleplay_error_message")
        net.WriteString("Вы должны быть живы для этого действия")
        net.Send(ply)
        return
    end

    local declare = net.ReadBool()
    local reason  = net.ReadString()

    if declare then
        -- Проверяем, не идёт ли уже комендантский час
        if round.IsCurfewActive then
            net.Start("roleplay_error_message")
            net.WriteString("Комендантский час уже объявлен!")
            net.Send(ply)
            return
        end

        -- Проверяем, не идёт ли война
        if round.IsWarActive then
            net.Start("roleplay_error_message")
            net.WriteString("Нельзя объявить комендантский час во время войны!")
            net.Send(ply)
            return
        end

        -- Проверяем кулдаун
        if round.NextCurfewTime and CurTime() < round.NextCurfewTime then
            local timeLeft = math.ceil(round.NextCurfewTime - CurTime())
            local m = math.floor(timeLeft / 60)
            local s = timeLeft % 60
            net.Start("roleplay_error_message")
            net.WriteString(string.format("Комендантский час недоступен. Попробуйте через %d:%02d", m, s))
            net.Send(ply)
            return
        end

        -- Обрезаем причину
        reason = string.sub(reason, 1, 120)
        if reason == "" then reason = "Не указана" end

        -- Активируем комендантский час
        round.IsCurfewActive = true
        round.CurfewReason   = reason
        SetGlobalBool("IsCurfewActive", true)
        SetGlobalString("CurfewReason", reason)

        -- Таймер на 300 секунд
        timer.Create("CurfewTimer", 300, 1, function()
            if not round or round.name ~= "roleplay" then return end
            CancelCurfew("timer_expired")
        end)

        -- Уведомляем всех об объявлении
        for _, p in player.Iterator() do
            if p:Team() ~= TEAM_SPECTATOR then
                net.Start("roleplay_curfew_message")
                net.WriteBool(true)
                net.WriteInt(300, 32)
                net.WriteString(reason)
                net.Send(p)
            end
        end
    else
        -- Отмена комендантского часа
        if not round.IsCurfewActive then
            net.Start("roleplay_error_message")
            net.WriteString("Комендантский час не объявлен!")
            net.Send(ply)
            return
        end

        CancelCurfew("cancel_by_mayor")
    end
end)

-- (роли util.AddNetworkString("roleplay_start") удалён — был зарегистрирован
--  ранее на строке 195, повторная регистрация бессмысленна и сорит)

-- Обработка выбора профессии
net.Receive("roleplay_select_job", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    local jobName = net.ReadString()
    
    -- Проверка на текущую профессию
    if ply.RoleplayJob == jobName then
        net.Start("roleplay_job_error")
        net.WriteString("У вас уже и так эта профессия")
        net.Send(ply)
        return
    end
    
    -- Проверка на кулдаун смены профессии
    if ply.NextJobChange and CurTime() < ply.NextJobChange then
        local timeLeft = math.ceil(ply.NextJobChange - CurTime())
        net.Start("roleplay_job_error")
        net.WriteString("Вы сможете сменить профессию через " .. timeLeft .. " сек.")
        net.Send(ply)
        return
    end
    
    -- Проверка блокировки профессии мэра
    if jobName == "Мэр" and ply.MayorBlockedUntil and CurTime() < ply.MayorBlockedUntil then
        local timeLeft = math.ceil(ply.MayorBlockedUntil - CurTime())
        local minutes = math.floor(timeLeft / 60)
        local seconds = timeLeft % 60
        net.Start("roleplay_job_error")
        net.WriteString(string.format("Профессия мэра заблокирована на %d:%02d", minutes, seconds))
        net.Send(ply)
        return
    end
    
    -- Проверка ULX блокировки профессии
    if ulx and ulx.IsJobBanned then
        local isBanned, timeLeft = ulx.IsJobBanned(ply, jobName)
        if isBanned then
            local hours = math.floor(timeLeft / 3600)
            local minutes = math.floor((timeLeft % 3600) / 60)
            local timeStr = hours > 0 and string.format("%dч %dм", hours, minutes) or minutes .. "м"
            net.Start("roleplay_job_error")
            net.WriteString("Профессия заблокирована администратором на " .. timeStr)
            net.Send(ply)
            return
        end
    end
    
    -- Таблица профессий для проверки
    local validJobs = {
        "Гражданский", "Полицейский", "Спецназ", "Мэр",
        "Глава Полиции", "Бандит", "Продавец Оружия",
        "Солдат ЦАХАЛ", "Глава ЦАХАЛ", "Медик"
    }
    
    local isValid = false
    for _, job in ipairs(validJobs) do
        if job == jobName then
            isValid = true
            break
        end
    end
    
    if not isValid then
        net.Start("roleplay_job_error")
        net.WriteString("Неверная профессия!")
        net.Send(ply)
        return
    end
    
    -- Проверка лимита профессии
    local jobData = round.Jobs[jobName]
    if jobData and jobData.limit and jobData.limit > 0 then
        -- Подсчитываем количество игроков с этой профессией
        local count = 0
        for _, p in player.Iterator() do
            if p:Team() ~= TEAM_SPECTATOR and p.RoleplayJob == jobName then
                count = count + 1
            end
        end
        
        -- Проверяем, не превышен ли лимит
        if count >= jobData.limit then
            net.Start("roleplay_job_error")
            net.WriteString("Достигнут лимит профессии " .. jobName .. " (" .. count .. "/" .. jobData.limit .. ")")
            net.Send(ply)
            return
        end
    end
    
    -- Если мэр сменил профессию — отменяем комендантский час
    local oldJob = ply.RoleplayJob
    if oldJob == "Мэр" and jobName ~= "Мэр" then
        CancelCurfew("mayor_job_changed")
    end

    ply.RoleplayJob = jobName
    ply.NextJobChange = CurTime() + 30 -- Кулдаун 30 секунд
    ply.ChangingJob = true -- блокирует "убит как мэр" в PlayerDeath

    -- [ZCITY_PORT] Меняем DarkRP-команду игрока (force=true), чтобы DarkRP-
    -- интерфейсы (F4-меню/scoreboard/agendas) знали актуальную профессию.
    --
    -- Порядок ВАЖЕН для корректного трупа со СТАРОЙ моделью:
    --   1. ply:Kill() — пока модель ещё старой профы → homigrad создаёт
    --      RagdollDeath со старой моделью (труп остаётся на месте смерти).
    --   2. changeTeam(teamID, true) — переключаем DarkRP-команду.
    --   3. timer.Simple(0.05, ply:Spawn()) — ply:Spawn вызывает PlayerLoadout
    --      с новой моделью/оружием, телепортирует на точку спавна новой профы.
    --   • Флаг ply.RP_InstantRespawn = true бипассит 15-секундный таймер.
    --
    -- КРИТИЧНО: перед Kill() ОТКЛЮЧАЕМ babygod (DarkRP даёт его на 5 сек после
    -- спавна). Иначе ply:Kill() ничего не делает (игрок неубиваем), changeTeam
    -- проходит без респавна, а флаг Babygod остаётся → следующая смерть
    -- оставляет годмод. Это и был баг "после смены профы на спавне остался годмод".
    if RPExtraTeams then
        for teamID, teamData in pairs(RPExtraTeams) do
            if teamData.name == jobName then
                local wasAlive = ply:Alive()
                local isSpec   = ply:Team() == TEAM_SPECTATOR

                if wasAlive and not isSpec then
                    -- 0. Снимаем babygod до Kill() чтобы реально убило
                    if ply.Babygod then
                        timer.Remove(ply:EntIndex() .. "babygod")
                        ply.Babygod = nil
                        if ply.GodDisable then ply:GodDisable() end
                        ply:SetRenderMode(RENDERMODE_NORMAL)
                        if ply.babyGodColor then
                            ply:SetColor(ply.babyGodColor)
                            ply.babyGodColor = nil
                        else
                            ply:SetColor(color_white)
                        end
                    end

                    -- 1. Сначала убиваем — труп со старой моделью
                    ply.RP_InstantRespawn = true -- бипассим 15-сек таймер
                    ply:Kill()
                end

                -- 2. Меняем DarkRP-команду
                if ply.changeTeam then
                    ply:changeTeam(teamID, true)
                end

                -- 3. Через тик возрождаем (для wasAlive) — игрок появится
                --    на точке спавна новой профы с новой моделью/оружием.
                if wasAlive and not isSpec then
                    timer.Simple(0.05, function()
                        if IsValid(ply) and not ply:Alive() then
                            ply:Spawn()
                        end
                        if IsValid(ply) then ply.ChangingJob = nil end
                    end)
                else
                    ply.ChangingJob = nil
                end
                break
            end
        end
    end

    -- Если игрок перестал быть Продавцом Оружия — удаляем его магазин с эффектом
    if jobName ~= "Продавец Оружия" then
        for _, ent in ipairs(ents.FindByClass("zb_gun_shop")) do
            if IsValid(ent) and ent:GetOwnerID() == ply:SteamID() then
                local effectData = EffectData()
                effectData:SetOrigin(ent:GetPos())
                effectData:SetEntity(ent)
                util.Effect("Disintegrate", effectData, true, true)
                timer.Simple(0.5, function()
                    if IsValid(ent) then ent:Remove() end
                end)
            end
        end
    end
    
    -- Синхронизируем профессию с клиентом
    ply:SetNWString("RoleplayJob", jobName)
    
    -- Синхронизируем цвет профессии с клиентом
    if jobData.color then
        ply:SetNWVector("RoleplayJobColor", Vector(jobData.color.r / 255, jobData.color.g / 255, jobData.color.b / 255))
    end
    
    -- Обновляем имя мэра если игрок стал мэром
    if jobName == "Мэр" then
        SetGlobalString("CityMayorName", ply:Nick())
    else
        -- Проверяем, есть ли другой мэр
        local hasMayor = false
        for _, p in player.Iterator() do
            if p ~= ply and p.RoleplayJob == "Мэр" and p:Team() ~= TEAM_SPECTATOR then
                hasMayor = true
                SetGlobalString("CityMayorName", p:Nick())
                break
            end
        end
        if not hasMayor then
            SetGlobalString("CityMayorName", "Отсутствует")
        end
    end
    
    -- Отправляем сообщение об успехе
    net.Start("roleplay_job_success")
    net.WriteString(jobName)
    net.Send(ply)

    -- [ZCITY_PORT] НЕ убиваем и не респавним игрока — DarkRP changeTeam (см. выше)
    -- уже обновил профессию. Старый скин/одежда остаются на теле до естественной
    -- смерти и следующего респавна. Это нужное поведение для RP.
    -- Старая логика (ply:Kill() → ply:Spawn() через 0.3с) удалена.
end)

-- Начало интермиссии
function MODE:Intermission()
    -- Сохраняем таблички ПЕРЕД очисткой карты
    if SaveCityTexts then
        SaveCityTexts()
    end
    
    self.LootTimer = CurTime() + 2
    game.CleanUpMap()
    
    self.RoleplayPoints = zb.GetMapPoints("ROLEPLAY_SPAWN")
    
    -- Инициализируем данные города
    self.CityTaxRate = self.CityTaxRate or 10
    self.CityTreasury = self.CityTreasury or 0
    self.CityRules = self.CityRules or "Правила города не установлены"
    self.IsWarActive = self.IsWarActive or false
    
    -- Устанавливаем глобальные переменные
    SetGlobalInt("CityTaxRate", self.CityTaxRate)
    SetGlobalInt("CityTreasury", self.CityTreasury)
    SetGlobalString("CityRules", self.CityRules)
    SetGlobalString("CityMayorName", "Отсутствует")
    SetGlobalBool("IsWarActive", self.IsWarActive)

    for k, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        ply:SetupTeam(0)
        
        -- Присваиваем профессию "Гражданский" по умолчанию
        if not ply.RoleplayJob then
            ply.RoleplayJob = "Гражданский"
        end
    end
    
    -- Отправляем сообщение клиентам
    net.Start("roleplay_start")
    net.Broadcast()
    
    -- Отправляем данные о дверях всем игрокам
    timer.Simple(1, function()
        zb.SendDoors()
    end)
end

-- БЕСКОНЕЧНЫЙ РЕЖИМ - игроки всегда могут респавниться
function MODE:CheckAlivePlayers()
    -- Ничего не делаем - режим бесконечный
end

-- БЕСКОНЕЧНЫЙ РЕЖИМ - раунд НИКОГДА не заканчивается
function MODE:ShouldRoundEnd()
    return false -- Режим никогда не заканчивается!
end

-- Начало раунда
function MODE:RoundStart()
    -- Инициализация при старте раунда
    
    -- Загружаем точки спавна машин
    if zb.LoadCarSpawns then
        zb.LoadCarSpawns()
    end
    
    -- Спавним все фракционные машины
    timer.Simple(1, function()
        if zb.CarSpawns then
            for id, spawn in pairs(zb.CarSpawns) do
                if not IsValid(spawn.vehicle) then
                    zb.SpawnCar(id)
                end
            end
        end
    end)
    
    -- НЕ загружаем таблички здесь - они уже загружены при старте карты
    -- и восстанавливаются автоматически после CleanUpMap
end

-- Получение позиции спавна
function MODE:GetSpawnPos(ply)
    local tab = {}
    
    -- Получаем профессию игрока
    local jobName = ply.RoleplayJob or "Гражданский"
    local job = self.Jobs[jobName]
    
    if not job then
        jobName = "Гражданский"
        job = self.Jobs[jobName]
    end
    
    -- Пытаемся использовать точки спавна профессии
    local jobSpawns = zb.GetMapPoints(job.pointGroup) or {}
    for k, v in pairs(jobSpawns) do
        if v.pos then
            tab[#tab + 1] = v.pos
        end
    end
    
    -- Если нет точек профессии, используем общие точки
    if #tab == 0 then
        local roleplaySpawns = zb.GetMapPoints("ROLEPLAY_SPAWN") or {}
        for k, v in pairs(roleplaySpawns) do
            if v.pos then
                tab[#tab + 1] = v.pos
            end
        end
    end
    
    -- Если нет кастомных точек, используем стандартные
    if #tab == 0 then
        local tbl = ents.FindByClass("info_player_start")
        for k, v in pairs(tbl) do
            tab[#tab + 1] = v:GetPos()
        end
    end
    
    -- Если и стандартных нет, используем дефолтную позицию
    if #tab == 0 then
        tab[#tab + 1] = Vector(0, 0, 0)
    end
    
    -- Возвращаем случайную точку из доступных
    return tab[math.random(1, #tab)] or Vector(0, 0, 0)
end

function MODE:GetPlySpawn(ply)
    local pos = self:GetSpawnPos(ply)
    ply:SetPos(pos)
    return pos
end

function MODE:GetTeamSpawn()
    local dummyPly = player.GetAll()[1]
    if not dummyPly then return {Vector(0,0,0)}, {Vector(0,0,0)} end
    return {self:GetSpawnPos(dummyPly)}, {self:GetSpawnPos(dummyPly)}
end

-- Цвета для ролей (из конфига или дефолтные)
local clr_citizen = ROLEPLAY_COLORS and ROLEPLAY_COLORS.citizen or Color(100, 200, 100)
local clr_refugee = ROLEPLAY_COLORS and ROLEPLAY_COLORS.refugee or Color(200, 150, 50)
local clr_rebel = ROLEPLAY_COLORS and ROLEPLAY_COLORS.rebel or Color(255, 100, 50)

-- Выдача экипировки игрокам
function MODE:GiveEquipment()
    local modeJobs = self.Jobs -- Сохраняем ссылку на таблицу профессий
    
    timer.Simple(0, function()
        local players = player.GetAll()
        
        for _, ply in RandomPairs(players) do
            if not ply:Alive() then continue end

            ply:SetSuppressPickupNotices(true)
            ply.noSound = true

            -- Получаем профессию игрока
            local jobName = ply.RoleplayJob or "Гражданский"
            local job = modeJobs[jobName]
            
            if not job then
                jobName = "Гражданский"
                job = modeJobs[jobName]
                ply.RoleplayJob = jobName
            end

            -- Даем инвентарь
            local inv = ply:GetNetVar("Inventory")
            inv["Weapons"] = inv["Weapons"] or {}
            inv["Weapons"]["hg_sling"] = true
            inv["Weapons"]["hg_flashlight"] = true
            ply:SetNetVar("Inventory", inv)

            -- Устанавливаем класс игрока
            ply:SetPlayerClass("Refugee", {bNoEquipment = true})
            zb.GiveRole(ply, jobName, job.color)

            -- Даем руки всем по умолчанию
            ply:Give("weapon_hands_sh")
            ply:SelectWeapon("weapon_hands_sh")
            
            -- Даем оружие профессии
            for _, weapon in ipairs(job.weapons) do
                local wep = ply:Give(weapon)
                
                -- Даем 2 обоймы патронов к оружию
                if IsValid(wep) and wep.Primary and wep.Primary.Ammo then
                    local ammoType = wep.Primary.Ammo
                    local clipSize = wep.Primary.ClipSize or 30
                    
                    if clipSize > 0 then
                        ply:GiveAmmo(clipSize * 2, ammoType, true)
                    end
                end
            end

            -- Спавним игрока на точке его профессии
            local pos = self:GetPlySpawn(ply)

            timer.Simple(0.1, function()
                if IsValid(ply) then
                    ply.noSound = false
                    ply:SetSuppressPickupNotices(false)
                end
            end)
        end
    end)
end

-- Конец раунда
function MODE:EndRound()
    -- Сохраняем таблички
    if SaveCityTexts then
        SaveCityTexts()
    end
end

-- Логика раунда
function MODE:RoundThink()
    -- [ZCITY_PORT] Автоматический респавн через RoundThink ОТКЛЮЧЁН.
    -- Раньше каждую секунду проверялся CurTime() >= ply.NextRespawn и
    -- вызывался ply:Spawn(). Это давало два конкурирующих таймера (вместе
    -- с zcity_rp_respawn/sv_respawn_delay.lua), и в редких случаях игрок
    -- спавнился раньше времени (за 4 сек вместо 15) или дважды.
    -- Теперь точный таймер ровно один — timer.Create в sv_respawn_delay.lua.

    -- Проверка смерти мэра во время войны
    if self.IsWarActive then
        local mayorAlive = false
        for _, ply in player.Iterator() do
            if ply:Team() ~= TEAM_SPECTATOR and ply:Alive() then
                local jobName = ply.RoleplayJob or "Гражданский"
                if jobName == "Мэр" then
                    mayorAlive = true
                    break
                end
            end
        end
        
        -- Если мэр мертв, заканчиваем войну
        if not mayorAlive then
            self.IsWarActive = false
            SetGlobalBool("IsWarActive", false)

            -- Кулдаун 15 минут на следующую войну
            self.NextWarTime = CurTime() + 900
            
            -- Удаляем таймер войны
            if timer.Exists("WarTimer") then
                timer.Remove("WarTimer")
            end
            
            -- Уведомляем всех игроков о победе ЦАХАЛ
            for _, p in player.Iterator() do
                if p:Team() ~= TEAM_SPECTATOR then
                    net.Start("roleplay_war_message")
                    net.WriteBool(false)
                    net.WriteInt(0, 32)
                    net.WriteString("isis_victory")
                    net.Send(p)
                end
            end
        end
    end
    
    -- Система выплаты зарплаты каждые 5 минут
    self.NextSalaryPayment = self.NextSalaryPayment or CurTime() + 300 -- 300 секунд = 5 минут
    
    if CurTime() >= self.NextSalaryPayment then
        self.NextSalaryPayment = CurTime() + 300
        
        -- Выплачиваем зарплату всем живым игрокам
        for _, ply in player.Iterator() do
            if ply:Team() ~= TEAM_SPECTATOR and ply:Alive() then
                local jobName = ply.RoleplayJob or "Гражданский"
                local job = self.Jobs[jobName]
                
                if job and job.salary then
                    -- Вычисляем налог
                    local taxRate = self.CityTaxRate or 0
                    local taxAmount = math.floor(job.salary * (taxRate / 100))
                    local salaryAfterTax = job.salary - taxAmount
                    
                    -- Добавляем налог в казну
                    if taxAmount > 0 then
                        self.CityTreasury = (self.CityTreasury or 0) + taxAmount
                        SetGlobalInt("CityTreasury", self.CityTreasury)
                    end
                    
                    -- Выплачиваем зарплату
                    self:AddMoney(ply, salaryAfterTax, "salary")

                    -- Цветное сообщение о зарплате
                    net.Start("roleplay_salary_message")
                    net.WriteInt(salaryAfterTax, 16)
                    net.WriteInt(taxAmount, 16)
                    net.Send(ply)
                end
            end
        end
    end
end

-- Проверка возможности спавна
function MODE:CanSpawn()
    return true -- Всегда можно заспавниться
end

-- Проверка возможности запуска режима
function MODE:CanLaunch()
    return true -- Режим всегда доступен
end

-- Хук для предотвращения урона по союзникам (опционально)
hook.Add("EntityTakeDamage", "RoleplayFriendlyFire", function(ent, dmginfo)
    -- [ZCITY_PORT] было: проверка raund=='roleplay'; теперь всегда true
    
    local att = dmginfo:GetAttacker()
    if IsValid(ent) and IsValid(att) and att:IsPlayer() and ent:IsPlayer() then
        -- Можно добавить логику для дружественного огня
        -- Например, уменьшить урон или полностью его убрать
    end
end)

-- Хук для логики при смерти (мэр-блок, отмена ограбления).
-- Сам респавн-таймер отправляет sv_respawn_delay.lua — здесь только бизнес-логика.
hook.Add("PlayerDeath", "RoleplayAutoRespawn", function(victim, inflictor, attacker)
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    
    if IsValid(victim) and victim:IsPlayer() then
        -- Бипасс: при смене профы Spawn() будет вызван моментально
        if victim.RP_InstantRespawn then return end

        -- Отменяем ограбление если игрок умер
        if victim.RobbingTreasury then
            victim.RobbingTreasury = false
            timer.Remove("RobberyTimer_" .. victim:SteamID())
            
            -- Отправляем отмену ограбления
            net.Start("roleplay_robbery_cancel")
            net.Send(victim)
            
            -- Уведомляем всех о провале
            for _, p in player.Iterator() do
                if p:Team() ~= TEAM_SPECTATOR then
                    net.Start("roleplay_colored_message")
                    net.WriteString("robbery_failed")
                    net.WriteString(victim:Nick())
                    net.Send(p)
                end
            end
        end
        
        -- Если убили мэра - блокируем профессию на 5 минут
        local jobName = victim.RoleplayJob or "Гражданский"
        if jobName == "Мэр" and not victim.ChangingJob then
            -- Переводим на гражданского сразу. Дополнительно дублируем
            -- через 0.1 сек на случай если другой хук перезапишет профу
            -- между PlayerDeath и PlayerSpawn — мэр должен 100% стать
            -- гражданским после смерти.
            victim.RoleplayJob = "Гражданский"
            victim:SetNWString("RoleplayJob", "Гражданский")

            -- DarkRP team тоже сразу меняем — иначе после респавна DarkRP
            -- может попытаться загрузить лоадаут мэра по сохранённому team.
            if victim.changeTeam then
                pcall(victim.changeTeam, victim, TEAM_CITIZEN or 1, true, true)
            elseif victim.SetTeam then
                victim:SetTeam(TEAM_CITIZEN or 1)
            end

            -- Подстраховка через тик
            timer.Simple(0.1, function()
                if IsValid(victim) and victim.RoleplayJob == "Мэр" then
                    victim.RoleplayJob = "Гражданский"
                    victim:SetNWString("RoleplayJob", "Гражданский")
                end
            end)

            -- Блокируем профессию мэра на 5 минут
            victim.MayorBlockedUntil = CurTime() + 300

            -- Уведомляем игрока
            timer.Simple(1, function()
                if IsValid(victim) then
                    net.Start("roleplay_error_message")
                    net.WriteString("Вы были убиты как мэр! Профессия заблокирована на 5 минут")
                    net.Send(victim)
                end
            end)

            -- Обновляем имя мэра
            SetGlobalString("CityMayorName", "Отсутствует")

            -- Отменяем комендантский час если он был активен
            CancelCurfew("mayor_died")
        end

        -- victim.NextRespawn / отправку таймера убрали:
        -- этим занимается sv_respawn_delay.lua (точный timer.Create на 15 сек).
    end
end)

-- Хук для удаления трупа через 30 секунд
hook.Add("PostPlayerDeath", "RoleplayRemoveRagdoll", function(ply)
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    
    -- Получаем рэгдолл игрока
    local ragdoll = ply:GetNWEntity("RagdollDeath")
    
    if IsValid(ragdoll) then
        timer.Simple(30, function()
            if IsValid(ragdoll) then
                ragdoll:Remove()
            end
        end)
    end
end)

-- Хук для сброса таймера респавна при спавне и установки позиции
hook.Add("PlayerSpawn", "RoleplayResetRespawn", function(ply)
    if OverrideSpawn then return end
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true

    if not IsValid(ply) then return end

    -- Если игрок в спектаторах — НЕ выдаём оружие, не меняем модель, не
    -- ставим спавн-точку. PlayerSpawn у спектатора всё равно срабатывает
    -- (DarkRP/Sandbox), но любые `ply:Give(...)` падают с runtime error
    -- т.к. у TEAM_SPECTATOR нет валидного getJobTable().
    if ply:Team() == TEAM_SPECTATOR then return end

    ply.NextRespawn = nil
    ply.fakecd = CurTime() + 3 -- Запрещаем баговать рагдол при спавне и телепортироваться на место камеры
    
    -- Присваиваем профессию "Гражданский" по умолчанию, если её нет
    if not ply.RoleplayJob then
        ply.RoleplayJob = "Гражданский"
    end
    
    -- Синхронизируем профессию и цвет с клиентом
    local round = ZCity_RP
    if round and round.Jobs then
        local jobName = ply.RoleplayJob or "Гражданский"
        local job = round.Jobs[jobName]
        
        if job then
            ply:SetNWString("RoleplayJob", jobName)
            
            -- Синхронизируем цвет профессии
            if job.color then
                ply:SetNWVector("RoleplayJobColor", Vector(job.color.r / 255, job.color.g / 255, job.color.b / 255))
            end
        end
    end
    
    -- Устанавливаем позицию спавна на точке профессии и выдаем экипировку
    timer.Simple(0.1, function()
        if IsValid(ply) and ply:Alive() and ply:Team() ~= TEAM_SPECTATOR then
            local round = ZCity_RP
            
            -- Получаем профессию и устанавливаем класс игрока
            local jobName = ply.RoleplayJob or "Гражданский"
            if round and round.Jobs and round.Jobs[jobName] then
                local job = round.Jobs[jobName]
                
                -- Устанавливаем класс игрока (он сам установит модель и аксессуары)
                if job.playerClass then
                    ply:SetPlayerClass(job.playerClass, {bNoEquipment = true})

                    -- Если профессия использует настраиваемую внешность
                    if job.useAppearance then
                        -- Применяем внешность игрока
                        timer.Simple(0.2, function()
                            if IsValid(ply) then
                                ApplyAppearance(ply, nil, nil, nil, true)
                            end
                        end)
                    end
                else
                    -- Если нет класса, устанавливаем модель вручную
                    if job.models and #job.models > 0 then
                        local randomModel = job.models[math.random(1, #job.models)]
                        ply:SetModel(randomModel)
                        
                        -- Полностью сбрасываем цвет и материалы
                        ply:SetPlayerColor(Vector(1, 1, 1))
                        ply:SetColor(Color(255, 255, 255, 255))
                        
                        -- Сбрасываем все материалы
                        for i = 0, 20 do
                            ply:SetSubMaterial(i, nil)
                        end
                        
                        -- Сбрасываем основной материал
                        ply:SetMaterial("")
                    end
                end
                
                -- Устанавливаем роль с цветом
                zb.GiveRole(ply, jobName, job.color)
            end
            
            -- Выдаем руки
            if not ply:HasWeapon("weapon_hands_sh") then
                ply:Give("weapon_hands_sh")
            end
            
            -- Выдаем оружие профессии
            -- Флаг RP_GivingWeapons блокирует наш WeaponEquip хук (защита спавна),
            -- иначе он отберёт только что выданное оружие т.к. игрок в зоне спавна.
            ply.RP_GivingWeapons = true
            if round and round.Jobs and round.Jobs[jobName] then
                local job = round.Jobs[jobName]
                for _, weapon in ipairs(job.weapons) do
                    if not ply:HasWeapon(weapon) then
                        local wep = ply:Give(weapon)
                        
                        -- Устанавливаем частоту рации
                        if IsValid(wep) and weapon == "weapon_walkie_talkie" and job.radioFrequency then
                            wep.Frequency = job.radioFrequency
                        end
                        
                        -- Даем 2 обоймы патронов к оружию
                        if IsValid(wep) and wep.Primary and wep.Primary.Ammo then
                            local ammoType = wep.Primary.Ammo
                            local clipSize = wep.Primary.ClipSize or 30
                            
                            if clipSize > 0 then
                                ply:GiveAmmo(clipSize * 2, ammoType, true)
                            end
                        end
                    end
                end
                
                -- Надеваем броню
                -- ОТКЛЮЧЕНО: броню выдаёт sv_loadout.lua через PlayerLoadout
                -- (ZCity_JobArmor[jobName]). Двойная выдача приводила к тому,
                -- что hg.AddArmor видел уже надетую первым вызовом броню,
                -- дропал её в мир и надевал новый комплект.
                -- if job.armor then
                --     hg.AddArmor(ply, job.armor)
                -- end
            end

            -- Выдача админ-инструментов: dadmin+ получают физган и тулган
            -- чтобы Q-меню (spawnmenu) работало в полном объёме.
            local ADMIN_TOOLS_GROUPS = {
                dadmin      = true,
                admin       = true,
                superadmin  = true,
                dsuperadmin = true,
                operator    = true,
            }
            if ADMIN_TOOLS_GROUPS[ply:GetUserGroup()] then
                if not ply:HasWeapon("weapon_physgun") then ply:Give("weapon_physgun") end
                if not ply:HasWeapon("gmod_tool")      then ply:Give("gmod_tool")      end
            end

            -- Снимаем флаг через тик — все WeaponEquip уже отработали.
            timer.Simple(0.05, function()
                if IsValid(ply) then ply.RP_GivingWeapons = nil end
            end)

            -- Выбираем руки
            ply:SelectWeapon("weapon_hands_sh")

            -- Устанавливаем позицию спавна ПОСЛЕ всех манипуляций.
            -- Сохраняем точку спавна в ply.RP_SpawnPos — она используется
            -- хуком PlayerSwitchWeapon ниже для зонной защиты от доставания
            -- оружия (пока игрок в радиусе ROLEPLAY_SPAWN_PROTECT_RADIUS).
            timer.Simple(0.1, function()
                if IsValid(ply) and ply:Alive() then
                    local round = ZCity_RP
                    local pos
                    if ply.ulx_ragdoll_tp_pos then
                        pos = ply.ulx_ragdoll_tp_pos
                        ply.ulx_ragdoll_tp_pos = nil
                    elseif round and round.GetSpawnPos then
                        pos = round:GetSpawnPos(ply)
                    end
                    if pos then
                        ply:SetPos(pos)
                        ply.RP_SpawnPos = pos
                        ply:SelectWeapon("weapon_hands_sh")
                    end
                end
            end)
        end
    end)
end)

-- Хук для присвоения профессии при подключении игрока
hook.Add("PlayerInitialSpawn", "RoleplaySetDefaultJob", function(ply)
    ply.RoleplayJob = "Гражданский"
    
    -- Синхронизируем профессию с клиентом
    timer.Simple(0.1, function()
        if IsValid(ply) then
            ply:SetNWString("RoleplayJob", "Гражданский")
            
            -- Синхронизируем цвет профессии
            local round = ZCity_RP
            if round and round.Jobs and round.Jobs["Гражданский"] then
                local job = round.Jobs["Гражданский"]
                if job.color then
                    ply:SetNWVector("RoleplayJobColor", Vector(job.color.r / 255, job.color.g / 255, job.color.b / 255))
                end
            end
        end
    end)
    
    -- Загружаем деньги и синхронизируем после загрузки (асинхронно)
    local function syncAfterLoad(money)
        if not IsValid(ply) then return end

        net.Start("roleplay_sync_money")
        net.WriteInt(money, 32)
        net.Send(ply)

        local round = ZCity_RP

        -- Синхронизируем состояние войны
        if round and round.name == "roleplay" and round.IsWarActive then
            local warTimeLeft = 600
            if timer.Exists("WarTimer") then
                warTimeLeft = math.max(0, math.ceil(timer.TimeLeft("WarTimer")))
            end
            net.Start("roleplay_war_message")
            net.WriteBool(true)
            net.WriteInt(warTimeLeft, 32)
            net.Send(ply)
        end

        -- Синхронизируем состояние комендантского часа
        if round and round.name == "roleplay" and round.IsCurfewActive then
            local curfewTimeLeft = 300
            if timer.Exists("CurfewTimer") then
                curfewTimeLeft = math.max(0, math.ceil(timer.TimeLeft("CurfewTimer")))
            end
            net.Start("roleplay_curfew_message")
            net.WriteBool(true)
            net.WriteInt(curfewTimeLeft, 32)
            net.WriteString(round.CurfewReason or "")
            net.Send(ply)
        end
    end

    if true then
        LoadPlayerMoney(ply, syncAfterLoad)
    else
        ply.RoleplayMoney = 5000
        timer.Simple(1, function() syncAfterLoad(5000) end)
    end
end)

-- Хук для сброса профессии при переходе в спектаторы
hook.Add("PlayerChangedTeam", "RoleplaySpectatorJobReset", function(ply, oldTeam, newTeam)
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    
    -- Если игрок перешел в спектаторы
    if newTeam == TEAM_SPECTATOR then
        -- Убираем профессию
        local oldJob = ply.RoleplayJob
        ply.RoleplayJob = nil
        ply:SetNWString("RoleplayJob", "")
        
        -- Отменяем таймер респавна
        ply.NextRespawn = nil

        -- Если мэр ушёл в спектаторы — отменяем комендантский час
        if oldJob == "Мэр" then
            CancelCurfew("mayor_spectator")
        end

        -- Удаляем магазин оружия с эффектом
        local steamID = ply:SteamID()
        for _, ent in ipairs(ents.FindByClass("zb_gun_shop")) do
            if IsValid(ent) and ent:GetOwnerID() == steamID then
                local effectData = EffectData()
                effectData:SetOrigin(ent:GetPos())
                effectData:SetEntity(ent)
                util.Effect("Disintegrate", effectData, true, true)
                timer.Simple(0.5, function()
                    if IsValid(ent) then ent:Remove() end
                end)
            end
        end
        
        print("[ZBattle] Игрок " .. ply:Name() .. " перешел в спектаторы, профессия сброшена")
    end
    
    -- Если игрок вышел из спектаторов
    if oldTeam == TEAM_SPECTATOR and newTeam ~= TEAM_SPECTATOR then
        -- Присваиваем профессию "Гражданский"
        ply.RoleplayJob = "Гражданский"
        ply:SetNWString("RoleplayJob", "Гражданский")
        
        -- Синхронизируем цвет профессии
        local round = ZCity_RP
        if round and round.Jobs and round.Jobs["Гражданский"] then
            local job = round.Jobs["Гражданский"]
            if job.color then
                ply:SetNWVector("RoleplayJobColor", Vector(job.color.r / 255, job.color.g / 255, job.color.b / 255))
            end
        end
        
        print("[ZBattle] Игрок " .. ply:Name() .. " вышел из спектаторов, присвоена профессия Гражданский")
        
        -- Респавним игрока
        timer.Simple(0.1, function()
            if IsValid(ply) and not ply:Alive() then
                ply:Spawn()
            end
        end)
    end
end)

-- [ZCITY_PORT] СТАРЫЕ ФУНКЦИИ ОТКЛЮЧЕНЫ — теперь работает ZCity_RP:AddMoney/TakeMoney/GetMoney
-- из darkrp_modules/zcity_rp_core/sh_zcity_rp_namespace.lua, проброс на DarkRP-кошелёк.
-- Старые версии оставлены как _ZCity_OLD_* для отката если потребуется.

function MODE._ZCity_OLD_AddMoney(self, ply, amount, reason, targetPly)
    if not IsValid(ply) then return end

    ply.RoleplayMoney = (ply.RoleplayMoney or 5000) + amount

    -- Синхронизируем с клиентом
    net.Start("roleplay_sync_money")
    net.WriteInt(ply.RoleplayMoney, 32)
    net.Send(ply)

    -- Автосохранение при изменении денег
    SavePlayerMoney(ply)

    -- Логируем изменение денег (хук для Discord-логгера и др. слушателей)
    hook.Run("RoleplayMoneyChange", ply, amount, reason or "add", targetPly)

    return ply.RoleplayMoney
end

-- Функция для снятия денег у игрока
function MODE._ZCity_OLD_TakeMoney(self, ply, amount, reason, targetPly)
    if not IsValid(ply) then return false end

    ply.RoleplayMoney = ply.RoleplayMoney or 5000

    if ply.RoleplayMoney >= amount then
        ply.RoleplayMoney = ply.RoleplayMoney - amount

        -- Синхронизируем с клиентом
        net.Start("roleplay_sync_money")
        net.WriteInt(ply.RoleplayMoney, 32)
        net.Send(ply)

        -- Автосохранение при изменении денег
        SavePlayerMoney(ply)

        -- Логируем изменение денег
        hook.Run("RoleplayMoneyChange", ply, -amount, reason or "take", targetPly)

        return true
    end

    return false
end

-- Функция для получения денег игрока
function MODE._ZCity_OLD_GetMoney(self, ply)
    if not IsValid(ply) then return 0 end
    return ply.RoleplayMoney or 5000
end

-- ============================================
-- [ZCITY_PORT] СИСТЕМА СОХРАНЕНИЯ ДЕНЕГ (MySQL) — УДАЛЕНА
-- ============================================
-- Раньше тут были SavePlayerMoney/LoadPlayerMoney/InitDatabase + подключение к
-- внешней базе pw769_money на УКАЖИТЕ_IP_БД. Теперь деньги хранит DarkRP
-- (SQLite по умолчанию, sv.db). Миграция старых балансов делается один раз
-- через addons/darkrpmodification/lua/darkrp_modules/zcity_rp_money/sv_money_migration.lua.
-- Пустые stubs функций оставляем чтобы не падал старый код.
-- LoadPlayerMoney возвращает текущий DarkRP-кошелёк (deferred until DarkRP money loaded).
function LoadPlayerMoney(ply, callback)
    if not IsValid(ply) then if callback then callback(0) end return end
    -- DarkRP грузит деньги асинхронно тоже. Дадим ему 1.5 сек, потом отдадим текущее значение.
    timer.Simple(1.5, function()
        if not IsValid(ply) then return end
        local money = ply.getDarkRPVar and ply:getDarkRPVar("money") or 0
        ply.RoleplayMoney = money
        ply.RoleplayMoneyLoaded = true
        if callback then callback(money) end
    end)
end
function SavePlayerMoney(ply, callback) if callback then callback(true) end end
function SaveAllPlayerMoney() end
_G.RoleplayMoneyLog = function() end
_G.RoleplayMoneySnapshot = function() end

-- ============================================
-- СИСТЕМА ДВЕРЕЙ
-- ============================================

-- Обработчик покупки двери
net.Receive("zb_door_buy", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    local door = net.ReadEntity()
    
    if not IsValid(door) or not IsValid(ply) or not ply:Alive() then return end
    
    -- Проверяем расстояние до двери
    local doorPos = door:LocalToWorld(door:OBBCenter())
    if ply:GetPos():Distance(doorPos) > 150 then
        net.Start("roleplay_error_message")
        net.WriteString("Вы слишком далеко от двери")
        net.Send(ply)
        return
    end
    
    local doorData = zb.GetDoorData(door)
    
    if not doorData then
        net.Start("roleplay_error_message")
        net.WriteString("Эта дверь не продается")
        net.Send(ply)
        return
    end
    
    -- Проверяем тип двери
    if doorData.type ~= "buyable" then
        net.Start("roleplay_error_message")
        net.WriteString("Эта дверь не продается")
        net.Send(ply)
        return
    end
    
    -- Проверяем, не занята ли дверь
    if doorData.owner then
        net.Start("roleplay_error_message")
        net.WriteString("Эта дверь уже куплена")
        net.Send(ply)
        return
    end
    
    -- Получаем все двери в группе
    local doorKeysToBuy = {}
    if doorData.groupID then
        doorKeysToBuy = zb.GetDoorsInGroup(doorData.groupID)
    else
        -- Если нет группы, покупаем только эту дверь
        local fp = zb.GetDoorFingerprint(door)
        if fp then
            table.insert(doorKeysToBuy, zb.GetDoorKey(fp))
        end
    end
    
    -- Проверяем, что все двери в группе свободны
    for _, doorKey in ipairs(doorKeysToBuy) do
        local data = zb.Doors[doorKey]
        if data and data.owner then
            net.Start("roleplay_error_message")
            net.WriteString("Одна из дверей в группе уже куплена")
            net.Send(ply)
            return
        end
    end
    
    -- Проверяем деньги
    local price = 200
    ply.RoleplayMoney = ply.RoleplayMoney or 5000
    
    if ply.RoleplayMoney < price then
        net.Start("roleplay_error_message")
        net.WriteString("Недостаточно денег (нужно " .. price .. "$)")
        net.Send(ply)
        return
    end
    
    -- Покупаем все двери в группе
    round:TakeMoney(ply, price, "purchase")
    
    for _, doorKey in ipairs(doorKeysToBuy) do
        local data = zb.Doors[doorKey]
        if data then
            data.owner = ply:SteamID()
            data.ownerName = ply:Nick()
            data.locked = false
        end
    end
    
    zb.SaveDoors()
    zb.SendDoors()
    
    -- Цветное сообщение
    if #doorKeysToBuy > 1 then
        net.Start("roleplay_door_message")
        net.WriteString("buy_group")
        net.WriteInt(#doorKeysToBuy, 8)
        net.WriteInt(price, 16)
        net.Send(ply)
    else
        net.Start("roleplay_door_message")
        net.WriteString("buy")
        net.WriteInt(price, 16)
        net.Send(ply)
    end
end)

-- Обработчик продажи двери
net.Receive("zb_door_sell", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    local door = net.ReadEntity()
    
    if not IsValid(door) or not IsValid(ply) or not ply:Alive() then return end
    
    -- Проверяем расстояние до двери
    local doorPos = door:LocalToWorld(door:OBBCenter())
    if ply:GetPos():Distance(doorPos) > 150 then
        net.Start("roleplay_error_message")
        net.WriteString("Вы слишком далеко от двери")
        net.Send(ply)
        return
    end
    
    local doorData = zb.GetDoorData(door)
    
    if not doorData or doorData.owner ~= ply:SteamID() then
        net.Start("roleplay_error_message")
        net.WriteString("Это не ваша дверь")
        net.Send(ply)
        return
    end
    
    -- Получаем все двери в группе
    local doorKeysToSell = {}
    if doorData.groupID then
        doorKeysToSell = zb.GetDoorsInGroup(doorData.groupID)
    else
        local fp = zb.GetDoorFingerprint(door)
        if fp then
            table.insert(doorKeysToSell, zb.GetDoorKey(fp))
        end
    end
    
    -- Продаем все двери в группе (возвращаем 50% стоимости)
    local refund = 100
    round:AddMoney(ply, refund, "sale")
    
    for _, doorKey in ipairs(doorKeysToSell) do
        local data = zb.Doors[doorKey]
        if data then
            data.owner = nil
            data.ownerName = nil
            data.locked = false
        end
    end
    
    zb.SaveDoors()
    zb.SendDoors()
    
    -- Цветное сообщение
    if #doorKeysToSell > 1 then
        net.Start("roleplay_door_message")
        net.WriteString("sell_group")
        net.WriteInt(#doorKeysToSell, 8)
        net.WriteInt(refund, 16)
        net.Send(ply)
    else
        net.Start("roleplay_door_message")
        net.WriteString("sell")
        net.WriteInt(refund, 16)
        net.Send(ply)
    end
end)

-- Обработчик блокировки/разблокировки двери
net.Receive("zb_door_lock", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    local door = net.ReadEntity()
    
    if not IsValid(door) or not IsValid(ply) or not ply:Alive() then return end
    
    -- Проверяем расстояние до двери
    local doorPos = door:LocalToWorld(door:OBBCenter())
    if ply:GetPos():Distance(doorPos) > 150 then
        return
    end
    
    local doorData = zb.GetDoorData(door)
    
    if not doorData then return end
    
    -- Проверяем права на дверь
    local canUse = false
    local jobName = ply.RoleplayJob or "Гражданский"
    
    -- Владелец может использовать свою дверь
    if doorData.type == "buyable" and doorData.owner == ply:SteamID() then
        canUse = true
    end
    
    -- Полиция, спецназ и глава полиции могут использовать полицейские двери и двери мэрии
    if doorData.type == "police" and (jobName == "Полицейский" or jobName == "Спецназ" or jobName == "Глава Полиции") then
        canUse = true
    end
    
    if doorData.type == "mayor" and (jobName == "Полицейский" or jobName == "Спецназ" or jobName == "Глава Полиции") then
        canUse = true
    end
    
    -- Мэр может использовать двери мэрии и полицейские двери
    if doorData.type == "mayor" and jobName == "Мэр" then
        canUse = true
    end
    
    if doorData.type == "police" and jobName == "Мэр" then
        canUse = true
    end
    
    -- ЦАХАЛ может использовать двери игила
    if doorData.type == "isis" and (jobName == "Солдат ЦАХАЛ" or jobName == "Глава ЦАХАЛ") then
        canUse = true
    end
    
    if not canUse then
        net.Start("roleplay_error_message")
        net.WriteString("У вас нет доступа к этой двери")
        net.Send(ply)
        return
    end
    
    -- Анимация использования ключа
    ply:DoAnimationEvent(ACT_GMOD_GESTURE_ITEM_PLACE)
    
    -- Получаем все двери в группе
    local doorKeysToLock = {}
    if doorData.groupID then
        doorKeysToLock = zb.GetDoorsInGroup(doorData.groupID)
    else
        local fp = zb.GetDoorFingerprint(door)
        if fp then
            table.insert(doorKeysToLock, zb.GetDoorKey(fp))
        end
    end

    -- Добавляем напрямую связанные двери (door_link tool)
    if zb.DoorLinks then
        local seen = {}
        for _, k in ipairs(doorKeysToLock) do seen[k] = true end

        local toAdd = {}
        for _, k in ipairs(doorKeysToLock) do
            local linked = zb.DoorLinks[k]
            if linked and not seen[linked] then
                seen[linked] = true
                table.insert(toAdd, linked)
            end
        end
        for _, k in ipairs(toAdd) do
            table.insert(doorKeysToLock, k)
        end
    end
    
    -- Переключаем состояние блокировки для всех дверей в группе.
    -- Источник правды — РЕАЛЬНОЕ состояние замка под прицелом (m_bLocked),
    -- а не сохранённый doorData.locked. Это решает проблему рассинхрона:
    -- если кеш расходится с движком (после сноса/Fire из карты/итд),
    -- кнопка "Закрыть" иногда не закрывала дверь т.к. в кеше она
    -- "уже закрыта", и не было toggle.
    local realLocked
    do
        local mb = door:GetInternalVariable("m_bLocked")
        if mb ~= nil then realLocked = mb end
    end
    if realLocked == nil then realLocked = doorData.locked or false end

    local newLockState = not realLocked

    for _, doorKey in ipairs(doorKeysToLock) do
        local data = zb.Doors[doorKey]
        if data then
            data.locked = newLockState
        end
    end
    
    -- Применяем блокировку физически ко ВСЕМ дверям группы.
    -- На картах вроде rp_bangclaw двойные двери — это две независимых
    -- prop_door_rotating, поэтому Fire() на одной не повлияет на вторую,
    -- и проход открывался бы только через одну створку. Идём по группе.
    local playedSound = false
    for _, doorKey in ipairs(doorKeysToLock) do
        local doorEnt = zb.FindDoorEntByKey(doorKey)
        if IsValid(doorEnt) then
            if newLockState then
                doorEnt:Fire("Lock")
                doorEnt:Fire("Close")
            else
                doorEnt:Fire("Unlock")
            end

            -- Звук проигрываем только один раз, на двери под прицелом.
            if not playedSound and doorEnt == door then
                if newLockState then
                    doorEnt:EmitSound("doors/door_latch3.wav")
                else
                    doorEnt:EmitSound("doors/door_latch1.wav")
                end
                playedSound = true
            end
        end
    end

    -- Если по какой-то причине дверь под прицелом не оказалась в списке
    -- (нет groupID, или ключи разъехались) — гарантируем хотя бы её работу
    -- и звук для игрока.
    if not playedSound then
        if newLockState then
            door:Fire("Lock")
            door:Fire("Close")
            door:EmitSound("doors/door_latch3.wav")
        else
            door:Fire("Unlock")
            door:EmitSound("doors/door_latch1.wav")
        end
    end
    
    zb.SaveDoors()
    zb.SendDoors()
end)

-- Хук для сброса владельца двери при смерти/отключении
hook.Add("PlayerDisconnected", "RoleplayResetDoors", function(ply)
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    
    local steamID = ply:SteamID()
    
    for doorKey, doorData in pairs(zb.Doors) do
        if doorData.owner == steamID then
            doorData.owner = nil
            doorData.ownerName = nil
            doorData.locked = false
        end
    end
    
    zb.SaveDoors()
    zb.SendDoors()

    -- Удаляем магазин оружия игрока при отключении
    for _, ent in ipairs(ents.FindByClass("zb_gun_shop")) do
        if IsValid(ent) and ent:GetOwnerID() == steamID then
            local effectData = EffectData()
            effectData:SetOrigin(ent:GetPos())
            effectData:SetEntity(ent)
            util.Effect("Disintegrate", effectData, true, true)
            timer.Simple(0.5, function()
                if IsValid(ent) then ent:Remove() end
            end)
        end
    end
end)


-- ============================================
-- СИСТЕМА ФРАКЦИОННЫХ МАШИН
-- ============================================

-- Проверка доступа к машине по фракции
function MODE:CanPlayerEnterVehicle(ply, vehicle, role)
    if not IsValid(vehicle) or not IsValid(ply) then return end
    
    -- Проверяем, является ли это фракционной машиной
    if not vehicle.zbCarSpawnID then return end
    
    local spawnID = vehicle.zbCarSpawnID
    local spawn = zb.CarSpawns[spawnID]
    
    if not spawn then return end
    
    local carType = spawn.carType
    local carInfo = zb.CarTypes[carType]
    
    if not carInfo then return end
    
    -- Получаем профессию игрока
    local jobName = ply.RoleplayJob or "Гражданский"
    local job = self.Jobs[jobName]
    
    if not job then return false end
    
    -- Проверяем доступ по фракции
    local faction = carInfo.faction
    
    -- Полицейские машины
    if faction == "police" then
        if jobName == "Полицейский" or jobName == "Спецназ" or jobName == "Глава Полиции" then
            return true
        end
    end
    
    -- Машины мэрии
    if faction == "meria" then
        if jobName == "Мэр" or jobName == "Глава Полиции" then
            return true
        end
    end
    
    -- Машины игил
    if faction == "igil" or faction == "igil2" then
        if jobName == "ЦАХАЛ" then
            return true
        end
    end
    
    -- Доступ запрещен
    net.Start("roleplay_error_message")
    net.WriteString("У вас нет доступа к этой машине")
    net.Send(ply)
    return false
end

-- Глобальный хук для проверки доступа к машинам (работает для всех типов машин)
hook.Add("CanPlayerEnterVehicle", "zb_car_access_control", function(ply, vehicle, role)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    print("[ZBattle] CanPlayerEnterVehicle вызван для " .. ply:Name())
    
    -- Проверяем, является ли это фракционной машиной
    if not vehicle.zbCarSpawnID then 
        print("[ZBattle] Машина не фракционная, пропускаем")
        return 
    end
    
    print("[ZBattle] Фракционная машина ID: " .. vehicle.zbCarSpawnID)
    
    local spawnID = vehicle.zbCarSpawnID
    local spawn = zb.CarSpawns[spawnID]
    
    if not spawn then 
        print("[ZBattle] Точка спавна не найдена")
        return 
    end
    
    local carType = spawn.carType
    local carInfo = zb.CarTypes[carType]
    
    if not carInfo then 
        print("[ZBattle] Информация о машине не найдена")
        return 
    end
    
    print("[ZBattle] Тип машины: " .. carInfo.name .. ", фракция: " .. carInfo.faction)
    
    -- Получаем профессию игрока
    local jobName = ply.RoleplayJob or "Гражданский"
    print("[ZBattle] Профессия игрока: " .. jobName)
    
    -- Проверяем доступ по фракции
    local faction = carInfo.faction
    local hasAccess = false
    
    -- Полицейские машины
    if faction == "police" then
        if jobName == "Полицейский" or jobName == "Спецназ" or jobName == "Глава Полиции" then
            hasAccess = true
        end
    end
    
    -- Машины мэрии
    if faction == "meria" then
        if jobName == "Мэр" or jobName == "Глава Полиции" then
            hasAccess = true
        end
    end
    
    -- Машины игил
    if faction == "igil" or faction == "igil2" then
        if jobName == "ЦАХАЛ" then
            hasAccess = true
        end
    end
    
    print("[ZBattle] Доступ: " .. tostring(hasAccess))
    
    if not hasAccess then
        net.Start("roleplay_error_message")
        net.WriteString("У вас нет доступа к этой машине (" .. carInfo.name .. ")")
        net.Send(ply)
        return false
    end
    
    return true
end)

-- Дополнительная проверка после входа (для Simfphys, который может игнорировать CanPlayerEnterVehicle)
hook.Add("PlayerEnteredVehicle", "zb_car_access_check_simfphys", function(ply, vehicle, role)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    -- Проверяем, является ли это фракционной машиной
    if not vehicle.zbCarSpawnID then return end
    
    print("[ZBattle] PlayerEnteredVehicle - игрок " .. ply:Name() .. " сел в фракционную машину")
    
    local spawnID = vehicle.zbCarSpawnID
    local spawn = zb.CarSpawns[spawnID]
    
    if not spawn then return end
    
    local carType = spawn.carType
    local carInfo = zb.CarTypes[carType]
    
    if not carInfo then return end
    
    -- Получаем профессию игрока
    local jobName = ply.RoleplayJob or "Гражданский"
    print("[ZBattle] Проверка доступа: профессия " .. jobName .. ", фракция машины " .. carInfo.faction)
    
    -- Проверяем доступ по фракции
    local faction = carInfo.faction
    local hasAccess = false
    
    -- Полицейские машины
    if faction == "police" then
        if jobName == "Полицейский" or jobName == "Спецназ" or jobName == "Глава Полиции" then
            hasAccess = true
        end
    end
    
    -- Машины мэрии
    if faction == "meria" then
        if jobName == "Мэр" or jobName == "Глава Полиции" then
            hasAccess = true
        end
    end
    
    -- Машины игил
    if faction == "igil" or faction == "igil2" then
        if jobName == "ЦАХАЛ" then
            hasAccess = true
        end
    end
    
    if not hasAccess then
        print("[ZBattle] Доступ запрещен, выкидываем игрока")
        net.Start("roleplay_error_message")
        net.WriteString("У вас нет доступа к этой машине (" .. carInfo.name .. ")")
        net.Send(ply)
        ply:ExitVehicle()
    else
        print("[ZBattle] Доступ разрешен")
    end
end)

-- Постоянная проверка игроков в фракционных машинах (на случай если хуки не работают)
local nextCheck = 0
hook.Add("Think", "zb_car_access_continuous_check", function()
    if CurTime() < nextCheck then return end
    nextCheck = CurTime() + 0.5 -- Проверяем каждые 0.5 секунды
    
    local round = ZCity_RP
    if not round then 
        return 
    end
    
    if round.name ~= "roleplay" then 
        return 
    end
    
    for _, ply in ipairs(player.GetAll()) do
        local vehicle = ply:GetVehicle()
        
        if IsValid(vehicle) then
            -- Проверяем zbCarSpawnID
            if vehicle.zbCarSpawnID then
                print("[ZBattle] Think: Игрок " .. ply:Name() .. " в фракционной машине #" .. vehicle.zbCarSpawnID)
                
                local spawnID = vehicle.zbCarSpawnID
                local spawn = zb.CarSpawns[spawnID]
                
                if spawn then
                    local carInfo = zb.CarTypes[spawn.carType]
                    
                    if carInfo then
                        local jobName = ply.RoleplayJob or "Гражданский"
                        local faction = carInfo.faction
                        local hasAccess = false
                        
                        print("[ZBattle] Think: Профессия " .. jobName .. ", фракция машины " .. faction)
                        
                        -- Полицейские машины
                        if faction == "police" then
                            if jobName == "Полицейский" or jobName == "Спецназ" or jobName == "Глава Полиции" then
                                hasAccess = true
                            end
                        end
                        
                        -- Машины мэрии
                        if faction == "meria" then
                            if jobName == "Мэр" or jobName == "Глава Полиции" then
                                hasAccess = true
                            end
                        end
                        
                        -- Машины игил
                        if faction == "igil" or faction == "igil2" then
                            if jobName == "ЦАХАЛ" then
                                hasAccess = true
                            end
                        end
                        
                        print("[ZBattle] Think: Доступ = " .. tostring(hasAccess))
                        
                        if not hasAccess then
                            print("[ZBattle] Think: ВЫКИДЫВАЕМ ИГРОКА!")
                            net.Start("roleplay_error_message")
                            net.WriteString("У вас нет доступа к этой машине!")
                            net.Send(ply)
                            ply:ExitVehicle()
                        end
                    else
                        print("[ZBattle] Think: carInfo не найден для " .. spawn.carType)
                    end
                else
                    print("[ZBattle] Think: spawn не найден для ID " .. spawnID)
                end
            end
        end
    end
end)


-- Команда для тестирования системы доступа к машинам
concommand.Add("zb_test_car_access", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    
    print("=== ТЕСТ СИСТЕМЫ ДОСТУПА К МАШИНАМ ===")
    print("Профессия игрока: " .. (ply.RoleplayJob or "Гражданский"))
    print("Всего фракционных машин: " .. table.Count(zb.CarSpawns))
    
    for id, spawn in pairs(zb.CarSpawns) do
        if IsValid(spawn.vehicle) then
            print("Машина #" .. id .. ":")
            print("  zbCarSpawnID: " .. tostring(spawn.vehicle.zbCarSpawnID))
            print("  Класс: " .. spawn.vehicle:GetClass())
            print("  Тип: " .. spawn.carType)
        end
    end
    
    print("======================================")
end)


-- Команда для проверки машины под игроком
concommand.Add("zb_check_my_vehicle", function(ply, cmd, args)
    if not IsValid(ply) then return end
    
    local vehicle = ply:GetVehicle()
    
    print("=== ПРОВЕРКА МАШИНЫ ===")
    print("Игрок: " .. ply:Name())
    print("Профессия: " .. (ply.RoleplayJob or "Гражданский"))
    print("Режим: " .. (ZCity_RP and ZCity_RP.name or "НЕТ"))
    print("В машине: " .. tostring(IsValid(vehicle)))
    
    if IsValid(vehicle) then
        print("Класс машины: " .. vehicle:GetClass())
        print("zbCarSpawnID: " .. tostring(vehicle.zbCarSpawnID))
        
        if vehicle.zbCarSpawnID then
            local spawn = zb.CarSpawns[vehicle.zbCarSpawnID]
            if spawn then
                print("Точка спавна найдена")
                print("Тип: " .. spawn.carType)
                local carInfo = zb.CarTypes[spawn.carType]
                if carInfo then
                    print("Название: " .. carInfo.name)
                    print("Фракция: " .. carInfo.faction)
                end
            else
                print("Точка спавна НЕ найдена!")
            end
        else
            print("Это НЕ фракционная машина")
        end
    end
    
    print("======================")
end)


-- ============================================
-- СИСТЕМА МАНИ ПРИНТЕРОВ
-- ============================================

util.AddNetworkString("roleplay_buy_printer")
util.AddNetworkString("roleplay_printer_collect")
util.AddNetworkString("roleplay_printer_message")

-- Обработчик покупки принтера
net.Receive("roleplay_buy_printer", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    
    if not IsValid(ply) or not ply:Alive() then return end
    
    local printerType = net.ReadString()
    
    -- Проверяем тип принтера
    local printerInfo = scripted_ents.GetStored("zb_money_printer").t.PrinterTypes[printerType]
    if not printerInfo then
        net.Start("roleplay_error_message")
        net.WriteString("Неизвестный тип принтера")
        net.Send(ply)
        return
    end
    
    -- Проверяем деньги
    ply.RoleplayMoney = ply.RoleplayMoney or 5000
    
    if ply.RoleplayMoney < printerInfo.price then
        net.Start("roleplay_error_message")
        net.WriteString("Недостаточно денег (нужно " .. printerInfo.price .. "$)")
        net.Send(ply)
        return
    end
    
    -- Проверяем лимит принтеров (максимум 5 на игрока)
    local PRINTER_LIMIT = 5
    local printerCount = 0
    for _, ent in ipairs(ents.FindByClass("zb_money_printer")) do
        if IsValid(ent) and ent:GetNWString("Owner", "") == ply:SteamID() then
            printerCount = printerCount + 1
        end
    end
    
    if printerCount >= PRINTER_LIMIT then
        net.Start("roleplay_error_message")
        net.WriteString("Достигнут лимит принтеров (" .. PRINTER_LIMIT .. "/" .. PRINTER_LIMIT .. ")")
        net.Send(ply)
        return
    end
    
    -- Снимаем деньги
    round:TakeMoney(ply, printerInfo.price, "purchase")
    
    -- Создаём принтер перед игроком
    local trace = ply:GetEyeTrace()
    local spawnPos = trace.HitPos + trace.HitNormal * 10
    
    local printer = ents.Create("zb_money_printer")
    if IsValid(printer) then
        printer:SetPos(spawnPos)
        printer:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
        printer:SetPrinterType(printerType)
        printer:Spawn()
        printer:SetPrinterOwner(ply)
        
        -- Цветное сообщение о покупке
        net.Start("roleplay_printer_message")
        net.WriteString("buy")
        net.WriteString(printerInfo.name)
        net.WriteInt(printerInfo.price, 16)
        net.Send(ply)
    end
end)

-- ============================================
-- СИСТЕМА АВТОУДАЛЕНИЯ ОРУЖИЯ
-- ============================================

local rp_disable_weapon_autoremove = CreateConVar(
    "rp_disable_weapon_autoremove",
    "0",
    FCVAR_NONE,
    "Temporarily disable roleplay weapon auto-removal",
    0,
    1
)

concommand.Add("rp_toggle_weapon_autoremove", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local newValue = rp_disable_weapon_autoremove:GetBool() and 0 or 1
    RunConsoleCommand("rp_disable_weapon_autoremove", tostring(newValue))
    local msg = "rp_disable_weapon_autoremove = " .. newValue
    if IsValid(ply) then
        ply:ChatPrint(msg)
    else
        print(msg)
    end
end)

local function rpWeaponAutoRemoveDisabled()
    return rp_disable_weapon_autoremove:GetBool()
end

-- Классы оружия которые нельзя подбирать / они должны удаляться мгновенно
local INSTANT_REMOVE_WEAPONS = {
    ["weapon_physgun"] = true,
    ["gmod_tool"]      = true,
}

-- 1. Мгновенное удаление при явном дропе (G-клавиша или скрипт)
hook.Add("PlayerDroppedWeapon", "RoleplayWeaponAutoRemove", function(ply, weapon)
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    if rpWeaponAutoRemoveDisabled() then return end
    if not IsValid(weapon) then return end

    -- Физган / тулган — удаляем немедленно
    if INSTANT_REMOVE_WEAPONS[weapon:GetClass()] then
        weapon:Remove()
        return
    end

    -- Остальное оружие — помечаем для таймера
    weapon.DroppedTime = CurTime()
    weapon.IsDropped = true
end)

-- 2. Удаление при смерти игрока (оружие спавнится в мире на следующий тик)
hook.Add("DoPlayerDeath", "RoleplayMarkWeaponsOnDeath", function(ply, attacker, dmginfo)
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    if rpWeaponAutoRemoveDisabled() then return end

    timer.Simple(0.1, function()
        if not IsValid(ply) then return end

        -- Ищем физган / тулган без владельца рядом с местом смерти
        for cls in pairs(INSTANT_REMOVE_WEAPONS) do
            for _, weapon in ipairs(ents.FindByClass(cls)) do
                if IsValid(weapon) and (not IsValid(weapon:GetOwner()) or not weapon:GetOwner():IsPlayer()) then
                    weapon:Remove()
                end
            end
        end

        -- Остальное оружие — помечаем для таймера
        for _, weapon in ipairs(ents.FindByClass("weapon_*")) do
            if IsValid(weapon) and weapon:GetOwner() == NULL and not weapon.DroppedTime then
                local dist = weapon:GetPos():Distance(ply:GetPos())
                if dist < 200 then
                    weapon.DroppedTime = CurTime()
                    weapon.IsDropped = true
                end
            end
        end
    end)
end)

-- 3. Страховка: EntityCreated перехватывает любой спавн физгана / тулгана в мире
hook.Add("EntityCreated", "RoleplayInstantRemoveAdminGuns", function(ent)
    if not IsValid(ent) then return end
    if rpWeaponAutoRemoveDisabled() then return end
    if not INSTANT_REMOVE_WEAPONS[ent:GetClass()] then return end

    -- Даём один тик — если владелец не присвоен (= оружие лежит в мире), удаляем
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        -- Оружие выдано через билд мод — не удалять
        if ent.BuildModeWeapon then return end
        local owner = ent:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then return end -- в руках игрока — ок
        -- Дополнительная проверка: оружие уже в инвентаре у игрока с билд модом
        for _, p in ipairs(player.GetAll()) do
            if p:GetNWBool("rp_buildmode", false) and p:HasWeapon(ent:GetClass()) then return end
        end
        -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
        ent:Remove()
    end)
end)

-- 4. Последняя линия обороны: запрещаем подбор с земли
hook.Add("PlayerCanPickupWeapon", "RoleplayBlockAdminGunPickup", function(ply, weapon)
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    if rpWeaponAutoRemoveDisabled() then return end
    if not IsValid(weapon) then return end
    if INSTANT_REMOVE_WEAPONS[weapon:GetClass()] then
        -- Билд мод: разрешить подбор физгана / тулгана выданных через !стройка / ESC-меню
        if IsValid(ply) and ply:GetNWBool("rp_buildmode", false) then return end
        if weapon.BuildModeWeapon then return end
        return false
    end
end)

-- Таймер для проверки и удаления старого оружия
timer.Create("RoleplayWeaponCleanup", 5, 0, function()
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    if rpWeaponAutoRemoveDisabled() then return end
    
    local currentTime = CurTime()
    
    for _, weapon in ipairs(ents.FindByClass("weapon_*")) do
        if IsValid(weapon) and weapon.IsDropped and weapon.DroppedTime then
            -- Проверяем, не подобрано ли оружие
            if IsValid(weapon:GetOwner()) and weapon:GetOwner():IsPlayer() then
                weapon.IsDropped = false
                weapon.DroppedTime = nil
            elseif currentTime - weapon.DroppedTime >= 30 then
                -- Удаляем оружие через 30 секунд
                weapon:Remove()
            end
        end
    end
end)

-- ============================================
-- СИСТЕМА АВТОУДАЛЕНИЯ СЛЕДОВ ОТ ПУЛЬ
-- ============================================

-- Таблица для хранения времени создания декалей
local BulletDecals = {}

-- Хук для отслеживания создания декалей
hook.Add("EntityFireBullets", "RoleplayTrackBulletDecals", function(ent, data)
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    
    -- Запоминаем время создания декали
    timer.Simple(0, function()
        table.insert(BulletDecals, {
            time = CurTime(),
            pos = data.Src
        })
    end)
end)

-- Таймер для очистки старых декалей
timer.Create("RoleplayDecalCleanup", 30, 0, function()
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    
    local currentTime = CurTime()
    
    -- Удаляем записи старше 30 секунд
    for i = #BulletDecals, 1, -1 do
        if currentTime - BulletDecals[i].time >= 30 then
            table.remove(BulletDecals, i)
        end
    end
    
    -- Очищаем все декали на сервере каждые 30 секунд
    game.RemoveRagdolls()
    
    -- Отправляем команду клиентам на очистку декалей
    for _, ply in player.Iterator() do
        if IsValid(ply) then
            ply:ConCommand("r_cleardecals")
        end
    end
end)


-- ============================================
-- СИСТЕМА ЛОГИРОВАНИЯ УБИЙСТВ ДЛЯ XGUI
-- ============================================

-- Таблица для хранения логов убийств
RoleplayKillLogs = RoleplayKillLogs or {}
local MAX_KILL_LOGS = 100

util.AddNetworkString("XGUI_KillLogs")

-- Функция для добавления лога убийства
local function AddKillLog(killer, victim, weapon, distance)
    -- Убийца должен быть валидным игроком, отличным от жертвы
    local killerName, killerSID
    if IsValid(killer) and killer:IsPlayer() and killer ~= victim then
        killerName = killer:Nick()
        killerSID  = killer:SteamID()
    else
        killerName = "Мир"
        killerSID  = "N/A"
    end

    local log = {
        time          = os.date("%H:%M:%S"),
        killer        = killerName,
        killerSteamID = killerSID,
        victim        = IsValid(victim) and victim:Nick() or "Неизвестно",
        victimSteamID = IsValid(victim) and victim:SteamID() or "N/A",
        weapon        = weapon or "Неизвестно",
        distance      = distance and math.Round(distance) .. "м" or "N/A"
    }
    
    table.insert(RoleplayKillLogs, log)
    
    -- Ограничиваем размер таблицы
    if #RoleplayKillLogs > MAX_KILL_LOGS then
        table.remove(RoleplayKillLogs, 1)
    end
end

-- Отслеживаем последнего реального атакующего через HomigradDamage
-- (owner:Kill() не передаёт attacker, поэтому берём его отсюда)
hook.Add("HomigradDamage", "RoleplayKillLoggerTrackAttacker", function(ply, dmgInfo, hitgroup, ent)
    -- [ZCITY_PORT] было: проверка ZCity_RP.name == 'roleplay'; теперь всегда true
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local attacker = dmgInfo:GetAttacker()
    -- Если атакующий — оружие, берём его владельца
    if IsValid(attacker) and not attacker:IsPlayer() then
        local owner = attacker:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then
            attacker = owner
        end
    end

    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= ply then
        ply._lastKillLogAttacker = attacker
        ply._lastKillLogAttackerPos = attacker:GetPos()
        ply._lastKillLogVictimPos = ply:GetPos()
    end
end)

hook.Add("PlayerDeath", "RoleplayKillLogger", function(victim, inflictor, attacker)
    local round = ZCity_RP -- [ZCITY_PORT]

    -- Приоритет: последний атакующий из HomigradDamage (самый надёжный источник)
    local realAttacker = victim._lastKillLogAttacker
    local attackerPos  = victim._lastKillLogAttackerPos
    local victimPos    = victim._lastKillLogVictimPos

    -- Сбрасываем сохранённые данные
    victim._lastKillLogAttacker    = nil
    victim._lastKillLogAttackerPos = nil
    victim._lastKillLogVictimPos   = nil

    -- Fallback: attacker из самого хука (если HomigradDamage не сработал — прямой урон)
    if not IsValid(realAttacker) then
        realAttacker = attacker
        if IsValid(realAttacker) and not realAttacker:IsPlayer() then
            local owner = realAttacker:GetOwner()
            if IsValid(owner) and owner:IsPlayer() then
                realAttacker = owner
            end
        end
        if IsValid(realAttacker) and realAttacker:IsPlayer() and realAttacker ~= victim then
            attackerPos = realAttacker:GetPos()
            victimPos   = victim:GetPos()
        else
            realAttacker = nil
        end
    end

    local weapon = "Неизвестно"
    if IsValid(inflictor) and inflictor:IsWeapon() then
        weapon = inflictor:GetClass()
    elseif IsValid(realAttacker) then
        local activeWep = realAttacker:GetActiveWeapon()
        if IsValid(activeWep) then
            weapon = activeWep:GetClass()
        end
    end

    local distance = nil
    if attackerPos and victimPos then
        distance = attackerPos:Distance(victimPos) * 0.01905
    end

    AddKillLog(realAttacker, victim, weapon, distance)
end)

-- Команда для получения логов
local STAFF_GROUPS = {
    moderator = true, admin = true, superadmin = true,
    dmoderator = true, dadmin = true, dsuperadmin = true,
}
local function IsStaff(ply)
    return IsValid(ply) and (STAFF_GROUPS[ply:GetUserGroup()] or ply:IsSuperAdmin())
end

concommand.Add("xgui_getkilllogs", function(ply, cmd, args)
    if not IsStaff(ply) then return end

    local filter = args[1] or ""
    local filteredLogs = {}

    if filter == "" then
        filteredLogs = RoleplayKillLogs
    else
        local lf = string.lower(filter)
        for _, log in ipairs(RoleplayKillLogs) do
            if string.find(string.lower(log.killer or ""), lf, 1, true)
            or string.find(string.lower(log.victim or ""), lf, 1, true) then
                table.insert(filteredLogs, log)
            end
        end
    end

    net.Start("XGUI_KillLogs")
    net.WriteTable(filteredLogs)
    net.Send(ply)
end)

-- Логи убийств — только в памяти, сбрасываются при каждом рестарте сервера

-- ============================================
-- МАГАЗИН ПРОДАВЦА ОРУЖИЯ — см. sv_gundealer.lua
-- ============================================

-- ============================================
-- КОНСОЛЬНАЯ КОМАНДА ВЫДАЧИ ДЕНЕГ
-- ============================================
-- Использование: rp_givemoney <имя/часть имени/"*"> <сумма>
-- Примеры:
--   rp_givemoney * 5000        — всем игрокам
--   rp_givemoney Vasya 1000    — игроку с именем содержащим "Vasya"

concommand.Add("rp_givemoney", function(ply, cmd, args)
    -- Только сервер или администратор
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[Roleplay] Недостаточно прав.")
        return
    end

    local round = ZCity_RP
    if not round or round.name ~= "roleplay" then
        if IsValid(ply) then
            ply:ChatPrint("[Roleplay] Команда доступна только в режиме Roleplay.")
        else
            print("[Roleplay] Команда доступна только в режиме Roleplay.")
        end
        return
    end

    local target = args[1]
    local amount = tonumber(args[2])

    if not target or not amount then
        local usage = "Использование: rp_givemoney <имя/\"*\"> <сумма>"
        if IsValid(ply) then ply:ChatPrint(usage) else print(usage) end
        return
    end

    amount = math.floor(amount)

    local targets = {}

    if target == "*" then
        -- Все игроки
        for _, p in player.Iterator() do
            if p:Team() ~= TEAM_SPECTATOR then
                table.insert(targets, p)
            end
        end
    else
        -- Поиск по части имени Steam (без учёта регистра)
        local lowerTarget = string.lower(target)
        for _, p in player.Iterator() do
            if string.find(string.lower(p:Nick()), lowerTarget, 1, true) then
                table.insert(targets, p)
            end
        end
    end

    if #targets == 0 then
        local msg = "[Roleplay] Игрок не найден: " .. target
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end

    for _, p in ipairs(targets) do
        round:AddMoney(p, amount, "admin_give", ply)
        local msg = string.format("[Roleplay] Выдано %d$ игроку %s", amount, p:Nick())
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end
end)

-- ============================================================================
-- Обновление флага "rp_safezone" для каждого игрока
-- ----------------------------------------------------------------------------
-- Каждые ~0.3 сек проверяем расстояние до всех точек ROLEPLAY_SPAWN. Если
-- игрок в радиусе MODE.SafeZoneRadius — выставляем NWBool, который читает
-- shared HG_MovementCalc_2 в sh_roleplay.lua. При входе в зону сразу
-- переключаем на руки, чтобы оружие не оставалось в руках видимо.
-- ============================================================================
local function GetSafePoints()
    local pts = zb.GetMapPoints("ROLEPLAY_SPAWN") or {}
    local out = {}
    for _, v in pairs(pts) do
        if v.pos then out[#out + 1] = v.pos end
    end
    return out
end

local _safeNextCheck = 0
hook.Add("Think", "roleplay_safezone_update", function()
    if CurTime() < _safeNextCheck then return end
    _safeNextCheck = CurTime() + 0.3

    local mode = zb.modes and zb.modes["roleplay"]
    if not mode then return end
    local radius = mode.SafeZoneRadius or 600
    local r2 = radius * radius

    local points = GetSafePoints()
    if #points == 0 then return end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then
            if IsValid(ply) and ply:GetNWBool("rp_safezone", false) then
                ply:SetNWBool("rp_safezone", false)
            end
            continue
        end

        local pos = ply:GetPos()
        local inside = false
        for _, p in ipairs(points) do
            if pos:DistToSqr(p) <= r2 then inside = true; break end
        end

        local was = ply:GetNWBool("rp_safezone", false)
        if was ~= inside then
            ply:SetNWBool("rp_safezone", inside)
            if inside then
                local hands = ply:GetWeapon("weapon_hands_sh")
                if IsValid(hands) then ply:SelectWeapon("weapon_hands_sh") end
                ply:ChatPrint("Вы вошли в безопасную зону — оружие недоступно.")
            else
                ply:ChatPrint("Вы покинули безопасную зону.")
            end
        end
    end
end)

-- =====================================================
-- ЗАЩИТА СПАВНА: ПОЛНОСТЬЮ ОТКЛЮЧЕНА
-- =====================================================
-- Система зонной блокировки доставания/подбора оружия удалена
-- (выкидывала оружие у игроков вне зоны спавна).
-- Явно снимаем хуки/таймер на случай autorefresh — без рестарта сервера
-- они продолжали бы висеть в памяти из предыдущей загрузки файла.
hook.Remove("PlayerSwitchWeapon",     "RoleplaySpawnProtect")
hook.Remove("StartCommand",           "RoleplaySpawnProtect_ForceHolster")
hook.Remove("SetupMove",              "RoleplaySpawnProtect_SetupMove")
hook.Remove("PlayerCanPickupWeapon",  "RoleplaySpawnProtect_BlockPickup")
hook.Remove("WeaponEquip",            "RoleplaySpawnProtect_StripOnEquip")
if timer.Exists("RoleplaySpawnProtect_DumpWeapons") then
    timer.Remove("RoleplaySpawnProtect_DumpWeapons")
end
