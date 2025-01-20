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

-- keys are simple table, not like in vim.tbl_get.
function M.set(t, key_list, v)
	for i = 1, #key_list-1 do
		local next_t = t[key_list[i]]
		if type(next_t) ~= "table" then
			t[key_list[i]] = {}
			next_t = t[key_list[i]]
		end
		t = next_t
	end
	t[key_list[#key_list]] = v
end

function M.get(t, key_list)
	return vim.tbl_get(t, unpack(key_list))
end

local function do_recursive(t, keys, fn)
	-- will be overwritten immediately.
	table.insert(keys, "dummy_val")
	for k, v in pairs(t) do
		keys[#keys] = k
		local recurse = fn(t, keys, v)
		-- update in case fn changed the value.
		v = t[k]
		if recurse and type(v) == "table" then
			do_recursive(v, keys, fn)
		end
	end
	keys[#keys] = nil
end

-- fn returns whether to recurse into the subtree.
function M.tbl_do(t, fn)
	do_recursive(t, {}, fn)
end

return M
