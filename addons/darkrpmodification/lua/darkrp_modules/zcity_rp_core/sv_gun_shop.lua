-- [ZCITY_PORT] Файл автоматически мигрирован из gamemodes/zcity/.../modes/roleplay/sv_gun_shop.lua
-- Источник: _backup_20260522_182916/zcity/gamemode/modes/roleplay/
-- Все обращения к CurrentRound()/MODE/round заменены на ZCity_RP.
-- ZCity_RP — это таблица-обёртка, имитирующая старый MODE-namespace,
--           содержит Jobs, AddMoney, TakeMoney, GetMoney, CityTaxRate и т.д.
-- Реализация в darkrp_modules/zcity_rp_core/sh_zcity_rp_namespace.lua

-- Серверная логика магазина оружия (zb_gun_shop)
-- Покупатель платит из RoleplayMoney, продавец получает 20% комиссии от базовой цены
-- Налоговая надбавка (taxRate%) идёт в казну города

util.AddNetworkString("zb_gun_shop_open")
util.AddNetworkString("zb_gun_shop_buy")

-- Комиссия продавца
local DEALER_CUT = 0.20
local ATTACHMENT_PRICE = 50

-- Возвращает цену с учётом налога и сумму налога
local function GetTaxedPrice(basePrice)
    local round = ZCity_RP
    local taxRate = (round and round.CityTaxRate) or 0
    local taxAmount = math.floor(basePrice * (taxRate / 100))
    return basePrice + taxAmount, taxAmount
end

-- Открытие меню: сервер просто ретранслирует клиенту (клиент сам строит меню из TDM BuyItems)
-- Сигнал уже отправляется из ENT:Use() в init.lua энтити

-- Покупка через магазин
net.Receive("zb_gun_shop_buy", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    if not ply:Alive() then return end

    -- Читаем данные
    local shopEnt = net.ReadEntity()
    local tItem   = net.ReadTable()

    -- Проверяем энтити
    if not IsValid(shopEnt) or shopEnt:GetClass() ~= "zb_gun_shop" then return end

    -- Проверяем расстояние
    if ply:GetPos():Distance(shopEnt:GetPos()) > 200 then
        net.Start("roleplay_error_message")
        net.WriteString("Вы слишком далеко от магазина")
        net.Send(ply)
        return
    end

    if not istable(tItem) then return end

    local category   = tItem[1]
    local index      = tItem[2]
    if not category or not index then return end

    -- Берём товары из TDM режима
    local tdmMode  = zb.modes and zb.modes["tdm"]
    local buyItems = tdmMode and tdmMode.BuyItems
    if not buyItems or not buyItems[category] or not buyItems[category][index] then return end

    local item = buyItems[category][index]
    if not item then return end

    ply.RoleplayMoney = ply.RoleplayMoney or 5000

    -- Покупка навески
    if tItem[3] then
        if not ply:HasWeapon(item.ItemClass) then
            ply:ChatPrint("[Roleplay] Сначала купите оружие для этой навески.")
            return
        end

        local taxedAttachPrice, attachTax = GetTaxedPrice(ATTACHMENT_PRICE)

        if ply.RoleplayMoney < taxedAttachPrice then
            ply:ChatPrint("[Roleplay] Недостаточно денег.")
            return
        end

        local wep = ply:GetWeapon(item.ItemClass)
        hg.AddAttachmentForce(ply, wep, tItem[3])
        round:TakeMoney(ply, taxedAttachPrice)
        ply:EmitSound("items/itempickup.wav")

        -- Налог в казну
        if attachTax > 0 then
            round.CityTreasury = (round.CityTreasury or 0) + attachTax
            SetGlobalInt("CityTreasury", round.CityTreasury)
        end

        -- Комиссия продавцу (от базовой цены)
        local ownerID = shopEnt:GetOwnerID()
        if ownerID ~= "" then
            for _, p in player.Iterator() do
                if p:SteamID() == ownerID and p:Alive() then
                    round:AddMoney(p, math.floor(ATTACHMENT_PRICE * DEALER_CUT))
                    break
                end
            end
        end
        return
    end

    -- Покупка предмета
    local taxedPrice, taxAmount = GetTaxedPrice(item.Price)

    if ply.RoleplayMoney < taxedPrice then
        ply:ChatPrint("[Roleplay] Недостаточно денег.")
        return
    end

    local ent = ply:Give(item.ItemClass)

    if ent.Use and IsValid(ent) then
        ent:Use(ply)
    end

    if IsValid(ent) and ent:GetClass() == "weapon_bloodbag" then
        ent.bloodtype = "o-"
        ent.modeValues[1] = 1
    end

    if item.Amount then
        ent.AmmoCount = item.Amount
    end

    if ent.GetPrimaryAmmoType then
        ply:GiveAmmo(ent:GetMaxClip1() * 1, ent:GetPrimaryAmmoType(), true)
    end

    round:TakeMoney(ply, taxedPrice)
    ply:EmitSound("items/itempickup.wav")

    -- Налог в казну
    if taxAmount > 0 then
        round.CityTreasury = (round.CityTreasury or 0) + taxAmount
        SetGlobalInt("CityTreasury", round.CityTreasury)
    end

    -- Комиссия продавцу (20% от базовой цены)
    local ownerID = shopEnt:GetOwnerID()
    if ownerID ~= "" then
        for _, p in player.Iterator() do
            if p:SteamID() == ownerID and p:Alive() then
                round:AddMoney(p, math.floor(item.Price * DEALER_CUT))
                break
            end
        end
    end
end)
