local M = {}

-- for read-only empty tables, so we don't allocate a bunch of them.
M.empty = {}
M.nop = function() end
M.no = function() return false end
function M.make_human_readable(matcher_id, instance_id, include_matcher_id)
	if include_matcher_id then
		return matcher_id .. "(" ..instance_id .. ")"
	else
		return instance_id
	end
end


return M
