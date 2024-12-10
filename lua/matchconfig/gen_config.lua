local stack_util = require("matchconfig.util.callstack")
local as_config = require("matchconfig.primitives.config").as_config
local builtin_matchers = require("matchconfig.builtin_matchers")
local matchconfig = require("matchconfig.primitives.matchconfig")

local M = {}

local config_list_name = "__matchconfig_configlist"
function M.load_config(fname, fail_silently)
	local conf_fn, err = loadfile(fname)
	if not conf_fn then
		if not fail_silently then
			print("Could not load configs from " .. fname .. ": " .. err)
		end
		return {}
	end

	local conf_table = {}
	setfenv(conf_fn, setmetatable({
		[config_list_name] = conf_table,
	}, {__index = _G}))
	local ok, run_err = pcall(conf_fn)
	if ok ~= true then
		if not fail_silently then
			print("Error while running config " .. fname .. ": " .. run_err)
		end
		return {}
	end

	return conf_table
end

function M.register(matcher, config, opts)
	config = config:copy()
	local additional_tags = opts and opts.tags

	local mc = matchconfig.new(config, matcher, additional_tags)

	local global_config_fn_level = stack_util.stack_fenv_get_marked_level(config_list_name)
	local config_list = getfenv(global_config_fn_level)[config_list_name]

	local debuginfo = debug.getinfo(global_config_fn_level, "Sl")
	-- :sub(2): skip leading "@"
	config:set_source(debuginfo.source:sub(2), debuginfo.currentline-1, matcher.matcher_id, matcher:human_readable(false))

	table.insert(config_list, mc)

	return mc
end

return M
