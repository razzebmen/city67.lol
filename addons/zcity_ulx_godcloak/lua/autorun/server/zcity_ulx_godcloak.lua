-- ZCity: ULX !god / !ungod / !cloak / !uncloak → та же логика, что у !zc_god / !zc_cloak
-- Gamemode должен быть zcity; иначе выполняется штатный колбэк ULX.

local GM_NAME = "zcity"

local function ulib_cmds()
	return istable(ULib) and ULib.cmds and ULib.cmds.translatedCmds
end

local function applyZCityCloak(ply, should_be_cloaked)
	ply.cloak = should_be_cloaked
	ply:SetMaterial(should_be_cloaked and "NULL" or nil)
	ply:DrawShadow(not should_be_cloaked)
	ply:SetCollisionGroup(should_be_cloaked and COLLISION_GROUP_DEBRIS or COLLISION_GROUP_PLAYER)
	ply:RemoveAllDecals()
	ply:Notify(
		should_be_cloaked and "Невидимость включена" or "Невидимость выключена",
		0
	)
end

local function isGodActive(v)
	if v.organism then return v.organism.godmode == true end
	return v:HasGodMode()
end

-- =====================================================
-- Публичный API: переключить божественный режим без чата/уведомлений
-- =====================================================
-- Используется системой безопасных зон (zb_greenzone) и любыми другими
-- авто-триггерами, которые НЕ должны спамить игроку «Режим бога включён».
--
-- ply    - целевой игрок
-- enable - true / false
-- silent - true чтобы подавить v:Notify(...). false/nil = показать.
ZCity = ZCity or {}
function ZCity.SetGod(ply, enable, silent)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	enable = enable and true or false

	if ply.organism then
		ply.organism.godmode = enable
	else
		if enable then ply:GodEnable() else ply:GodDisable() end
	end

	-- Совместимость с движковым ULX God: гасим лишний флаг
	if not enable and ply:HasGodMode() then ply:GodDisable() end
	ply.ULXHasGod = nil

	if not silent then
		ply:Notify(enable and "Режим бога включён" or "Режим бога выключен", 0)
	end
end

function ZCity.IsGodActive(ply)
	if not IsValid(ply) then return false end
	return isGodActive(ply)
end

