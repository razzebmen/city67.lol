--[[---------------------------------------------------------------------------
ZCity RP — применение Appearance из ESC-меню при спавне
---------------------------------------------------------------------------
В homigrad/new_appearance/sv_init.lua:192 хук на PlayerSpawn вешается только
если engine.ActiveGamemode() == "sandbox". У нас геймод "zcity" (derived от
darkrp), поэтому хук не вешается и одежда из ESC-меню не применяется.

Здесь дублируем этот хук, чтобы при спавне игрока его CachedAppearance
накладывался автоматически.

Также: SetPlayerClass из homigrad классов уже вызывает ApplyAppearance,
поэтому для джобов с playerClass = "Refugee" это будет дублироваться,
но WearAppearance идемпотентна — повторный вызов не ломает.
---------------------------------------------------------------------------]]
if not SERVER then return end

hook.Add("PlayerSpawn", "ZCity_RP_ApplyAppearance", function(ply)
    if not IsValid(ply) then return end
    if OverrideSpawn then return end
    if not ApplyAppearance then return end -- homigrad ещё не загружен

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        ApplyAppearance(ply, nil, nil, nil, true) -- bUseCahsed = берём из CachedAppearance
    end)
end)

-- НЕ применяем appearance при смене джоба — иначе модель/одежда сменятся
-- сразу до респавна. Игрок должен видеть старую модель пока не умрёт и не
-- заспавнится. PlayerSpawn хук выше всё применит при респавне.

print("[ZCity RP] Appearance auto-apply on spawn (replaces sandbox-only hook)")
