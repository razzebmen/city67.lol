--[[---------------------------------------------------------------------------
city67: фикс порядка категорий в IGS
---------------------------------------------------------------------------
IGS строит вкладку "Последние покупки" → создаёт панель тегов категорий через
    for categ in pairs(cats) do bg.tags:AddTag(categ, ...) end
`pairs()` в Lua не гарантирует порядок — поэтому категории прыгают каждый
запуск (то "Хиты продаж" сверху, то "Валюта", то "Донат-персонал").

Этот хук подвязывается на тот же IGS.CatchActivities с приоритетом HOOK_LOW —
он отрабатывает ПОСЛЕ родного "main" и пересортирует уже добавленные теги
в DIconLayout-панели (bg.tags) в нашем порядке.

Порядок задаётся таблицей CATEGORY_ORDER. Категории, не упомянутые здесь,
идут в конце в том порядке, в каком были добавлены IGS.
---------------------------------------------------------------------------]]
if not CLIENT then return end

local CATEGORY_ORDER = {
    "[★] Хиты продаж", -- наша приоритетная категория — всегда сверху
    "Статусы",
    "Донат-персонал",
    "Валюта",
}

-- Вспомогательное: индекс категории в нашем порядке (или большое число если не задана)
local function rankOf(name)
    for i, n in ipairs(CATEGORY_ORDER) do
        if n == name then return i end
    end
    return 9999
end

-- IGS добавляет первый "тег" — это ВКЛАДКА "Сброс фильтров" (текст оригинала).
-- В исходном коде это переменная `categ` объекта tag. Найдём её и не трогаем.
-- Сами теги категорий имеют свойство `.categ = categ` (см. main.lua):
--     bg.tags:AddTag(categ,function() ... end).categ = categ

-- Хук срабатывает позже основного "main" (HOOK_LOW = post)
hook.Add("IGS.CatchActivities", "city67_category_order", function(activity, sidebar)
    timer.Simple(0, function()
        if not IsValid(activity) then return end
        -- Найдём DIconLayout с тегами: ходим по детям sidebar/activity
        -- Упрощаем — bg.tags имеет .AddTag function (создан в main.lua).
        -- Иду по всем VGUI-детям внутри активности.
        local function findTagsLayout(panel)
            if not IsValid(panel) then return nil end
            for _, child in ipairs(panel:GetChildren()) do
                -- DIconLayout с табами категорий. Признак: имеет .AddTag-инжект и хотя бы один child с .categ
                if child.GetChildren then
                    local kids = child:GetChildren()
                    if kids and #kids > 0 then
                        for _, k in ipairs(kids) do
                            if k.categ ~= nil then return child end
                        end
                    end
                end
                local found = findTagsLayout(child)
                if found then return found end
            end
            return nil
        end

        local tagsLayout = findTagsLayout(activity)
        if not IsValid(tagsLayout) then return end

        -- Сортируем детей по нашему порядку. tag без .categ ("Сброс фильтров")
        -- ставим первым (rank=0).
        local kids = tagsLayout:GetChildren()
        table.sort(kids, function(a, b)
            local ra = a.categ and rankOf(a.categ) or 0
            local rb = b.categ and rankOf(b.categ) or 0
            if ra ~= rb then return ra < rb end
            return tostring(a.categ or "") < tostring(b.categ or "")
        end)

        -- DIconLayout раскладывает детей в порядке их добавления (порядок
        -- в:GetChildren()). Чтобы пересортировать — снимаем родителя и
        -- ставим обратно в нужном порядке (это перенесёт их в конец списка
        -- детей в нужной последовательности).
        for _, k in ipairs(kids) do
            if IsValid(k) then k:SetParent(nil) end
        end
        for _, k in ipairs(kids) do
            if IsValid(k) then k:SetParent(tagsLayout) end
        end
        tagsLayout:InvalidateLayout(true)
        if tagsLayout.Layout then tagsLayout:Layout() end
    end)
end, HOOK_LOW)
