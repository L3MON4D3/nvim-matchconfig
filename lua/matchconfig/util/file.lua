local M = {}

function M.lines(fname)
	local f = io.open(fname)
	if not f then
		return nil
	end

	local content = f:read("*all")
	f:close()
	return content
end

return M
