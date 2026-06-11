--[[---------------------------------------------------------------------------
city67 — Тканевый мешок (cl)
---------------------------------------------------------------------------
Архитектура отрисовки в zcity:
* Игрок не рендерится напрямую — за него рендерится FakeRagdoll (ent).
* Player ↔ FakeRagdoll связь: ply.FakeRagdoll = ent  (см. lua/homigrad/fake/).
* NW-флаги (bagmasked) живут на player'е, не на ragdoll'е.
* Bones к которым крепимся (ValveBiped.Bip01_Head1) есть и у player и у ragdoll.

Что мы делаем:
1. Каждый кадр (PostDrawTranslucentRenderables) проходим по player.GetAll()
   и для каждого "bagmasked" — рисуем ClientsideModel(bag_prop.mdl) и
   обнуляем scale кости головы.
2. Используем визуальный ent: ply.FakeRagdoll если он есть, иначе сам ply.
3. При снятии мешка — возвращаем scale=1 для всех ent'ов которые трогали.
4. Q-меню — eye-trace может вернуть ragdoll → используем hg.RagdollOwner.
---------------------------------------------------------------------------]]
if not CLIENT then return end

-- Дефолтные значения откалиброванного положения мешка относительно
-- head-bone'а ValveBiped.Bip01_Head1. Получены через bagmask_calibrate.
-- Подходит для большинства HL2-моделей (citizen / group03m / monolithservers).
local DEFAULT_BAGMASK = {
    x  = -28.212,
    y  = -5.107,
    z  =  2.148,
    p  =  5.689,
    ya = 99.013,
    r  = 93.871,
}

local cvX  = CreateClientConVar("bagmask_head_x",  tostring(DEFAULT_BAGMASK.x),  true, false)
local cvY  = CreateClientConVar("bagmask_head_y",  tostring(DEFAULT_BAGMASK.y),  true, false)
local cvZ  = CreateClientConVar("bagmask_head_z",  tostring(DEFAULT_BAGMASK.z),  true, false)
local cvP  = CreateClientConVar("bagmask_head_p",  tostring(DEFAULT_BAGMASK.p),  true, false)
local cvYA = CreateClientConVar("bagmask_head_ya", tostring(DEFAULT_BAGMASK.ya), true, false)
local cvR  = CreateClientConVar("bagmask_head_r",  tostring(DEFAULT_BAGMASK.r),  true, false)

-- ─── Миграция cvar'ов ───────────────────────────────────────────────────────
-- archive-cvar'ы сохраняются у клиента в client.vdf. После того как клиент
-- ОДИН раз создал cvar с дефолтом, любое изменение default в коде уже не
-- применится к нему. Поэтому ведём версию: если у клиента CFG_VERSION ниже
-- текущей — перезатираем все 6 параметров на новые DEFAULT_BAGMASK.
-- Если игрок откалибровал себе своё — он сам потом перезапишет через
-- bagmask_calibrate / bagmask_set.
local BAGMASK_CFG_VERSION = 2  -- ↑ инкрементировать при изменении DEFAULT_BAGMASK
local cvVer = CreateClientConVar("bagmask_cfg_ver", "0", true, false)

local function applyDefaults()
    RunConsoleCommand("bagmask_head_x",  tostring(DEFAULT_BAGMASK.x))
    RunConsoleCommand("bagmask_head_y",  tostring(DEFAULT_BAGMASK.y))
    RunConsoleCommand("bagmask_head_z",  tostring(DEFAULT_BAGMASK.z))
    RunConsoleCommand("bagmask_head_p",  tostring(DEFAULT_BAGMASK.p))
    RunConsoleCommand("bagmask_head_ya", tostring(DEFAULT_BAGMASK.ya))
    RunConsoleCommand("bagmask_head_r",  tostring(DEFAULT_BAGMASK.r))
    RunConsoleCommand("bagmask_cfg_ver", tostring(BAGMASK_CFG_VERSION))
end

hook.Add("InitPostEntity", "zcity_bagmask_cfg_migrate", function()
    if cvVer:GetInt() < BAGMASK_CFG_VERSION then
        applyDefaults()
        print("[Мешок] Конфиг обновлён до версии " .. BAGMASK_CFG_VERSION)
    end
end)

