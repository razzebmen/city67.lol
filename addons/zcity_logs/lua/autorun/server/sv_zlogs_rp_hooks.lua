--[[
    ZCity Logs — хуки RP-эвентов.

    Стратегия: оборачиваем существующие net.Receive обработчики через
    net.Receivers без чтения payload. Сравниваем состояние ДО и ПОСЛЕ
    вызова оригинала и логируем разницу. Так не ломаем существующую логику.

    Для денег используем уже существующий хук RoleplayMoneyChange.
]]

if not ZLogs then return end

local function CurrentRound()
    if _G.CurrentRound then return _G.CurrentRound() end
    return nil
end

-- ============================================
-- WRAP-NET ОБЁРТКА С RETRY
-- ============================================

local function wrapNet(name, before, after, attempt)
    attempt = attempt or 1
    local key = name:lower()
    local orig = net.Receivers and net.Receivers[key]
    if not orig then
        if attempt < 10 then
            timer.Simple(2 * attempt, function()
                wrapNet(name, before, after, attempt + 1)
            end)
        else
            MsgN("[ZLogs] Не удалось обернуть net.Receive '" .. name .. "' — обработчик не зарегистрирован")
        end
        return
    end

    net.Receivers[key] = function(len, ply)
        local snap = before and before(ply) or nil
        local ok, err = pcall(orig, len, ply)
        if not ok then
            ErrorNoHalt("[ZLogs] orig handler error in '" .. name .. "': " .. tostring(err) .. "\n")
        end
        if after then
            local ok2, err2 = pcall(after, ply, snap)
            if not ok2 then
                ErrorNoHalt("[ZLogs] after-hook error in '" .. name .. "': " .. tostring(err2) .. "\n")
            end
        end
    end
end

