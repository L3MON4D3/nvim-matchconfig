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

return M