-- 100% затемнение для носителя мешка — alpha 255 (раньше было 179 ≈ 70%,
-- через мешок реально видно картинку, что ломает RP-эффект «темно»).
-- Если нужен мягкий вариант — суперадмин может выключить через
-- bagmask_blackout_off (см. ниже).
local clrBlack = Color(0, 0, 0, 255)
local vec_zero = Vector(0, 0, 0)
local vec_one  = Vector(1, 1, 1)

-- ─── Затемнение для носителя ─────────────────────────────────────────────────
-- HUDPaint-слой alpha 255 — полное затемнение. Без пост-эффекта на 3D-сцену
-- (раньше был DrawColorModify с brightness=-2 — иногда «залипал» в shader
-- state при горячей перезагрузке).

-- Одноразовый сброс PP-эффекта от предыдущих версий: если у клиента
-- остался залипший DrawColorModify (brightness=-2), без рестарта он
-- сохраняется в shader state. Делаем 1 раз restore при загрузке файла.
hook.Add("RenderScreenspaceEffects", "zcity_bagmask_pp_oneshot_restore", function()
    DrawColorModify({
        ["$pp_colour_brightness"] = 0,
        ["$pp_colour_contrast"]   = 1,
        ["$pp_colour_colour"]     = 1,
    })
    hook.Remove("RenderScreenspaceEffects", "zcity_bagmask_pp_oneshot_restore")
end)

hook.Add("HUDPaint", "zcity_bagmask_blackout", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNWBool("bagmasked", false) then return end
    if zcity_bagmask_blackoutDisabled then return end
    surface.SetDrawColor(clrBlack)
    surface.DrawRect(0, 0, ScrW(), ScrH())
    draw.SimpleText("На голове мешок. Жди пока союзник снимет.",
        "DermaLarge", ScrW() / 2, ScrH() - 60,
        Color(220, 220, 220, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

hook.Add("HUDShouldDraw", "zcity_bagmask_hidehud", function(name)
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNWBool("bagmasked", false) then return end
    if name == "CHudHealth" or name == "CHudBattery" or name == "CHudAmmo"
       or name == "CHudSecondaryAmmo" or name == "CHudCrosshair"
       or name == "CHudWeaponSelection" or name == "CHudDamageIndicator" then
        return false
    end
end)

net.Receive("zcity_bagmask_clear", function() end)


-- ─── Рендер мешка + скрытие головы ───────────────────────────────────────────
-- Кэш: ply -> ClientsideModel мешка
local bagModels = {}
-- Кэш: entity -> true если мы установили scale=0 на голову у этой entity
local hiddenHeads = {}

local function cleanupBagModel(ply)
    if IsValid(bagModels[ply]) then bagModels[ply]:Remove() end
    bagModels[ply] = nil
end

-- Восстановить scale=1 на голове у конкретной entity
local function restoreHead(ent)
    if not IsValid(ent) then return end
    local bone = ent.LookupBone and ent:LookupBone("ValveBiped.Bip01_Head1")
    if not bone then return end
    ent:ManipulateBoneScale(bone, vec_one)
end

-- Получить визуальную entity для player'а: FakeRagdoll если есть, иначе сам.
local function getVisualEnt(ply)
    if not IsValid(ply) then return nil end
    if IsValid(ply.FakeRagdoll) then return ply.FakeRagdoll end
    return ply
end

-- Скрыть голову + нарисовать мешок для одного игрока
local function drawBagFor(ply)
    local ent = getVisualEnt(ply)
    if not IsValid(ent) then return end

    local bone = ent.LookupBone and ent:LookupBone("ValveBiped.Bip01_Head1")
    if not bone then return end

    -- 1) Получаем матрицу bone головы каждый кадр (с учётом текущей анимации).
    --    GetBoneMatrix даёт актуальную mat — это «голова сейчас», поэтому
    --    мешок будет двигаться синхронно с поворотами головы.
    ent:SetupBones()
    local mat = ent:GetBoneMatrix(bone)
    if not mat then return end
    local bonePos, boneAng = mat:GetTranslation(), mat:GetAngles()

    -- 2) Скрываем голову на визуальной entity (после получения её матрицы).
    ent:ManipulateBoneScale(bone, vec_zero)
    hiddenHeads[ent] = true

    -- 3) Создаём ClientsideModel мешка (без bonemerge — у bag_prop.mdl 0 bone'ов).
    local mdl = bagModels[ply]
    if not IsValid(mdl) then
        mdl = ClientsideModel("models/mdl/bag_prop.mdl", RENDERGROUP_OPAQUE)
        if not IsValid(mdl) then return end
        mdl:SetNoDraw(true)
        mdl:SetModelScale(1)
        bagModels[ply] = mdl
    end

    -- 4) Применяем offset через LocalToWorld — bone matrix уже содержит
    --    актуальный поворот, поэтому мешок крутится с головой.
    local offsetVec = Vector(cvX:GetFloat(), cvY:GetFloat(), cvZ:GetFloat())
    local offsetAng = Angle(cvP:GetFloat(), cvYA:GetFloat(), cvR:GetFloat())
    local newPos, newAng = LocalToWorld(offsetVec, offsetAng, bonePos, boneAng)

    mdl:SetPos(newPos)
    mdl:SetAngles(newAng)
    mdl:SetupBones()
    mdl:DrawModel()
