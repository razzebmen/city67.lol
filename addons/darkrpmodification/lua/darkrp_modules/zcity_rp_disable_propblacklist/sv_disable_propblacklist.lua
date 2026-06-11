--[[---------------------------------------------------------------------------
ZCity RP — отключение DarkRP/FPP blacklist пропов
---------------------------------------------------------------------------
DarkRP включает FPP Blocked Models — список запрещённых для спавна моделей
(cranes, train cars, prison_cell, и т.д.). У нас своя система whitelist
(zcity_rp_spawnmenu cl_spawnmenu.lua), DarkRP-blacklist не нужен.

Что делаем:
  • Очищаем FPP.BlockedModels при загрузке
  • Чистим SQLite-таблицу FPP_BLOCKEDMODELS1 (чтобы при перезагрузке не вернулось)
  • Выключаем сам функционал через FPP.Settings (toggle = 0, RAW число!)

ВАЖНО: FPP.Settings.FPP_BLOCKMODELSETTINGS1.toggle ДОЛЖНО быть числом (0 или 1),
а не таблицей { value = 0 }. Иначе net.WriteDouble упадёт и сломает DarkRP jobs.
---------------------------------------------------------------------------]]
if not SERVER then return end

local function ApplyDisable()
    if not FPP then return end

    -- 1. Очищаем in-memory таблицу заблокированных моделей
    FPP.BlockedModels = {}

    -- 2. Чистим SQLite чтобы defaultblockedmodels не вернулись при перезагрузке
    if MySQLite and MySQLite.query then
        MySQLite.query("DELETE FROM FPP_BLOCKEDMODELS1;")
    end

    -- 3. Отключаем функционал blocked-моделей через FPP.Settings.
    --    ЗНАЧЕНИЕ ДОЛЖНО БЫТЬ ЧИСЛОМ — net.WriteDouble падает на таблицах.
    if FPP.Settings and FPP.Settings.FPP_BLOCKMODELSETTINGS1 then
        FPP.Settings.FPP_BLOCKMODELSETTINGS1.toggle    = 0
        FPP.Settings.FPP_BLOCKMODELSETTINGS1.propsonly = 0
        FPP.Settings.FPP_BLOCKMODELSETTINGS1.iswhitelist = 0
    end
end

-- Прогоняем сразу (на случай, если FPP уже загружен), и через хук на InitPostEntity.
ApplyDisable()
hook.Add("InitPostEntity", "ZCity_RP_DisablePropBlacklist", ApplyDisable)

-- Также на всякий случай открываем спавн пропов (zcity_rp_admin_perms решит).
hook.Add("PlayerSpawnProp", "ZCity_RP_AllowAllProps", function(ply, model)
    -- nil — не вмешиваемся, пропускаем дальше по цепочке хуков.
end)

print("[ZCity RP] Prop blacklist disable module loaded")