-- Поднимаем все обёртки после загрузки гейммода
hook.Add("InitPostEntity", "zlogs_wrap_rp_nets", function()
    timer.Simple(1, function()

    -- ============================================
    -- ДЕНЬГИ: единый хук RoleplayMoneyChange (admin_give, salary, sale, purchase, isis_rob, add, take, default)
    -- ============================================
    --
    -- Reasons и как они эмитятся:
    --   admin_give — выдача админом через ulx
    --   salary     — пассивная зарплата по работе
    --   purchase   — TakeMoney при покупке (двери, оружие)
    --   sale       — AddMoney при продаже (двери, передача товара)
    --   isis_rob   — доля от ограбления казны
    --   add/take   — дефолт без явного reason (передача денег между игроками)
    --
    hook.Add("RoleplayMoneyChange", "zlogs_money", function(ply, amount, reason, targetPly)
        if not IsValid(ply) then return end
        if amount == 0 then return end

        local reason = reason or "?"
        local nick = ply:Nick()

        -- P2P-передача идёт через hook ZLogs_P2PTransfer (см. ниже).
        -- RoleplayMoneyChange с reason add/take не содержит targetPly — пропускаем.
        if reason == "add" or reason == "take" then return end

        local labelMap = {
            admin_give = "Админ выдал",
            salary     = "Зарплата",
            purchase   = "Покупка",
            sale       = "Продажа",
            isis_rob   = "Ограбление казны",
        }
        local label = labelMap[reason] or reason

        if reason == "salary" then
            ZLogs.Add("money", ply, nick .. " получил зарплату $" .. amount, {
                amount = amount, kind = "salary",
            })
        elseif reason == "admin_give" then
            local from = IsValid(targetPly) and targetPly:Nick() or "Консоль"
            ZLogs.Add("money", ply, from .. " выдал $" .. math.abs(amount) .. " игроку " .. nick, {
                target = targetPly,
                amount = math.abs(amount),
                kind   = "admin_give",
            })
        elseif reason == "purchase" then
            ZLogs.Add("money", ply, nick .. " потратил $" .. math.abs(amount), {
                amount = math.abs(amount), kind = "purchase",
            })
        elseif reason == "sale" then
            ZLogs.Add("money", ply, nick .. " получил $" .. amount .. " (продажа/возврат)", {
                amount = amount, kind = "sale",
            })
        elseif reason == "isis_rob" then
            ZLogs.Add("rob", ply, nick .. " получил $" .. amount .. " от ограбления казны", {
                amount = amount, kind = "isis_rob",
            })
        else
            ZLogs.Add("money", ply, nick .. " (" .. label .. ") $" .. amount, {
                amount = amount, kind = reason,
            })
        end
    end)

    -- ============================================
    -- P2P-ПЕРЕДАЧА ДЕНЕГ (через Q-меню, roleplay_give_money)
    -- Хук эмитится из sv_roleplay.lua перед TakeMoney/AddMoney
    -- ============================================
    hook.Add("ZLogs_P2PTransfer", "zlogs_p2p", function(sender, receiver, amount)
        if not IsValid(sender) or not IsValid(receiver) then return end
        local sum = math.abs(amount)
        ZLogs.Add("money", sender,
            sender:Nick() .. " передал $" .. sum .. " игроку " .. receiver:Nick(), {
            target = receiver,
            amount = sum,
            kind   = "transfer",
        })
    end)

    -- ============================================
    -- НАЛОГИ МЭРА
    -- ============================================
    wrapNet("roleplay_set_tax",
        function(ply)
            local r = CurrentRound()
            return r and r.CityTaxRate or nil
        end,
        function(ply, before)
            local r = CurrentRound()
            if not r then return end
            local after = r.CityTaxRate
            if before ~= after and IsValid(ply) then
                ZLogs.Add("city", ply, ply:Nick() .. " изменил налог: " ..
                    tostring(before) .. "% → " .. tostring(after) .. "%", {
                    old_tax = before, new_tax = after,
                })
            end
        end
    )

    -- ============================================
    -- ПРАВИЛА МЭРА
    -- ============================================
    wrapNet("roleplay_set_rules",
        function(ply)
            local r = CurrentRound()
            return r and r.CityRules or ""
        end,
        function(ply, before)
            local r = CurrentRound()
            if not r then return end
            local after = r.CityRules or ""
            if before ~= after and IsValid(ply) then
                local short = ZLogs.Truncate(after, 200)
                ZLogs.Add("city", ply, ply:Nick() .. " обновил правила города: " .. short, {
                    rules = after,
                })
            end
        end
    )

    -- ============================================
    -- ОГРАБЛЕНИЕ КАЗНЫ
    -- ============================================
    wrapNet("roleplay_rob_treasury",
        function(ply)
            return IsValid(ply) and ply.RobbingTreasury or false
        end,
        function(ply, before)
            if not IsValid(ply) then return end
            local after = ply.RobbingTreasury
            if not before and after then
                local r = CurrentRound()
                local treasury = r and r.CityTreasury or 0
                ZLogs.Add("rob", ply, ply:Nick() .. " начал ограбление казны (в казне $" .. treasury .. ")", {
                    treasury = treasury,
                    pos      = ply:GetPos(),
                })
            end
        end
    )

    -- ============================================
    -- ВОЙНА
    -- ============================================
    wrapNet("roleplay_declare_war",
        function(ply)
            local r = CurrentRound()
            return r and r.IsWarActive or false
        end,
        function(ply, before)
            local r = CurrentRound()
            if not r then return end
            local after = r.IsWarActive
            if before == after then return end
            if not IsValid(ply) then return end
            if after then
                ZLogs.Add("war", ply, ply:Nick() .. " ОБЪЯВИЛ ВОЙНУ (10 минут)", {
                    action = "declare",
                })
            else
                ZLogs.Add("war", ply, ply:Nick() .. " завершил войну досрочно", {
                    action = "end",
                })
            end
        end
    )

    -- ============================================
    -- КОМЕНДАНТСКИЙ ЧАС
    -- ============================================
    wrapNet("roleplay_declare_curfew",
        function(ply)
            local r = CurrentRound()
            return r and r.IsCurfewActive or false
        end,
        function(ply, before)
            local r = CurrentRound()
            if not r then return end
            local after = r.IsCurfewActive
            if before == after then return end
            if not IsValid(ply) then return end
            if after then
                ZLogs.Add("war", ply, ply:Nick() .. " объявил комендантский час", {
                    action = "curfew_on",
                })
            else
                ZLogs.Add("war", ply, ply:Nick() .. " отменил комендантский час", {
                    action = "curfew_off",
                })
            end
        end
    )

    -- ============================================
    -- СМЕНА РАБОТЫ
    -- ============================================
    wrapNet("roleplay_select_job",
        function(ply)
            return IsValid(ply) and ply.RoleplayJob or nil
        end,
        function(ply, before)
            if not IsValid(ply) then return end
            local after = ply.RoleplayJob
            if before == after then return end
            ZLogs.Add("job", ply, ply:Nick() .. " сменил работу: " ..
                tostring(before or "—") .. " → " .. tostring(after or "—"), {
                old_job = before,
                new_job = after,
            })
        end
    )

    -- ============================================
    -- ДВЕРИ — ПОКУПКА
    -- ============================================
    wrapNet("zb_door_buy",
        function(ply)
            return IsValid(ply) and (ply.RoleplayMoney or 0) or 0
        end,
        function(ply, before)
            if not IsValid(ply) then return end
            local after = ply.RoleplayMoney or 0
            local spent = before - after
            if spent > 0 then
                ZLogs.Add("door", ply, ply:Nick() .. " купил дверь за $" .. spent, {
                    amount = spent, action = "buy",
                })
            end
        end
    )

    -- ============================================
    -- ДВЕРИ — ПРОДАЖА
    -- ============================================
    wrapNet("zb_door_sell",
        function(ply)
            return IsValid(ply) and (ply.RoleplayMoney or 0) or 0
        end,
        function(ply, before)
            if not IsValid(ply) then return end
            local after = ply.RoleplayMoney or 0
            local gained = after - before
            if gained > 0 then
                ZLogs.Add("door", ply, ply:Nick() .. " продал дверь за $" .. gained, {
                    amount = gained, action = "sell",
                })
            end
        end
    )

    -- ============================================
    -- ПОКУПКА ПРИНТЕРА
    -- ============================================
    wrapNet("roleplay_buy_printer",
        function(ply)
            return IsValid(ply) and (ply.RoleplayMoney or 0) or 0
        end,
        function(ply, before)
            if not IsValid(ply) then return end
            local after = ply.RoleplayMoney or 0
            local spent = before - after
            if spent > 0 then
                ZLogs.Add("money", ply, ply:Nick() .. " купил принтер за $" .. spent, {
                    amount = spent, kind = "printer",
                })
            end
        end
    )

    -- ============================================
    -- GUN DEALER (F3 меню) — покупки
    -- ============================================
    wrapNet("roleplay_gundealer_buy",
        function(ply)
            return IsValid(ply) and (ply.RoleplayMoney or 0) or 0
        end,
        function(ply, before)
            if not IsValid(ply) then return end
            local after = ply.RoleplayMoney or 0
            local spent = before - after
            if spent > 0 then
                ZLogs.Add("weapon", ply, ply:Nick() .. " купил у оружейника за $" .. spent, {
                    amount = spent, kind = "gundealer",
                })
            end
        end
    )

    -- ============================================
    -- GUN SHOP entity — покупки
    -- ============================================
    wrapNet("zb_gun_shop_buy",
        function(ply)
            return IsValid(ply) and (ply.RoleplayMoney or 0) or 0
        end,
        function(ply, before)
            if not IsValid(ply) then return end
            local after = ply.RoleplayMoney or 0
            local spent = before - after
            if spent > 0 then
                ZLogs.Add("weapon", ply, ply:Nick() .. " купил в магазине оружия за $" .. spent, {
                    amount = spent, kind = "gun_shop",
                })
            end
        end
    )

    MsgN("[ZLogs] RP-хуки подключены")
    end) -- timer.Simple
end)

MsgN("[ZLogs] RP-хуки запланированы (InitPostEntity)")