end

-- Главный хук: каждый кадр после рендера opaque мира (модель не translucent
-- — рисуем в opaque-фазе чтобы избежать blend и "полупрозрачности").
hook.Add("PostDrawOpaqueRenderables", "zcity_bagmask_main_render", function(bDepth, bSkybox)
    if bSkybox then return end
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNWBool("bagmasked", false) then
            drawBagFor(ply)
        else
            -- Снят: убираем cached модель и восстанавливаем голову
            if bagModels[ply] then cleanupBagModel(ply) end
        end
    end
end)

-- Восстановление головы. PrePlayerDraw срабатывает ДО рендера каждого ent —
-- если ent помечен hidden, но соответствующего player'а с bagmasked нет,
-- сбрасываем scale обратно (защита от "залипания" головы скрытой после снятия).
hook.Add("Think", "zcity_bagmask_head_safety", function()
    for ent, _ in pairs(hiddenHeads) do
        if not IsValid(ent) then hiddenHeads[ent] = nil continue end
        -- Найдём player'а: либо ent — это сам player, либо ragdoll-владельца.
        local ply
        if ent:IsPlayer() then
            ply = ent
        else
            -- ragdoll: ищем владельца по player.FakeRagdoll
            for _, p in ipairs(player.GetAll()) do
                if p.FakeRagdoll == ent then ply = p break end
            end
        end
        if not IsValid(ply) or not ply:GetNWBool("bagmasked", false) then
            restoreHead(ent)
            hiddenHeads[ent] = nil
        end
    end
end)

hook.Add("EntityRemoved", "zcity_bagmask_mdl_gc", function(ent)
    if bagModels[ent] then cleanupBagModel(ent) end
    hiddenHeads[ent] = nil
end)


-- ─── Жест надевания (net от сервера) ─────────────────────────────────────────
net.Receive("zcity_bagmask_gesture", function()
    local owner = net.ReadEntity()
    if not IsValid(owner) or not owner:IsPlayer() then return end
    owner:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD,
        ACT_HL2MP_GESTURE_RANGE_ATTACK_SLAM, true)
end)

-- ─── Калибровка: получить данные от сервера и сохранить offset ───────────────
net.Receive("zcity_bagmask_calib_done", function()
    local propPos = net.ReadVector()
    local propAng = net.ReadAngle()
    local target  = net.ReadEntity()
    if not IsValid(target) then return end

    local bone = target:LookupBone("ValveBiped.Bip01_Head1")
    if not bone then return end
    local bonePos, boneAng = target:GetBonePosition(bone)
    if not bonePos then return end

    local localPos, localAng = WorldToLocal(propPos, propAng, bonePos, boneAng)
    RunConsoleCommand("bagmask_head_x",  tostring(math.Round(localPos.x, 3)))
    RunConsoleCommand("bagmask_head_y",  tostring(math.Round(localPos.y, 3)))
    RunConsoleCommand("bagmask_head_z",  tostring(math.Round(localPos.z, 3)))
    RunConsoleCommand("bagmask_head_p",  tostring(math.Round(localAng.p, 3)))
    RunConsoleCommand("bagmask_head_ya", tostring(math.Round(localAng.y, 3)))
    RunConsoleCommand("bagmask_head_r",  tostring(math.Round(localAng.r, 3)))
    print(string.format("[Мешок] offset сохранён: Vec(%g, %g, %g) Ang(%g, %g, %g)",
        localPos.x, localPos.y, localPos.z, localAng.p, localAng.y, localAng.r))
end)

