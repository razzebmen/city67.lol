--[[
    ZCity Logs — логирование ноклипа.

    Хук PlayerNoClip срабатывает, когда игрок переключает ноклип кнопкой
    (бинд noclip / V). Прямой SetMoveType(MOVETYPE_NOCLIP) его НЕ триггерит,
    поэтому спектатор при смерти (sv_spectator.lua) сюда не попадает — спама нет.

    Команда "ulx noclip" логируется отдельно через ULibCommandCalled
    (sv_zlogs_hooks.lua), здесь — только ручное переключение кнопкой.
]]

if not ZLogs then return end

hook.Add("PlayerNoClip", "zlogs_noclip", function(ply, desiredState)
    if not IsValid(ply) then return end

    -- Анти-дребезг: движок иногда дёргает хук дважды за один кадр
    if ply._zlogsNoclipLast == desiredState and
       ply._zlogsNoclipTime and (CurTime() - ply._zlogsNoclipTime) < 0.2 then
        return
    end
    ply._zlogsNoclipLast = desiredState
    ply._zlogsNoclipTime = CurTime()

    local action = desiredState and "включил ноклип" or "выключил ноклип"

    ZLogs.Add("admin", ply, ply:Nick() .. " " .. action, {
        state = desiredState and "on" or "off",
        pos   = ply:GetPos(),
        group = ply:GetUserGroup(),
    })
end)

MsgN("[ZLogs] Хук ноклипа загружен")
