--[[---------------------------------------------------------------------------
ZCity RP — полное отключение голосований за смену карты
---------------------------------------------------------------------------
Глушим ULX-команды смены карты голосованием для ВСЕХ (включая публичный
!votemap с доступом ACCESS_ALL и админский !votemap2):
  * ulx votemap   / !votemap   — публичное голосование игроков (все)
  * ulx votemap2  / !votemap2  — голосование, запускаемое админом

Других систем mapvote на сервере нет (отдельный mapvote/RTV-аддон не
установлен; ссылки в nova-defender — это античит, а не голосовалка).

Механика:
  ULX хранит объекты команд в ulx.cmdsByCategory. Вызов команды идёт через
  cmd:call() → cmd.fn(calling_ply, ...), причём ОДИН объект обслуживает и
  чат-вариант (!votemap), и консольный (ulx votemap). Поэтому подмена cmd.fn
  на отказ перекрывает оба пути сразу. Переопределять глобал ulx.votemap
  бесполезно — команда держит ссылку на функцию, захваченную при регистрации.

  Дополнительно форсим штатный выключатель ulx_votemapEnabled 0 — на случай,
  если этот файл уберут, публичный votemap всё равно останется выключенным
  до ручного включения.
---------------------------------------------------------------------------]]
if not SERVER then return end

local DISABLED_CMDS = {
    ["ulx votemap"]  = true, -- публичный (!votemap), ACCESS_ALL
    ["ulx votemap2"] = true, -- админский (!votemap2)
}

local DENY_MSG = "Голосование за карту отключено администрацией."

local function denyVote(calling_ply)
    if IsValid(calling_ply) and ULib and ULib.tsayError then
        ULib.tsayError(calling_ply, DENY_MSG, true)
    end
end

local function disableMapVotes()
    if not ulx or not ulx.cmdsByCategory then return end

    -- Штатный выключатель публичного votemap (defense-in-depth).
    if ConVarExists("ulx_votemapEnabled") then
        RunConsoleCommand("ulx_votemapEnabled", "0")
    end

    local patched = 0
    for _, cmds in pairs(ulx.cmdsByCategory) do
        for _, cmd in ipairs(cmds) do
            if cmd.cmd and DISABLED_CMDS[cmd.cmd] then
                cmd.fn = denyVote
                patched = patched + 1
            end
        end
    end

    print("[ZCITY] Голосования за карту отключены для всех (заглушено команд: " ..
          patched .. ")")
end

-- darkrpmodification грузится раньше ulx → ждём окончания загрузки ULX.
hook.Add("ULXLoaded", "ZCity_DisableMapVote", disableMapVotes)

-- Фолбэк на случай, если ULX уже загружен к моменту выполнения этого файла
-- (нестандартный порядок аддонов / горячая перезагрузка).
if ulx and ulx.cmdsByCategory then
    disableMapVotes()
end