-- ─── Q-меню (radialOptions): «Снять мешок» ───────────────────────────────────
-- В zcity hg.eyeTrace часто возвращает FakeRagdoll цели, а не самого player.
-- Конвертируем через hg.RagdollOwner если результат — ragdoll.
hook.Add("radialOptions", "zcity_bagmask", function()
    if not hg or not hg.radialOptions then return end
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return end
    if lp.organism and lp.organism.otrub then return end

    local tr = hg.eyeTrace and hg.eyeTrace(lp) or lp:GetEyeTrace()
    local ent = tr and tr.Entity
    if not IsValid(ent) then return end

    local target
    if ent:IsPlayer() then
        target = ent
    elseif ent:IsRagdoll() and hg.RagdollOwner then
        target = hg.RagdollOwner(ent)
    end
    if not IsValid(target) or not target:IsPlayer() then return end
    if not target:GetNWBool("bagmasked", false) then return end
    if lp:GetPos():Distance(target:GetPos()) > 200 then return end

    hg.radialOptions[#hg.radialOptions + 1] = {
        function()
            net.Start("zcity_bagmask_request")
            net.WriteString("trace")
            net.SendToServer()
        end,
        "Снять мешок",
    }
end)

-- ─── Консольные команды ──────────────────────────────────────────────────────
concommand.Add("bagmask_self", function()
    net.Start("zcity_bagmask_debug")
    net.SendToServer()
end, nil, "Надеть/снять мешок на себя (дебаг)")

concommand.Add("bagmask_head_print", function()
    print(string.format("[Мешок] offset: Vec(%g, %g, %g)  Ang(%g, %g, %g)",
        cvX:GetFloat(), cvY:GetFloat(), cvZ:GetFloat(),
        cvP:GetFloat(), cvYA:GetFloat(), cvR:GetFloat()))
end, nil, "Вывести текущий offset мешка на голове")

-- ─── Live-тюнинг мешка (дебаг для админа) ───────────────────────────────────
-- Все команды применяются МГНОВЕННО — PostDrawOpaqueRenderables читает cvar'ы
-- каждый кадр. Надеть мешок на себя (или на бота): `bagmask_self` (без аргументов
-- надевает/снимает на себя) — увидишь живой результат.
--
-- Дефолтные значения: pitch=0  yaw=0  roll=0   x=7.29  y=1.69  z=-28.64
--
-- Удобный воркфлоу:
--   bagmask_show           — показать текущие значения в чате
--   bagmask_set p 90       — абсолютно: pitch = 90
--   bagmask_set z -20      — абсолютно: z = -20
--   bagmask_adj p 10       — инкрементально: pitch += 10
--   bagmask_adj z -2       — инкрементально: z -= 2
--   bagmask_tune 90 0 0 7.29 1.69 -28.64   — все 6 за раз
--   bagmask_reset          — сбросить к дефолтам
-- ───────────────────────────────────────────────────────────────────────────

-- Соответствие ключ → cvar
local TUNE_KEYS = {
    p  = cvP,  pitch = cvP,
    y  = cvYA, ya    = cvYA, yaw   = cvYA,
    r  = cvR,  roll  = cvR,
    x  = cvX,
    z  = cvZ,
}
-- Отдельно для оси Y (позиция) — конфликт с y(yaw). Делаем явные альтернативы:
TUNE_KEYS.posy = cvY  -- использовать `posy` если хочешь позицию по Y

