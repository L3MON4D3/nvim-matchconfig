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
	conf_fn()

	return conf_table
end

function M.match(matcher, configs, opts)
	local additional_tags
	local after
	local before
	if opts then
		additional_tags = opts.tags
		after = opts.after
		before = opts.before
	end

	-- there is at least one config.
	local config = as_config(configs[1])
	for i = 2, #configs do
		-- don't use barriers here, these are all one logical unit.
		config:_append(as_config(configs[i]))
	end

	local mc = matchconfig.new(config, matcher, additional_tags, after, before)

	local global_config_fn_level = stack_util.stack_fenv_get_marked_level(config_list_name)
	local config_list = getfenv(global_config_fn_level)[config_list_name]

	local debuginfo = debug.getinfo(global_config_fn_level, "Sl")
	-- :sub(2): skip leading "@"
	config:set_source(debuginfo.source:sub(2), debuginfo.currentline-1, matcher.matcher_id, matcher:human_readable(false))

	table.insert(config_list, mc)

	return mc
end

local function match_generic(matcher_type)
	return function(matcher_arg, ...)
		return M.match(matcher_type.new(matcher_arg), {...})
	end
end

M.match_dir = match_generic(builtin_matchers.dir)
M.match_pattern = match_generic(builtin_matchers.pattern)
M.match_filetype = match_generic(builtin_matchers.filetype)
M.match_file = match_generic(builtin_matchers.file)

return M
