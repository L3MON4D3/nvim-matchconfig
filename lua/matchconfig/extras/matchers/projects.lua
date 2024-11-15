local framework_id_fns = {
	cmake = function(bufinfo)
		return #vim.fs.find("CMakeLists.txt", {upward=true, type="file", limit=1, path = bufinfo.dir})
	end,
}



local M = {}

for framework, id_fn in pairs(framework_id_fns) do
	M[framework] = function()
		return require("matchconfig.builtin_matchers").generic.new(id_fn, framework, "framework")
	end
end

return M
