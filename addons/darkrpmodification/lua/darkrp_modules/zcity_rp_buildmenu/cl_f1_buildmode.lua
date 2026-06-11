--[[---------------------------------------------------------------------------
ZCity RP — F1 = открыть Q-меню (spawnmenu)
---------------------------------------------------------------------------
В стандартном GMod спавн-меню (тулы, пропы и т.д.) открывается на Q (бинд
+menu_context). Здесь привязываем F1 к тому же действию.

Q-меню остаётся zcity-кастомным (cl_spawnmenu.lua). F1 — просто альтернативная
клавиша.
---------------------------------------------------------------------------]]
if SERVER then return end

-- Перехватываем F1 и открываем спавн-меню
hook.Add("PlayerBindPress", "ZCity_RP_F1OpenSpawnmenu", function(ply, bind, pressed)
    if not pressed then return end
    if bind ~= "gm_showhelp" then return end -- gm_showhelp = F1 в DarkRP

    -- Открываем стандартное Q-меню (zcity его модифицирует через хуки)
    -- spawnmenu есть только если SpawnMenuOpen хук разрешает
    if hook.Run("SpawnMenuOpen") == false then return true end

    -- Имитируем нажатие Q: вызвать спавн-меню
    if g_SpawnMenu then
        if g_SpawnMenu:IsVisible() then
            g_SpawnMenu:Close()
        else
            g_SpawnMenu:Open()
        end
    end

    return true -- блокируем дефолтный F1 help
end)

print("[ZCity RP] F1 -> Q-меню (spawnmenu)")
