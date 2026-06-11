-- [ZCITY_PORT] Файл автоматически мигрирован из gamemodes/zcity/.../modes/roleplay/config.lua
-- Источник: _backup_20260522_182916/zcity/gamemode/modes/roleplay/
-- Все обращения к CurrentRound()/MODE/round заменены на ZCity_RP.
-- ZCity_RP — это таблица-обёртка, имитирующая старый MODE-namespace,
--           содержит Jobs, AddMoney, TakeMoney, GetMoney, CityTaxRate и т.д.
-- Реализация в darkrp_modules/zcity_rp_core/sh_zcity_rp_namespace.lua

-- Конфигурация режима Roleplay
-- Этот файл можно редактировать для настройки режима

-- Время автоматического респавна (в секундах)
ROLEPLAY_RESPAWN_TIME = 5

-- Радиус зоны защиты от доставания оружия вокруг точки спавна (юниты).
-- Пока игрок находится в этом радиусе от своей точки респавна, он не может
-- переключиться с weapon_hands_sh на боевое оружие. Уйдёт за радиус — защита
-- автоматически снимается.
ROLEPLAY_SPAWN_PROTECT_RADIUS = 300

-- Включить/выключить автоматический респавн
ROLEPLAY_AUTO_RESPAWN = true

-- Включить/выключить дружественный огонь
ROLEPLAY_FRIENDLY_FIRE = true

-- Множитель вины за атаку союзников
ROLEPLAY_GUILT_MULTIPLIER = 2.0

-- Включить/выключить спавн лута
ROLEPLAY_LOOT_ENABLED = true

-- Включить/выключить случайные точки спавна
ROLEPLAY_RANDOM_SPAWNS = true

-- Классы игроков по умолчанию для разных типов карт
ROLEPLAY_MAP_CLASSES = {
    ["rp_*"] = "citizen",
    ["gm_*"] = "citizen",
    ["*"] = "citizen"
}

-- Цвета для ролей
ROLEPLAY_COLORS = {
    citizen = Color(100, 200, 100),
    refugee = Color(200, 150, 50),
    rebel = Color(255, 100, 50)
}

-- Сообщения режима
ROLEPLAY_MESSAGES = {
    start = "Режим Roleplay начался! Наслаждайтесь бесконечной игрой!",
    death = "Вы возродитесь через %d секунд...",
    respawn = "Вы возродились!"
}
