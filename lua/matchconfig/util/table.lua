local M = {}

function M.vals_sorted(t)
	local keys = {}
	for k, _ in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys)

	local i = 1

	return function()
		if not keys[i] then
			return nil
		end
		local res = t[keys[i]]
		i = i + 1
		return res
	end
end

---Convert value or list of values to a table of booleans for fast lookup.
---@generic T
---@param values T|T[]|table<T, boolean>
---@return table<T, boolean>
function M.list_to_set(values)
	if values == nil then
		return {}
	end

	if type(values) ~= "table" then
		return { [values] = true }
	end

	local list = {}
	for _, v in ipairs(values) do
		list[v] = true
	end

	return list
end

function M.shallow_copy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end

function M.id_map(t)
	local t2 = {}
	for _,v in pairs(t) do
		t2[v] = v
	end
	return t2
end

return M
