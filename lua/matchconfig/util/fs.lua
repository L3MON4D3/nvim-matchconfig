local M = {}

function M.normalize_dir(dir)
	if dir:match("%/$") then
		dir = dir:sub(1,-2)
	end
	return dir
end

return M
