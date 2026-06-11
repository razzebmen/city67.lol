--[[-------------------------------------------------------------------------
	Обязательные методы:
		:SetPrice()
		:SetDescription()

	Популярные:
		:SetTerm()            --> Срок действия в днях (по умолчанию 0, т.е. одноразовая активация)
		:SetStackable()       --> Разрешает покупать несколько одинаковых предметов
		:SetCategory()        --> Группирует предметы
		:SetIcon()            --> Картинка, модель или материал в качестве иконки (пример в файле)
		:SetHighlightColor()  --> Цвет заголовка
		:SetDiscountedFrom()  --> Скидка
		:SetOnActivate()      --> Свое действие при активации
		:SetCanSee(false)     --> Скрытый предмет

	Полезное:
		gm-donate.net/docs    -->  Подробнее о методах и все остальные
		gm-donate.net/support -->  Быстрая помощь и настройка от нас
		gm-donate.net/mods    -->  Бесплатные модули
---------------------------------------------------------------------------]]

-- :SetValidator(function() end) — отключает автовосстановление ранга при реконнекте.
-- Без этого IGS переназначает группу каждый раз когда у игрока активна покупка,
-- но текущая группа не совпадает (например, после ручного снятия админкой).
-- Снятие при истечении срока продолжает работать через checkGroups в ulx.lua.

-- Хелпер для зачисления внутриигровой валюты через ZCity RP API.
local function GiveCurrency(ply, amount)
	if not IsValid(ply) then return end
	if not CurrentRound then return end
	local round = CurrentRound()
	if not round or round.name ~= "roleplay" then
		ply:ChatPrint("[Донат] Деньги придут когда RP-раунд начнётся.")
		return
	end
	round:AddMoney(ply, amount, "igs_currency", nil)
	ply:ChatPrint(string.format("[Донат] Зачислено %s ден.", string.Comma(amount)))
end

-- ============================================================================
-- [★] Хиты продаж — добавляется ПЕРВЫМ, чтобы быть в начале донат-меню.
-- Категория названа со звёздочкой ★ (поддерживается шрифтами IGS) и большими
-- буквами — это лексикографически выводит её в самый верх списка.
-- ============================================================================

IGS("VIP — самый популярный пак", "vip_perma_pop"):SetULXGroup("vip"):SetValidator(function() end)
	:SetPrice(599)
	:SetTerm(30)
	:SetCategory("[★] Хиты продаж")
	:SetHighlightColor(Color(255, 200, 60))
	:SetDescription(
		"Поддержи проект и получи возможности, недоступные обычным игрокам.\n" ..
		"\n" ..
		"Что входит в VIP:\n" ..
		"  — Гарантированный заход на сервер, даже когда он забит\n" ..
		"  — Стройка: пропы, физган и тулган в любой момент\n" ..
		"  — Эксклюзивные скины оружия — выбор и предпросмотр в ESC → «Скины»\n" ..
		"  — Заметная отметка в табло и в чате\n" ..
		"  — Тёплая благодарность от админ-состава :)\n" ..
		"\n" ..
		"Срок действия: 30 дней."
	)
	:SetIcon("https://i.imgur.com/Zg9JJCq.png")

IGS("Админ — выбор большинства", "dadmin_perma_pop"):SetULXGroup("dadmin"):SetValidator(function() end)
	:SetPrice(2299)
	:SetTerm(30)
	:SetCategory("[★] Хиты продаж")
	:SetHighlightColor(Color(85, 130, 210))
	:SetDescription(
		"Самая востребованная админка.\n" ..
		"Полный набор инструментов: бан до 3 недель, заморозка, режим бога,\n" ..
		"невидимость, джейлтп, jobban, выдача оружия и многое другое.\n" ..
		"\n" ..
		"Срок действия: 30 дней."
	)
	:SetIcon("https://cdn.jsdelivr.net/gh/twitter/twemoji/assets/72x72/2b50.png")

IGS("500.000 денег — лучшая цена", "money_pack_500k_pop"):SetValidator(function() end):SetStackable()
	:SetPrice(419)
	:SetCategory("[★] Хиты продаж")
	:SetHighlightColor(Color(120, 220, 120))
	:SetDescription(
		"Самый выгодный пакет валюты — берут чаще остальных.\n" ..
		"500.000 ден. зачисляются мгновенно после покупки.\n" ..
		"Можно купить несколько раз, валюта суммируется."
	)
	:SetIcon("https://cdn.jsdelivr.net/gh/twitter/twemoji/assets/72x72/1f4b0.png")
	:SetOnActivate(function(ply) GiveCurrency(ply, 500000) end)


-- ─── Донат-персонал ──────────────────────────────────────────────────────────

IGS("Супер-Админ", "dsuperadmin_perma"):SetULXGroup("dsuperadmin"):SetValidator(function() end)
	:SetPrice(3499)
	:SetTerm(30)
	:SetCategory("Донат-персонал")
	:SetHighlightColor(Color(220, 80, 80))
	:SetDescription(
		"Бан без ограничения по сроку.\n" ..
		"Выдача валюты любым игрокам.\n" ..
		"Полный набор команд Админа.\n" ..
		"Срок: 30 дней."
	)
	:SetIcon("https://cdn.jsdelivr.net/gh/twitter/twemoji/assets/72x72/1f451.png") -- 👑

