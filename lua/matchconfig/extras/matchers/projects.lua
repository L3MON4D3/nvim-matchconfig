local project_id_fns = {
	cmake = function(bufinfo)
		-- return directory of uppermost CMakeLists.txt, that's most likely the correct one.
		-- 16 should be a reasonable upper limit.
		local res = vim.fs.find("CMakeLists.txt", {upward=true, type="file", limit=16, path = bufinfo.dir})
		return #res > 0 and vim.fs.dirname(res[#res])
	end,
	pkgbuild = function(bufinfo)
		-- there shouldn't be nested PKGBUILDS.
		local res = vim.fs.find("PKGBUILD", {upward=true, type="file", limit=1, path = bufinfo.dir})
		return #res > 0 and vim.fs.dirname(res[1])
	end,
	make = function(bufinfo)
		-- return directory of uppermost Makefile, that's most likely the correct one.
		-- 16 should be a reasonable upper limit.
		local res = vim.fs.find("Makefile", {upward=true, type="file", limit=16, path = bufinfo.dir})
		return #res > 0 and vim.fs.dirname(res[#res])
	end,
}

local M = {}

for k, id_fn in pairs(project_id_fns) do
	M[k] = function()
		return require("matchconfig.builtin_matchers").generic.new(id_fn, k, "project")
	end
end

return M
