--[[---------------------------------------------------------------------------
ZCity RP — FrePorts backend (написан с нуля под наш сервер).

Полностью независим от plib_v2. Реализует ровно тот сетевой протокол и
структуры данных, которые ожидает дизайн (freports/cl_init.lua):

  Клиент → Сервер:
    PlayerSsay "@ <причина>"                  — создать жалобу
    freports.accept   (Entity reporter)       — админ принимает жалобу
    freports.close                            — закрыть жалобу
    freports.message  (String)                — сообщение в чат жалобы
    freports.reputation (Bool)                — оценить работу админа
    freports.request_admin_statistic          — статистика оцениваемого админа
    reps_stats (concmd)                       — топ админов по репутации
    adm_stats  (concmd)                       — мини-логи активности
    freports.reports_statistics.search        — поиск в статистике
    freports.reports_statistics.load_more     — подгрузка страницы

  Сервер → Клиент:
    freports.send / freports.accept / freports.close / freports.message
    freports.reputation / freports.adm_stats / freports.reports_statistics(.*)
    freports.request_admin_statistic / rp.chat.SendMessage
    + netvar'ы rp.ReportClaimed (bool), rp.LastReport (int) из sh_init.lua

Структура жалобы (как ждёт дизайн):
  { reporter = Player, report_chat = {{Player, "текст"}, ...},
    start = CurTime(), admin = Player|nil }
---------------------------------------------------------------------------]]
if not SERVER then return end

local cfg = freports.config

-- ---------------------------------------------------------------------------
-- Сетевые строки
-- ---------------------------------------------------------------------------
for _, s in ipairs({
	"freports.send", "freports.accept", "freports.close", "freports.message",
	"freports.reputation", "freports.adm_stats", "freports.reports_statistics",
	"freports.reports_statistics.search", "freports.reports_statistics.load_more",
	"freports.request_admin_statistic", "rp.chat.SendMessage", "freports.sync",
}) do
	util.AddNetworkString(s)
end

-- На случай горячей перезагрузки файла: убираем устаревшую регистрацию на
-- обычном PlayerSay (раньше жалоба ловилась там). Иначе после reload остаются
-- ДВА хука с одним именем на разных событиях, и жалоба создаётся дважды.
hook.Remove("PlayerSay", "freports.create")

-- Хелпер чата (используется дизайном через PLAYER:rp_send_message)
local PLAYER = FindMetaTable("Player")
function PLAYER:rp_send_message(...)
	net.Start("rp.chat.SendMessage")
		net.WriteTable({ ... })
	net.Send(self)
end

local function notify(ply, ...)
	if IsValid(ply) then
		ply:rp_send_message(Color(255, 120, 120), "[REPORT] ", Color(255, 255, 255), ...)
	end
end

-- ---------------------------------------------------------------------------
-- Группы и получатели
-- ---------------------------------------------------------------------------
local function IsStaff(ply)
	return IsValid(ply) and cfg.WhoCanReceiveReports[ply:GetUserGroup()] == true
end