IGS("Админ", "dadmin_perma"):SetULXGroup("dadmin"):SetValidator(function() end)
	:SetPrice(2299)
	:SetTerm(30)
	:SetCategory("Донат-персонал")
	:SetHighlightColor(Color(85, 130, 210))
	:SetDescription(
		"Бан до 3 недель, режим бога.\n" ..
		"Невидимость, заморозка, джейлтп.\n" ..
		"Управление работами (jobban).\n" ..
		"Доступ к выдаче оружия.\n" ..
		"Полный набор команд Модератора.\n" ..
		"Срок: 30 дней."
	)
	:SetIcon("https://cdn.jsdelivr.net/gh/twitter/twemoji/assets/72x72/2b50.png") -- ⭐

IGS("Модератор", "dmoderator_perma"):SetULXGroup("dmoderator"):SetValidator(function() end)
	:SetPrice(1199)
	:SetTerm(30)
	:SetCategory("Донат-персонал")
	:SetHighlightColor(Color(69, 162, 206))
	:SetDescription(
		"Бан, кик, мут до 2 недель.\n" ..
		"Джейл, гэг, нок, нокклип.\n" ..
		"Телепортация, слэп, слэй.\n" ..
		"Скринграб и слежка за игроками.\n" ..
		"Доступ к пропам.\n" ..
		"Срок: 30 дней."
	)
	:SetIcon("https://cdn.jsdelivr.net/gh/twitter/twemoji/assets/72x72/1f6e1.png") -- 🛡️

-- ─── VIP статус ──────────────────────────────────────────────────────────────

IGS("VIP", "vip_perma"):SetULXGroup("vip"):SetValidator(function() end)
	:SetPrice(599)
	:SetTerm(30)
	:SetCategory("Статусы")
	:SetHighlightColor(Color(255, 200, 60))
	:SetDescription(
		"Поддержи проект и получи возможности, недоступные обычным игрокам.\n" ..
		"\n" ..
		"Что входит в VIP:\n" ..
		"  — Гарантированный заход на сервер, даже когда он забит\n" ..
		"  — Стройка: пропы, физган и тулган в любой момент\n" ..
		"  — Эксклюзивные скины оружия — выбор и предпросмотр в ESC → «Скины»\n" ..
		"  — Заметная отметка в табло и в чате\n" ..
		"  — Тёплая благодарность от админ-состава :)\n" ..
		"\n" ..
		"Срок действия: 30 дней."
	)
	:SetIcon("https://i.imgur.com/Zg9JJCq.png")

-- ─── Игровая валюта (пакеты денег) ───────────────────────────────────────────
-- Базовые цены 100/200/350/500, к каждой +15% наценка и округление "в 9".
-- Логика выдачи: round:AddMoney(ply, amount, "igs_currency") — серверный API
-- ZCity RP, тот же что использует `ulx givemoney`. Безопасен оффлайн —
-- если round не активен, активация просто ничего не делает (IGS повторит позже).

IGS("100.000 денег", "money_pack_100k"):SetValidator(function() end):SetStackable()
	:SetPrice(119)
	:SetCategory("Валюта")
	:SetHighlightColor(Color(100, 200, 100))
	:SetDescription(
		"Пакет внутриигровой валюты: 100.000 ден.\n" ..
		"Деньги зачисляются на счёт мгновенно."
	)
	:SetIcon("https://cdn.jsdelivr.net/gh/twitter/twemoji/assets/72x72/1f4b5.png") -- 💵
	:SetOnActivate(function(ply) GiveCurrency(ply, 100000) end)

IGS("250.000 денег", "money_pack_250k"):SetValidator(function() end):SetStackable()
	:SetPrice(249)
	:SetCategory("Валюта")
	:SetHighlightColor(Color(100, 200, 100))
	:SetDescription(
		"Пакет внутриигровой валюты: 250.000 ден.\n" ..
		"Деньги зачисляются на счёт мгновенно."
	)
	:SetIcon("https://cdn.jsdelivr.net/gh/twitter/twemoji/assets/72x72/1f4b5.png")
	:SetOnActivate(function(ply) GiveCurrency(ply, 250000) end)

IGS("500.000 денег", "money_pack_500k"):SetValidator(function() end):SetStackable()
	:SetPrice(419)
	:SetCategory("Валюта")
	:SetHighlightColor(Color(100, 200, 100))
	:SetDescription(
		"Пакет внутриигровой валюты: 500.000 ден.\n" ..
		"Деньги зачисляются на счёт мгновенно."
	)
	:SetIcon("https://cdn.jsdelivr.net/gh/twitter/twemoji/assets/72x72/1f4b0.png") -- 💰
	:SetOnActivate(function(ply) GiveCurrency(ply, 500000) end)

IGS("1.000.000 денег", "money_pack_1m"):SetValidator(function() end):SetStackable()
	:SetPrice(599)
	:SetCategory("Валюта")
	:SetHighlightColor(Color(255, 200, 80))
	:SetDescription(
		"Пакет внутриигровой валюты: 1.000.000 ден.\n" ..
		"Деньги зачисляются на счёт мгновенно."
	)
	:SetIcon("https://cdn.jsdelivr.net/gh/twitter/twemoji/assets/72x72/1f4b0.png") -- 💰
	:SetOnActivate(function(ply) GiveCurrency(ply, 1000000) end)