local DEFAULTS = {
    p  = DEFAULT_BAGMASK.p,
    ya = DEFAULT_BAGMASK.ya,
    r  = DEFAULT_BAGMASK.r,
    x  = DEFAULT_BAGMASK.x,
    y  = DEFAULT_BAGMASK.y,
    z  = DEFAULT_BAGMASK.z,
}

local function showCurrent()
    chat.AddText(Color(255,200,80), "[Мешок] ", color_white,
        string.format("Ang(p=%g, y=%g, r=%g)  Vec(x=%g, y=%g, z=%g)",
            cvP:GetFloat(), cvYA:GetFloat(), cvR:GetFloat(),
            cvX:GetFloat(), cvY:GetFloat(), cvZ:GetFloat()))
end

concommand.Add("bagmask_show", showCurrent,
    nil, "Показать текущие angle+offset мешка")

concommand.Add("bagmask_set", function(_, _, args)
    local key = string.lower(args[1] or "")
    local val = tonumber(args[2])
    local cv  = TUNE_KEYS[key]
    if not cv or not val then
        chat.AddText(Color(220,80,80), "[Мешок] ", color_white,
            "Использование: bagmask_set <p|y|r|x|posy|z> <число>")
        return
    end
    RunConsoleCommand(cv:GetName(), tostring(val))
    chat.AddText(Color(255,200,80), "[Мешок] ", color_white,
        key .. " = " .. val)
end, nil, "Установить параметр мешка: bagmask_set <p|y|r|x|posy|z> <число>")

concommand.Add("bagmask_adj", function(_, _, args)
    local key = string.lower(args[1] or "")
    local delta = tonumber(args[2])
    local cv  = TUNE_KEYS[key]
    if not cv or not delta then
        chat.AddText(Color(220,80,80), "[Мешок] ", color_white,
            "Использование: bagmask_adj <p|y|r|x|posy|z> <дельта>")
        return
    end
    local newVal = cv:GetFloat() + delta
    RunConsoleCommand(cv:GetName(), tostring(newVal))
    chat.AddText(Color(255,200,80), "[Мешок] ", color_white,
        string.format("%s: %+g → %g", key, delta, newVal))
end, nil, "Изменить параметр мешка на дельту: bagmask_adj <p|y|r|x|posy|z> <дельта>")

concommand.Add("bagmask_reset", function()
    RunConsoleCommand("bagmask_head_p",  tostring(DEFAULTS.p))
    RunConsoleCommand("bagmask_head_ya", tostring(DEFAULTS.ya))
    RunConsoleCommand("bagmask_head_r",  tostring(DEFAULTS.r))
    RunConsoleCommand("bagmask_head_x",  tostring(DEFAULTS.x))
    RunConsoleCommand("bagmask_head_y",  tostring(DEFAULTS.y))
    RunConsoleCommand("bagmask_head_z",  tostring(DEFAULTS.z))
    chat.AddText(Color(120,220,120), "[Мешок] ", color_white,
        "Сброшено к дефолтам")
end, nil, "Сбросить все параметры мешка к дефолтным значениям")

-- Старая «всё за раз» команда — оставлена для совместимости.
-- bagmask_tune <pitch> <yaw> <roll> [x] [y] [z]
concommand.Add("bagmask_tune", function(_, _, args)
    local p  = tonumber(args[1]) or 0
    local ya = tonumber(args[2]) or 0
    local r  = tonumber(args[3]) or 0
    RunConsoleCommand("bagmask_head_p",  tostring(p))
    RunConsoleCommand("bagmask_head_ya", tostring(ya))
    RunConsoleCommand("bagmask_head_r",  tostring(r))
    if args[4] then RunConsoleCommand("bagmask_head_x", args[4]) end
    if args[5] then RunConsoleCommand("bagmask_head_y", args[5]) end
    if args[6] then RunConsoleCommand("bagmask_head_z", args[6]) end
    chat.AddText(Color(255,200,80), "[Мешок] ", color_white,
        string.format("Ang(%g, %g, %g)%s", p, ya, r,
            args[4] and (" Vec("..args[4]..", "..(args[5] or "?")..", "..(args[6] or "?")..")") or ""))
end, nil, "Установить все 3 угла (и опционально все 3 позиции) сразу")


