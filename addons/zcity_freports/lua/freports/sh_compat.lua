--[[---------------------------------------------------------------------------
ZCity RP — совместимость для дизайна FrePorts.
Дизайн (cl_init.lua) рассчитан на plib_v2, который добавлял table.Filter.
В чистом GMod такой функции нет — определяем её сами, если отсутствует.
Возвращает НОВЫЙ последовательный массив значений, для которых callback истинен.
---------------------------------------------------------------------------]]
if not table.Filter then
	function table.Filter(tbl, callback)
		local out = {}
		for k, v in pairs(tbl) do
			if callback(v, k) then
				out[#out + 1] = v
			end
		end
		return out
	end
end
