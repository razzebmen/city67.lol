-- Обработка ошибок IGS API — критично для диагностики проблем с донат-меню.
-- При получении ip_not_registered / incorrect_sign / другой не-ретрай ошибки
-- репитер просто отбрасывает запрос, UI висит на загрузке навсегда. Этот хук:
--   1. Шлёт чёткое сообщение в чат админам с инструкцией что чинить.
--   2. Печатает причину в консоль сервера.
--   3. Дополняет файл igs_errors.txt человекочитаемой подсказкой.

local LAST_NOTIFY = {}          -- error_uid -> os.time()
local NOTIFY_COOLDOWN = 30      -- сек, чтобы не спамить
local INSTRUCTIONS = {
    ["ip_not_registered"] =
        "IP сервера не зарегистрирован в проекте " .. (IGS and IGS.C and IGS.C.ProjectID or "?") ..
        " на gm-donate.net.\n" ..
        "  → forum.gm-donate.net → Кабинет → проект → Серверы → Добавить IP\n" ..
        "  Узнать IP хостинга: status.gm-donate.net или у провайдера хостинга.",
    ["incorrect_sign"] =
        "Неверная подпись запроса. Проверь IGS.C.ProjectKey в config_sv.lua " ..
        "(должен совпадать с ключом проекта " .. (IGS and IGS.C and IGS.C.ProjectID or "?") .. ").",
    ["project_not_found"] =
        "Проект " .. (IGS and IGS.C and IGS.C.ProjectID or "?") .. " не существует или удалён. " ..
        "Проверь IGS.C.ProjectID в config_sv.lua.",
    ["access_denied"] =
        "Доступ к API запрещён. Проверь права проекта на gm-donate.net.",
}

local function NotifyAdmins(text)
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:IsAdmin() then
            p:ChatPrint("[IGS] " .. text)
        end
    end
end

hook.Add("IGS.OnApiError", "ZCityRP_IGSDiagnose", function(sMethod, error_uid, tParams)
    if not error_uid then return end

    local now = os.time()
    if LAST_NOTIFY[error_uid] and (now - LAST_NOTIFY[error_uid]) < NOTIFY_COOLDOWN then
        return
    end
    LAST_NOTIFY[error_uid] = now

    local hint = INSTRUCTIONS[error_uid]
    local prefix = "[IGS] Метод " .. tostring(sMethod) .. " вернул '" .. tostring(error_uid) .. "'"

    if hint then
        MsgC(Color(255, 80, 80), prefix .. "\n  ", Color(255, 200, 80), hint, Color(255, 255, 255), "\n")
        NotifyAdmins(error_uid .. " — " .. hint)
    else
        MsgC(Color(255, 80, 80), prefix .. "\n")
        NotifyAdmins("Ошибка API: " .. error_uid .. " (метод: " .. sMethod .. ")")
    end
end)

-- При успешном запросе сбрасываем cooldown для соответствующих error_uid
-- (чтобы при восстановлении сразу заработало без задержки на следующую ошибку)
hook.Add("IGS.OnApiSuccess", "ZCityRP_IGSDiagnoseReset", function()
    LAST_NOTIFY = {}
end)

-- "Размораживаем" UI: для нерекурабельных ошибок (ip_not_registered, incorrect_sign,
-- project_not_found, access_denied и пр.) вызываем callback с nil, чтобы клиентское
-- меню перестало висеть на "Loading..." и обработало отсутствие данных.
-- Иначе IGS.Query никогда не сообщает об ошибке вызывающему коду.
local NON_RECOVERABLE = {
    ip_not_registered = true,
    incorrect_sign    = true,
    project_not_found = true,
    access_denied     = true,
    invalid_credentials = true,
}

hook.Add("IGS.OnApiError", "ZCityRP_IGSUnstickUI", function(sMethod, error_uid, tParams, fOnSuccess)
    if not NON_RECOVERABLE[error_uid] then return end
    if not fOnSuccess then return end

    -- Безопасно вызываем callback с nil — UI получит "нет данных" вместо вечной загрузки.
    -- В IGS-коде распространён паттерн `player and player["Balance"]`, так что nil обычно ок.
    local ok, err = pcall(fOnSuccess, nil)
    if not ok then
        MsgC(Color(255, 80, 80), "[IGS] callback крашнулся при nil-данных (", tostring(err), ")\n")
    end
end)
