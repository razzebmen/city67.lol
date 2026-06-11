freports.config = {}

-- Префикс жалобы в чате: написать "@ текст" → создаётся жалоба
freports.config.command = "@"

-- Концоманды статистики
freports.config.adm_stats_cmd = "adm_stats"
freports.config.reps_stats_cmd = "reps_stats"

-- Кулдаун между оценками работы администратора (сек)
freports.config.reputation_cd = 180

-- Кулдаун, чтобы одна и та же жалоба не накручивала статистику (сек)
freports.config.add_report_to_statistic_cd = 10

-- Сколько строк хранить в мини-логах (adm_stats)
freports.config.maxp_rep_log = 15

-- Денежная награда администратору за +rep (DarkRP addMoney)
freports.config.reputation_reward = 500

-- Команда (TEAM_*) "на дежурстве" для статистики "Онлайн в админ-профе".
-- На нашем сервере отдельной админ-работы нет, поэтому nil — статистика
-- просто не накапливается (раздел в меню остаётся пустым, без ошибок).
freports.config.onduty_team = nil

-- Кто может ПРИНИМАТЬ жалобы (по ULX usergroup нашего сервера)
freports.config.WhoCanReceiveReports = {
	["superadmin"]  = true,
	["dsuperadmin"] = true,
	["admin"]       = true,
	["dadmin"]      = true,
	["moderator"]   = true,
	["dmoderator"]  = true,
	["operator"]    = false,
	["vip"]         = false,
	["user"]        = false,
}

-- Отображение рангов: [usergroup] = {"Название", Color}
freports.config.BRanks = {
	superadmin  = {"СуперАдмин",   Color(220, 80,  80)},
	dsuperadmin = {"Д-СуперАдмин", Color(180, 60,  60)},
	admin       = {"Админ",        Color(85,  130, 210)},
	dadmin      = {"Д-Админ",      Color(65,  110, 190)},
	moderator   = {"Модератор",    Color(69,  162, 206)},
	dmoderator  = {"Д-Модератор",  Color(50,  140, 185)},
	operator    = {"Оператор",     Color(206, 210, 58)},
	vip         = {"VIP",          Color(255, 215, 0)},
	user        = {"Игрок",        Color(255, 255, 255)},
}