-- ─── Скрытие аксессуаров на голове у носителя мешка ──────────────────────────
-- ZCity рисует accessory через DrawAccesories(ply, ent, name, data, islply).
-- Перехватываем функцию: если у player'а bagmasked=true и accessory крепится
-- к ValveBiped.Bip01_Head1 — пропускаем рендер.
hook.Add("InitPostEntity", "zcity_bagmask_wrap_accessories", function()
    if not DrawAccesories or _G.zcity_bagmask_origDraw then return end
    _G.zcity_bagmask_origDraw = DrawAccesories
    function DrawAccesories(ply, ent, name, data, ...)
        if IsValid(ply) and ply.GetNWBool and ply:GetNWBool("bagmasked", false) then
            if data and data.bone == "ValveBiped.Bip01_Head1" then
                return -- скрываем head-accessory
            end
        end
        return _G.zcity_bagmask_origDraw(ply, ent, name, data, ...)
    end
end)
-- На случай если файл cl_zcity_bagmask.lua грузится ПОСЛЕ инициализации gmod —
-- запускаем wrapper немедленно тоже.
if DrawAccesories and not _G.zcity_bagmask_origDraw then
    _G.zcity_bagmask_origDraw = DrawAccesories
    function DrawAccesories(ply, ent, name, data, ...)
        if IsValid(ply) and ply.GetNWBool and ply:GetNWBool("bagmasked", false) then
            if data and data.bone == "ValveBiped.Bip01_Head1" then
                return
            end
        end
        return _G.zcity_bagmask_origDraw(ply, ent, name, data, ...)
    end
end

-- ─── Скрытие шлемов и масок (hg.armor.head/face) ─────────────────────────────
-- DrawArmors(ply, armors, ent) — armors это таблица {placement = armorName}.
-- Пропускаем placement="head" и "face" для bagmasked игроков.
local function wrapDrawArmors()
    if not DrawArmors or _G.zcity_bagmask_origDrawArmors then return end
    _G.zcity_bagmask_origDrawArmors = DrawArmors
    function DrawArmors(ply, armors, ent, ...)
        if IsValid(ply) and ply.GetNWBool and ply:GetNWBool("bagmasked", false)
           and istable(armors) then
            -- Делаем поверхностную копию таблицы без head/face слотов
            local filtered = {}
            for placement, armor in pairs(armors) do
                if placement ~= "head" and placement ~= "face" then
                    filtered[placement] = armor
                end
            end
            return _G.zcity_bagmask_origDrawArmors(ply, filtered, ent, ...)
        end
        return _G.zcity_bagmask_origDrawArmors(ply, armors, ent, ...)
    end
end
hook.Add("InitPostEntity", "zcity_bagmask_wrap_armors", wrapDrawArmors)
wrapDrawArmors()

-- ─── Команда отключения затемнения (для суперадминов) ────────────────────────
-- Использование: bagmask_blackout_off  → выключить чёрный экран у себя
--                bagmask_blackout_on   → включить обратно
zcity_bagmask_blackoutDisabled = false

local function isSuperAdminCl(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    local g = ply:GetUserGroup()
    return g == "superadmin" or g == "dsuperadmin"
end

concommand.Add("bagmask_blackout_off", function()
    local lp = LocalPlayer()
    if not isSuperAdminCl(lp) then
        chat.AddText(Color(220,80,80), "[Мешок] ", color_white, "Только суперадмин.")
        return
    end
    zcity_bagmask_blackoutDisabled = true
    chat.AddText(Color(255,200,80), "[Мешок] ", color_white,
        "Затемнение временно ОТКЛЮЧЕНО (только у тебя).")
end, nil, "Отключить затемнение мешка (суперадмин)")

concommand.Add("bagmask_blackout_on", function()
    local lp = LocalPlayer()
    if not isSuperAdminCl(lp) then
        chat.AddText(Color(220,80,80), "[Мешок] ", color_white, "Только суперадмин.")
        return
    end
    zcity_bagmask_blackoutDisabled = false
    chat.AddText(Color(120,220,120), "[Мешок] ", color_white,
        "Затемнение ВКЛЮЧЕНО.")
end, nil, "Включить затемнение мешка обратно (суперадмин)")
