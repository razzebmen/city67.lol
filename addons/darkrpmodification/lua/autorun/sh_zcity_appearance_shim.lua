--[[---------------------------------------------------------------------------
ZCity RP — shim для GetRandomAppearance
---------------------------------------------------------------------------
В homigrad/playerclass/classes/sh_refuge.lua:273 есть баг — вызывается
глобальная функция GetRandomAppearance() которой не существует. Правильно
было бы hg.Appearance.GetRandomAppearance(). Чтобы не править core homigrad
файлы, регистрируем глобальный псевдоним.
---------------------------------------------------------------------------]]

function GetRandomAppearance(ply)
    if hg and hg.Appearance and hg.Appearance.GetRandomAppearance then
        return hg.Appearance.GetRandomAppearance()
    end
    return {} -- fallback пустая appearance
end
