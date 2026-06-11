-- [ZCITY_PORT] Файл автоматически мигрирован из gamemodes/zcity/.../modes/roleplay/sv_gundealer.lua
-- Источник: _backup_20260522_182916/zcity/gamemode/modes/roleplay/
-- Все обращения к CurrentRound()/MODE/round заменены на ZCity_RP.
-- ZCity_RP — это таблица-обёртка, имитирующая старый MODE-namespace,
--           содержит Jobs, AddMoney, TakeMoney, GetMoney, CityTaxRate и т.д.
-- Реализация в darkrp_modules/zcity_rp_core/sh_zcity_rp_namespace.lua

-- Серверная часть магазина Продавца Оружия в режиме Roleplay
-- Оригинальная TDM логика покупки, адаптированная под RP:
--   - деньги берутся из RoleplayMoney через round:TakeMoney()
--   - нет ограничения по времени (убрана проверка BuyTime)
--   - доступно только для профессии "Продавец Оружия"
--   - налоговая надбавка (taxRate%) идёт в казну города

util.AddNetworkString("roleplay_gundealer_buy")

local AttachmentPrice = 50

-- Возвращает цену с учётом налога и сумму налога
local function GetTaxedPrice(basePrice)
    local round = ZCity_RP
    local taxRate = (round and round.CityTaxRate) or 0
    local taxAmount = math.floor(basePrice * (taxRate / 100))
    return basePrice + taxAmount, taxAmount
end

net.Receive("roleplay_gundealer_buy", function(len, ply)
	local round = ZCity_RP -- [ZCITY_PORT]
	if not ply:Alive() then return end

	-- Только Продавец Оружия
	if (ply.RoleplayJob or "Гражданский") ~= "Продавец Оружия" then return end

	local tItem = net.ReadTable()
	if not istable(tItem) then return end

	local category = tItem[1]
	local index    = tItem[2]
	if not category or not index then return end

	-- Берём список товаров из TDM режима
	local tdmMode = zb.modes and zb.modes["tdm"]
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

		local taxedAttachPrice, attachTax = GetTaxedPrice(AttachmentPrice)

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
end)

-- ============================================
-- Покупка предмета "Магазин оружия" (энтити)
-- ============================================

util.AddNetworkString("roleplay_buy_gun_shop")

net.Receive("roleplay_buy_gun_shop", function(len, ply)
    local round = ZCity_RP -- [ZCITY_PORT]
    if not ply:Alive() then return end

    -- Только Продавец Оружия
    if (ply.RoleplayJob or "Гражданский") ~= "Продавец Оружия" then return end

    local price = 15000

    ply.RoleplayMoney = ply.RoleplayMoney or 5000
    if ply.RoleplayMoney < price then
        ply:ChatPrint("[Roleplay] Недостаточно денег.")
        return
    end

    -- Спавним энтити перед игроком
    local pos = ply:GetPos() + ply:GetForward() * 80
    pos.z = pos.z + 5

    local ent = ents.Create("zb_gun_shop")
    if not IsValid(ent) then return end

    ent:SetPos(pos)
    ent:SetAngles(Angle(0, ply:GetAngles().y + 180, 0))
    ent:Spawn()
    ent:Activate()

    -- Привязываем к продавцу
    ent:SetOwnerID(ply:SteamID())
    ent:SetOwnerName(ply:Nick())

    round:TakeMoney(ply, price)
    ply:EmitSound("items/itempickup.wav")
end)