local function handleGod(calling_ply, target_plys, should_revoke, origFn)
	if not IsValid(target_plys[1]) then
		return origFn(calling_ply, target_plys, should_revoke)
	end

	local affected = {}
	for i = 1, #target_plys do
		local v = target_plys[i]
		if ulx.getExclusive(v, calling_ply) then
			ULib.tsayError(calling_ply, ulx.getExclusive(v, calling_ply), true)
		else
			-- Автотоггл: !god при уже активном режиме — выключаем
			local effective_revoke = should_revoke
			if not should_revoke and isGodActive(v) then
				effective_revoke = true
			end

			if not v.organism then
				-- organism нет (roleplay режим) — используем стандартный ULX god
				if effective_revoke then v:GodDisable() else v:GodEnable() end
				v:Notify(effective_revoke and "Режим бога выключен" or "Режим бога включён", 0)
			else
				v.organism.godmode = not effective_revoke
				v:Notify(effective_revoke and "Режим бога выключен" or "Режим бога включён", 0)
			end
			affected[#affected + 1] = { ply = v, revoked = effective_revoke }
		end
	end

	if #affected == 0 then return end

	-- Лог только в серверную консоль, не в чат игрокам
	local names = {}
	for _, entry in ipairs(affected) do names[#names + 1] = entry.ply:Nick() end
	local who = calling_ply:IsValid() and calling_ply:Nick() or "CONSOLE"
	MsgC(Color(100, 220, 130), string.format("[ZCity God] %s → %s: %s\n",
		who, table.concat(names, ", "),
		(affected[1].revoked and "выключен" or "включён")))

	-- Совместимость: снимаем движковый God ULX, если остался включён
	for _, entry in ipairs(affected) do
		local v = entry.ply
		if IsValid(v) and v:IsPlayer() and v:HasGodMode() then
			v:GodDisable()
		end
		v.ULXHasGod = nil
	end
end

-- ulx.cloak( calling_ply, target_plys, amount, should_uncloak )
local function handleCloak(calling_ply, target_plys, amount, should_uncloak, origFn)
	if not IsValid(target_plys[1]) then
		return origFn(calling_ply, target_plys, amount, should_uncloak)
	end

	local affected = {}
	for i = 1, #target_plys do
		local v = target_plys[i]
		if ulx.getExclusive(v, calling_ply) then
			ULib.tsayError(calling_ply, ulx.getExclusive(v, calling_ply), true)
		else
			-- Автотоггл: !cloak при уже активной невидимости — выключаем
			local effective_uncloak = should_uncloak
			if not should_uncloak and v.cloak then
				effective_uncloak = true
			end

			if not v.organism then
				-- organism нет (roleplay режим) — используем стандартный ULX cloak
				if ULib.invisible then pcall(ULib.invisible, v, not effective_uncloak, 255) end
				applyZCityCloak(v, not effective_uncloak)
			else
				if ULib.invisible then pcall(ULib.invisible, v, false, 255) end
				applyZCityCloak(v, not effective_uncloak)
			end
			affected[#affected + 1] = { ply = v, uncloaked = effective_uncloak }
		end
	end

	if #affected == 0 then return end

	-- Лог только в серверную консоль, не в чат игрокам
	local names = {}
	for _, entry in ipairs(affected) do names[#names + 1] = entry.ply:Nick() end
	local who = calling_ply:IsValid() and calling_ply:Nick() or "CONSOLE"
	MsgC(Color(100, 220, 130), string.format("[ZCity Cloak] %s → %s: %s\n",
		who, table.concat(names, ", "),
		(affected[1].uncloaked and "снята" or "включена")))
end

local function patchOne(cmdName, handler)
	local translated = ulib_cmds()
	if not translated then return false end
	local cmd = translated[string.lower(cmdName)]
	if not cmd or not isfunction(cmd.fn) then return false end
	local origFn = cmd.fn
	cmd.fn = function(...)
		if engine.ActiveGamemode() ~= GM_NAME then
			return origFn(...)
		end
		return handler(origFn, ...)
	end
	return true
end

local function patchAll()
	if _G.ZCity_ULXGodCloak_done then return true end
	if not (istable(ulx) and istable(ULib)) then return false end
	local translated = ulib_cmds()
	if not translated then return false end
	if not translated["ulx god"] then return false end
	if not translated["ulx cloak"] then return false end

	if patchOne("ulx god", function(origFn, calling_ply, target_plys, should_revoke)
		handleGod(calling_ply, target_plys, should_revoke, origFn)
	end)
		and patchOne("ulx cloak", function(origFn, calling_ply, target_plys, amount, should_uncloak)
			handleCloak(calling_ply, target_plys, amount, should_uncloak, origFn)
		end)
	then
		_G.ZCity_ULXGodCloak_done = true
		MsgC(
			Color(100, 220, 130),
			"[ZCity ULX Bridge] !god / !cloak перенаправлены на логику gamemode ZCity.\n"
		)
		return true
	end
	return false
end

local function startPatch()
	_G.ZCity_ULXGodCloak_done = nil -- сбросить флаг чтобы патч накатился заново
	local tries = 0
	timer.Create("ZCityULXGodCloak_Retry", 0.5, 80, function()
		tries = tries + 1
		if patchAll() then timer.Remove("ZCityULXGodCloak_Retry") elseif tries >= 80 then
			MsgC(Color(220, 80, 80), "[ZCity ULX Bridge] Не удалось найти ULX после 80 попыток (есть ли ULib/ULX?).\n")
			timer.Remove("ZCityULXGodCloak_Retry")
		end
	end)
end

hook.Add("Initialize", "ZCityULXGodCloak", startPatch)
hook.Add("ULibLocalPlayerReady", "ZCityULXGodCloakReload", startPatch)

-- =====================================================
-- Доступы: god / cloak — с moderator/dmoderator и выше
-- =====================================================
-- По умолчанию ULX выдаёт ulx god / ulx cloak только admin+. Дадим эти
-- команды модераторским группам сервера, чтобы они могли защищаться
-- в горячих ситуациях. Группы admin/dadmin и выше получают через наследование.
local GODCLOAK_GROUPS = { "moderator", "dmoderator" }
local GODCLOAK_CMDS   = { "ulx god", "ulx ungod", "ulx cloak", "ulx uncloak" }

local function ensureGodCloakAccess()
    if not (ULib and ULib.ucl and ULib.ucl.groupAllow and ULib.ucl.groups) then return false end
    local granted = false
    for _, g in ipairs(GODCLOAK_GROUPS) do
        if ULib.ucl.groups[g] then
            for _, c in ipairs(GODCLOAK_CMDS) do
                if ULib.ucl.groupAllow(g, { c }) then granted = true end
            end
        end
    end
    if granted then
        MsgC(Color(100, 220, 130),
            "[ZCity ULX Bridge] god/cloak выданы группам moderator/dmoderator.\n")
    end
    return true
end

local function startGodCloakAccessGrant()
    local tries = 0
    timer.Create("ZCityULXGodCloak_AccessRetry", 1, 60, function()
        tries = tries + 1
        if ensureGodCloakAccess() then
            timer.Remove("ZCityULXGodCloak_AccessRetry")
        elseif tries >= 60 then
            timer.Remove("ZCityULXGodCloak_AccessRetry")
        end
    end)
end
hook.Add("Initialize", "ZCityULXGodCloakAccess", startGodCloakAccessGrant)