local function StaffOnline()
	local t = {}
	for _, p in ipairs(player.GetAll()) do
		if IsStaff(p) then t[#t + 1] = p end
	end
	return t
end

-- Получатели жалобы: автор + вся онлайн-администрация
local function ReportRecipients(reporter)
	local t = StaffOnline()
	if IsValid(reporter) then
		local found = false
		for _, p in ipairs(t) do if p == reporter then found = true break end end
		if not found then t[#t + 1] = reporter end
	end
	return t
end

-- ---------------------------------------------------------------------------
-- Состояние
-- ---------------------------------------------------------------------------
freports.active = freports.active or {} -- [reporter Player] = reportTable
local active = freports.active

local mini_logs = {} -- последние действия (newest first), для adm_stats
local function pushLog(entry)
	table.insert(mini_logs, 1, entry)
	while #mini_logs > (cfg.maxp_rep_log or 15) do
		table.remove(mini_logs)
	end
end

-- ---------------------------------------------------------------------------
-- База данных (SQLite — без MySQL-зависимостей)
-- ---------------------------------------------------------------------------
local EMPTY_JSON = util.TableToJSON({})

sql.Query([[CREATE TABLE IF NOT EXISTS freports_admins (
	steamid VARCHAR(255) PRIMARY KEY,
	name VARCHAR(255),
	rank VARCHAR(255),
	last_seen INTEGER,
	daily_online TEXT,
	daily_online_onduty TEXT,
	daily_reports TEXT,
	total_reports INTEGER,
	rep INTEGER
);]])

-- Сброс месячной статистики при смене месяца
do
	local cur = os.date("%m")
	if file.Read("freports_month.txt", "DATA") ~= cur then
		file.Write("freports_month.txt", cur)
		sql.Query(([[UPDATE freports_admins SET
			daily_online = %s,
			daily_online_onduty = %s,
			daily_reports = %s;]]):format(
			sql.SQLStr(EMPTY_JSON), sql.SQLStr(EMPTY_JSON), sql.SQLStr(EMPTY_JSON)))
	end
end

-- Гарантируем наличие записи админа + подтягиваем rep/total в рантайм-поля
local function ensureAdmin(ply)
	if not IsStaff(ply) then return end
	local sid = ply:SteamID64()
	if not sid then return end

	local row = sql.Query(("SELECT * FROM freports_admins WHERE steamid = %s;"):format(sql.SQLStr(sid)))
	if istable(row) and row[1] then
		sql.Query(("UPDATE freports_admins SET name = %s, rank = %s WHERE steamid = %s;"):format(
			sql.SQLStr(ply:Nick()), sql.SQLStr(ply:GetUserGroup()), sql.SQLStr(sid)))
		ply.fr_rep   = tonumber(row[1].rep) or 0
		ply.fr_total = tonumber(row[1].total_reports) or 0
	else
		sql.Query(([[INSERT INTO freports_admins
			(steamid, name, rank, last_seen, daily_online, daily_online_onduty, daily_reports, total_reports, rep)
			VALUES (%s, %s, %s, %d, %s, %s, %s, 0, 0);]]):format(
			sql.SQLStr(sid), sql.SQLStr(ply:Nick()), sql.SQLStr(ply:GetUserGroup()), os.time(),
			sql.SQLStr(EMPTY_JSON), sql.SQLStr(EMPTY_JSON), sql.SQLStr(EMPTY_JSON)))
		ply.fr_rep   = 0
		ply.fr_total = 0
	end

	ply.fr_onlineStart  = CurTime()
	ply.fr_dailyReports = 0
end

-- Сохраняем накопленные онлайн/жалобы/rep/total/last_seen в БД
local function flushAdmin(ply)
	if not IsValid(ply) then return end
	local sid = ply:SteamID64()
	if not sid then return end

	local row = sql.Query(("SELECT * FROM freports_admins WHERE steamid = %s;"):format(sql.SQLStr(sid)))
	if not (istable(row) and row[1]) then return end

	local day = os.date("%d") -- строковый ключ — стабильно переживает JSON round-trip

	if ply.fr_onlineStart then
		local add = CurTime() - ply.fr_onlineStart
		local tb = util.JSONToTable(row[1].daily_online or "") or {}
		tb[day] = (tb[day] or 0) + add
		sql.Query(("UPDATE freports_admins SET daily_online = %s WHERE steamid = %s;"):format(
			sql.SQLStr(util.TableToJSON(tb)), sql.SQLStr(sid)))
		ply.fr_onlineStart = CurTime()
	end

	if ply.fr_dailyReports and ply.fr_dailyReports > 0 then
		local tb = util.JSONToTable(row[1].daily_reports or "") or {}
		tb[day] = (tb[day] or 0) + ply.fr_dailyReports
		sql.Query(("UPDATE freports_admins SET daily_reports = %s WHERE steamid = %s;"):format(
			sql.SQLStr(util.TableToJSON(tb)), sql.SQLStr(sid)))
		ply.fr_dailyReports = 0
	end

	sql.Query(("UPDATE freports_admins SET rep = %d, total_reports = %d, last_seen = %d WHERE steamid = %s;"):format(
		tonumber(ply.fr_rep) or 0, tonumber(ply.fr_total) or 0, os.time(), sql.SQLStr(sid)))
end

-- ---------------------------------------------------------------------------
-- Жизненный цикл жалобы
-- ---------------------------------------------------------------------------
local function CreateReport(reporter, text)
	if active[reporter] then
		notify(reporter, "У вас уже есть открытая жалоба!")
		return
	end

	local report = {
		reporter    = reporter,
		report_chat = { { reporter, text } },
		start       = CurTime(),
		admin       = nil,
	}
	active[reporter] = report

	-- Жалоба создаётся всегда, даже если админов нет онлайн. Сейчас её получит
	-- сам автор (окно «Ожидаем администратора...»), а вся онлайн-администрация —
	-- если есть. Заходящим позже админам жалоба придёт через freports.sync.
	net.Start("freports.send")
		net.WriteTable(report)
	net.Send(ReportRecipients(reporter))

	if #StaffOnline() == 0 then
		notify(reporter, "Сейчас нет администрации онлайн. Жалоба сохранена — ",
			"её рассмотрят, как только зайдёт администратор.")
	end

	pushLog({
		rtype       = "create",
		rep_ply_id  = reporter:SteamID64(),
		rep_ply_name= reporter:Nick(),
		rep_ply_job = reporter:Team(),
		rep_start   = os.time(),
	})
end

-- Награждаем/штрафуем репутацию (с кулдауном на пару админ↔игрок)
local function GrantRating(reporter, admin)
	if not IsValid(reporter) or not IsValid(admin) then return end
	admin.fr_repCD = admin.fr_repCD or {}
	if admin.fr_repCD[reporter] and admin.fr_repCD[reporter] > CurTime() then return end
	admin.fr_repCD[reporter] = CurTime() + (cfg.reputation_cd or 180)

	reporter.fr_rateTarget = admin
	net.Start("freports.reputation")
	net.Send(reporter)
end

-- Засчитываем разобранную жалобу в статистику (с антинакрут-кулдауном)
local function CountHandledReport(admin, reporter)
	if not IsValid(admin) then return end
	admin.fr_statCD = admin.fr_statCD or {}
	if reporter and admin.fr_statCD[reporter] and admin.fr_statCD[reporter] > CurTime() then return end
	if reporter then
		admin.fr_statCD[reporter] = CurTime() + (cfg.add_report_to_statistic_cd or 10)
	end
	admin.fr_total        = (admin.fr_total or 0) + 1
	admin.fr_dailyReports = (admin.fr_dailyReports or 0) + 1
end

local function CloseReport(reporter)
	local report = active[reporter]
	if not report then return end
	local admin = report.admin

	-- Закрываем окна автора и админа
	local windows = {}
	if IsValid(reporter) then windows[#windows + 1] = reporter end
	if IsValid(admin) then windows[#windows + 1] = admin end
	if #windows > 0 then
		net.Start("freports.close")
		net.Send(windows)
	end

	-- Убираем запись из списков у всей администрации
	local staff = StaffOnline()
	if #staff > 0 then
		net.Start("freports.accept")
			net.WriteEntity(IsValid(reporter) and reporter or NULL)
			net.WriteEntity(NULL)
		net.Send(staff)
	end

	if IsValid(admin) then
		admin.fr_handling = nil
		admin:SetNetVar("rp.ReportClaimed", false)
		admin:SetNetVar("rp.LastReport", CurTime())
		CountHandledReport(admin, reporter)
		GrantRating(reporter, admin)
	end

	active[reporter] = nil
end
freports.CloseReport = CloseReport

-- ---------------------------------------------------------------------------
-- Создание жалобы через чат: "@ <причина>"
-- ---------------------------------------------------------------------------
-- ВАЖНО: используем HG_PlayerSay, а НЕ обычный PlayerSay.
-- На сервере стоит кастомный чат ZChat (lua/homigrad/zchat/sh_chat.lua), чей
-- PlayerSay-хук на КАЖДОЕ сообщение делает return "" (сам рассылает чат) и тем
-- самым обрывает цепочку PlayerSay — наш PlayerSay-хук (даже с HOOK_HIGH) до
-- нас попросту не доходил, поэтому "@ причина" ничего не делала.
-- Весь геймод (команды, pointshop, дроп оружия и т.д.) ловит чат через
-- кастомный хук HG_PlayerSay, который ZChat вызывает ДО рассылки и читает
-- обратно txtTbl[1]. Делаем так же: на "@ " создаём жалобу и прячем сообщение,
-- выставляя txtTbl[1] = "".
hook.Add("HG_PlayerSay", "freports.create", function(ply, txtTbl, text)
	if not isstring(text) then return end
	local prefix = (cfg.command or "@") .. " "
	if string.sub(text, 1, #prefix) ~= prefix then return end
	if not IsValid(ply) then return end

	-- прячем сообщение из общего чата (ZChat читает txtTbl[1] обратно)
	txtTbl[1] = ""

	local reason = string.Trim(string.sub(text, #prefix + 1))
	if reason == "" then
		if not IsStaff(ply) then
			notify(ply, "Укажите причину жалобы после ", Color(255, 200, 100), cfg.command or "@")
		end
		return
	end

	-- Стафф: "@ текст" → ULX admin chat (asay), а не жалоба
	-- Игроки создавать жалобы не могут на себя как на стафф; жалобы — только от обычных игроков.
	if IsStaff(ply) then
		if ulx and ulx.asay then
			ulx.asay(ply, reason)
		else
			-- fallback: ULib.tsay только админам
			ULib.tsay(nil, "[" .. ply:Nick() .. " → ADMINS] " .. reason, Color(255, 165, 0))
		end
		return
	end

	CreateReport(ply, reason)
end)

-- ---------------------------------------------------------------------------
-- Синхронизация: админ зашёл/прогрузил UI — отдаём все открытые жалобы.
-- Клиент шлёт этот запрос, когда становится готов (freports/cl_init.lua).
-- ---------------------------------------------------------------------------
net.Receive("freports.sync", function(_, ply)
	if not IsStaff(ply) then return end

	for reporter, report in pairs(active) do
		if IsValid(reporter) then
			net.Start("freports.send")
				net.WriteTable(report)
			net.Send(ply)
		else
			active[reporter] = nil -- автор уже вышел — чистим висяк
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Админ принимает жалобу
-- ---------------------------------------------------------------------------
net.Receive("freports.accept", function(_, ply)
	if not IsStaff(ply) then return end

	local reporter = net.ReadEntity()
	local report = active[reporter]

	if not report then
		notify(ply, "Такой жалобы не существует!")
		return
	end
	if reporter == ply then
		notify(ply, "Нельзя принять собственную жалобу!")
		return
	end
	if IsValid(report.admin) then
		notify(ply, "Эту жалобу уже разбирает ", Color(255, 200, 100), report.admin:Nick())
		return
	end
	if IsValid(ply.fr_handling) and active[ply.fr_handling] then
		notify(ply, "Вы уже разбираете жалобу!")
		return
	end

	report.admin    = ply
	ply.fr_handling = reporter
	ply:SetNetVar("rp.ReportClaimed", true)
	ply:SetNetVar("rp.LastReport", CurTime())

	net.Start("freports.accept")
		net.WriteEntity(reporter)
		net.WriteEntity(ply)
		net.WriteTable(report)
	net.Send(ReportRecipients(reporter))

	pushLog({
		rtype        = "accept",
		rep_ply_id   = reporter:SteamID64(),
		rep_ply_name = reporter:Nick(),
		rep_ply_job  = reporter:Team(),
		rep_accepted = os.time(),
		admin_id     = ply:SteamID64(),
		admin_name   = ply:Nick(),
		admin_job    = ply:Team(),
	})
end)

-- ---------------------------------------------------------------------------
-- Закрытие жалобы
--   • Стафф: может закрыть ЛЮБУЮ открытую жалобу (свою принятую ИЛИ чужую).
--   • Автор: закрывает только свою.
-- ---------------------------------------------------------------------------
net.Receive("freports.close", function(_, ply)
	if not IsValid(ply) then return end

	-- Стафф: может закрыть любую жалобу — ту, что он принял (fr_handling),
	-- или ту, автором которой является (если по какой-то причине открыл сам),
	-- или вообще любую открытую (например если другой разбирающий вышел).
	-- Дизайн cl_init.lua не шлёт Entity в freports.close, поэтому не читаем его.
	if IsStaff(ply) then
		-- 1. Жалоба, которую этот стафф принял
		if IsValid(ply.fr_handling) and active[ply.fr_handling] then
			CloseReport(ply.fr_handling)
			return
		end
		-- 2. Своя жалоба (стафф-игрок сам подал жалобу — маловероятно, но обрабатываем)
		if active[ply] then
			CloseReport(ply)
			return
		end
		-- 3. Любая открытая (стафф видит окно чужой непринятой жалобы — не бывает в дизайне,
		--    но на случай будущих расширений)
		for rep in pairs(active) do
			CloseReport(rep)
			return
		end
		return
	end

	-- Обычный игрок: только своя жалоба
	if active[ply] then
		CloseReport(ply)
	end
end)

-- ---------------------------------------------------------------------------
-- Сообщение в чат жалобы
-- ---------------------------------------------------------------------------
net.Receive("freports.message", function(_, ply)
	local report
	if active[ply] then
		report = active[ply]
	elseif IsValid(ply.fr_handling) and active[ply.fr_handling] then
		report = active[ply.fr_handling]
	end
	if not report then return end

	local message = string.Trim(net.ReadString() or "")
	if message == "" then return end

	table.insert(report.report_chat, { ply, message })

	local t = {}
	if IsValid(report.reporter) then t[#t + 1] = report.reporter end
	if IsValid(report.admin) then t[#t + 1] = report.admin end

	net.Start("freports.message")
		net.WriteTable({ ply, message })
	net.Send(t)
end)

-- ---------------------------------------------------------------------------
-- Оценка работы администратора (+rep / -rep)
-- ---------------------------------------------------------------------------
net.Receive("freports.reputation", function(_, ply)
	local admin = ply.fr_rateTarget
	if not IsValid(admin) then return end

	local up = net.ReadBool()
	admin.fr_rep = (admin.fr_rep or 0) + (up and 1 or -1)

	local sid = admin:SteamID64()
	if sid then
		sql.Query(("UPDATE freports_admins SET rep = %d WHERE steamid = %s;"):format(admin.fr_rep, sql.SQLStr(sid)))
	end

	if up then
		admin:rp_send_message(Color(255, 120, 120), "[REPORT] ", team.GetColor(ply:Team()), ply:Nick(),
			Color(255, 255, 255), " поставил вам ", Color(100, 255, 100), "+rep")
		if (cfg.reputation_reward or 0) ~= 0 and isfunction(admin.addMoney) then
			admin:addMoney(cfg.reputation_reward)
		end
	else
		admin:rp_send_message(Color(255, 120, 120), "[REPORT] ", team.GetColor(ply:Team()), ply:Nick(),
			Color(255, 255, 255), " поставил вам ", Color(255, 100, 100), "-rep")
	end

	ply.fr_rateTarget = nil
end)

-- Статистика оцениваемого администратора (кнопка в окне оценки)
net.Receive("freports.request_admin_statistic", function(_, ply)
	local admin = ply.fr_rateTarget
	if not IsValid(admin) or not IsStaff(admin) then return end

	local sid = admin:SteamID64()
	if not sid then return end

	flushAdmin(admin) -- актуализируем перед показом
	local row = sql.Query(("SELECT * FROM freports_admins WHERE steamid = %s;"):format(sql.SQLStr(sid)))

	net.Start("freports.request_admin_statistic")
		net.WriteTable(row and row[1] or {})
	net.Send(ply)
end)

-- ---------------------------------------------------------------------------
-- Статистика администрации (concmd reps_stats / adm_stats + поиск/подгрузка)
-- ---------------------------------------------------------------------------
local function cooldown(ply, key, secs)
	if ply[key] and ply[key] > CurTime() then return false end
	ply[key] = CurTime() + (secs or 1)
	return true
end

concommand.Add(cfg.reps_stats_cmd or "reps_stats", function(ply)
	if not IsValid(ply) or not cooldown(ply, "fr_repsCD", 1) then return end
	local data = sql.Query("SELECT * FROM freports_admins ORDER BY rep DESC LIMIT 15 OFFSET 0;")
	net.Start("freports.reports_statistics")
		net.WriteTable(data or {})
	net.Send(ply)
end)

concommand.Add(cfg.adm_stats_cmd or "adm_stats", function(ply)
	if not IsValid(ply) or not cooldown(ply, "fr_admCD", 1) then return end
	net.Start("freports.adm_stats")
		net.WriteTable(mini_logs)
	net.Send(ply)
end)

net.Receive("freports.reports_statistics.load_more", function(_, ply)
	if not cooldown(ply, "fr_searchCD", 1) then return end
	local page = net.ReadInt(32)
	local data = sql.Query(("SELECT * FROM freports_admins ORDER BY rep DESC LIMIT 15 OFFSET %d;"):format(page * 15))
	net.Start("freports.reports_statistics.load_more")
		net.WriteTable(data or {})
	net.Send(ply)
end)

net.Receive("freports.reports_statistics.search", function(_, ply)
	if not cooldown(ply, "fr_searchCD", 1) then return end

	local stype = net.ReadInt(32)
	local term  = net.ReadString()
	local col

	if stype == 1 then       col = "steamid"; term = util.SteamIDTo64(term) or term
	elseif stype == 2 then   col = "steamid"
	elseif stype == 3 then   col = "rank"
	elseif stype == 4 then   col = "name"
	else return end

	local data = sql.Query(("SELECT * FROM freports_admins WHERE %s LIKE '%%%s%%';"):format(
		col, sql.SQLStr(term, true)))

	net.Start("freports.reports_statistics.search")
		net.WriteTable(data or {})
	net.Send(ply)
end)

-- ---------------------------------------------------------------------------
-- Сохранение/инициализация записей админов
-- ---------------------------------------------------------------------------
hook.Add("PlayerInitialSpawn", "freports.ensure_admin", function(ply)
	timer.Simple(10, function() -- ждём, пока ULX выдаст группу
		if IsValid(ply) then ensureAdmin(ply) end
	end)
end)

hook.Add("CAMI.PlayerUsergroupChanged", "freports.rank_changed", function(ply)
	if not IsValid(ply) then return end
	timer.Simple(0.2, function()
		if IsValid(ply) then ensureAdmin(ply) end
	end)
end)

-- Периодический флаш онлайна в БД
timer.Create("freports.flush", 120, 0, function()
	for _, p in ipairs(player.GetAll()) do
		if IsStaff(p) then flushAdmin(p) end
	end
end)

-- ---------------------------------------------------------------------------
-- Отключение игрока
-- ---------------------------------------------------------------------------
hook.Add("PlayerDisconnected", "freports.disconnect", function(ply)
	-- Закрываем жалобу автора
	if active[ply] then
		CloseReport(ply)
	end

	-- Если ушёл админ, разбиравший чью-то жалобу — снимаем его и возвращаем
	-- жалобу в списки администрации (окно автора само покажет «Ожидаем
	-- администратора...», т.к. report.admin станет невалидным).
	if IsValid(ply.fr_handling) and active[ply.fr_handling] then
		local report = active[ply.fr_handling]
		report.admin = nil
		local staff = StaffOnline()
		if #staff > 0 then
			net.Start("freports.send")
				net.WriteTable(report)
			net.Send(staff)
		end
	end

	-- Чистим ссылки на ушедшего как на цель оценки
	for _, p in ipairs(player.GetAll()) do
		if p.fr_rateTarget == ply then p.fr_rateTarget = nil end
	end

	if IsStaff(ply) then flushAdmin(ply) end
end)

print("[ZCity RP] FrePorts backend загружен (SQLite, без plib)")
