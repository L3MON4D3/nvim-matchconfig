local stack_util = require("matchconfig.util.callstack")
local table_util = require("matchconfig.util.table")
local as_config = require("matchconfig.config").as_config
local autotable = require("matchconfig.util.autotable").autotable
local session = require("matchconfig.session")

local yes = function(_) return true end
local key_valid = {
	dir = function(k)
		if k:match("%/$") then
			vim.notify(("dirname %s is terminated by a `/` and won't be recognized."), vim.log.levels.WARN)
			return false
		end
		return true
	end,
	pattern = yes,
	filetype = yes,
	file = yes,
}

local M = {}

local config_list_name = "__matchconfig_configlist"
function M.load_config(fname)
	local conf_fn = loadfile(fname)
	if not conf_fn then
		error("Could not load " .. fname)
	end

	-- conf_table[prio][type][id][]
	local conf_table = autotable(4)
	setfenv(conf_fn, setmetatable({
		[config_list_name] = conf_table,
	}, {__index = _G}))
	conf_fn()

	local generated_config = {
		dir = {},
		pattern = {},
		filetype = {},
		file = {}
	}
	for config in table_util.vals_sorted(conf_table) do
		for category, t in pairs(config) do
			for k, v in pairs(t) do
				-- process configs:
				-- make sure some functions are only run once in some buffer, or session.
				if key_valid[category](k) then
					generated_config[category][k] = v
				end
			end
		end
	end

	return generated_config
end

local function match_generic(typename)
	return function(id, ...)
		local config_specs = {...}

		local prio

		if type(config_specs[#config_specs]) == "number" then
			prio = config_specs[#config_specs]
			config_specs[#config_specs] = nil
		else
			prio = 1000
		end

		-- there is at least one config.
		local config = as_config(config_specs[1])
		for i = 2, #config_specs do
			config:_append(as_config(config_specs[i]))
		end

		local global_config_fn_level = stack_util.stack_fenv_get_marked_level(config_list_name)
		local config_list = getfenv(global_config_fn_level)[config_list_name]

		local debuginfo = debug.getinfo(global_config_fn_level, "Sl")
		-- :sub(2): skip leading "@"
		config:set_source(debuginfo.source:sub(2), debuginfo.currentline-1, typename, id)

		config_list[prio][typename][id] = config
	end
end

M.match_dir = match_generic("dir")
M.match_pattern = match_generic("pattern")
M.match_filetype = match_generic("filetype")
M.match_file = match_generic("file")

return M
