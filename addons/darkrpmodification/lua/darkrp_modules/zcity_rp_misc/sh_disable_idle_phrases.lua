--[[---------------------------------------------------------------------------
ZCity RP — отключение "болтовни безделья" homigrad
---------------------------------------------------------------------------
homigrad/sh_status_messages.lua крутит фразы вида:
  "What if this quiet lasts forever?"
  "Everything seems too quiet..."
  "Breathing feels oddly satisfying right now."
  "Why isn't anything happening?"
когда игрок в спокойствии (organism.fear < -0.6).

Эти фразы под roleplay-контекстом неуместны. Переопределяем
hg.nothing_happening так чтобы оно всегда возвращало false — фразы боли,
страха, голода, холода и т.д. остаются работать как раньше.
---------------------------------------------------------------------------]]

-- Хук на HomigradRun — homigrad/loader.lua запускает его после полной загрузки.
-- К этому моменту hg.nothing_happening уже определён, можем перезаписать.
hook.Add("HomigradRun", "ZCity_RP_DisableIdlePhrases", function()
    if not hg then return end
    hg.nothing_happening = function(ply) return false end
end)

-- На случай если HomigradRun уже отработал до нас (autorun грузится поздно).
if hg and hg.loaded then
    hg.nothing_happening = function(ply) return false end
end

print("[ZCity RP] Idle phrases disabled (\"What if this quiet lasts forever?\" и т.п.)")
