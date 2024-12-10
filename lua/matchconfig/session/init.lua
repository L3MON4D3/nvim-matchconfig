local autotable = require("auto_table").autotable
local data = require("matchconfig.session.data")
local util = require("util")
local make_buf_config = require("matchconfig.make_buf_config")

-- sets/controls values in session.data.
-- they are in a separate module so they're accessible from anywhere.

local M = {}

local default_opts = {
	options = {require("matchconfig.options.run_buf")},
	path = "config.lua"
}

---@class Matchconfig.SetupOpts
---@field configfile string
---@field options table<string, Matchconfig.Option>

---Update configuration and reload.
---@param opts Matchconfig.SetupOpts
local function set_config_data(opts)
	opts = opts or {}
	opts = vim.tbl_extend("keep", opts, default_opts)

	local stdpath_config = vim.fn.stdpath("config") --[[ @as string ]]
	data.configfile = vim.fs.joinpath(stdpath_config, opts.path)
	data.options = opts.options

	data.configfile_watcher_id = vim.api.nvim_create_autocmd({"BufWritePost"}, {
		callback = function()
			-- notify config_picker that the file changed and the parser needs
			-- to be reloaded.
			require("matchconfig.config_picker").reset(data.configfile)
			-- don't fail silently.
			M.reload_same_opts(false)
		end,
		pattern = data.configfile
	})
end
-- undo things done in set_config.
local function reset_config()
	vim.api.nvim_del_autocmd(data.configfile_watcher_id)
end

local function set_derived_data(fail_silently)
	data.buf_configs = autotable(2)
	data.buf_applicators = autotable(2)
	-- fail silently.
	data.matchconfigs = require("matchconfig.gen_config").load_config(data.configfile, fail_silently)
end

-- args: must contain only args.buf, the bufnr, and args.file, the filename.
function M.load_buf_config(load_args)
	local bufnr = load_args.buf
	local bufname = load_args.file

	if data.buf_configs[bufnr][bufname] then
		-- already executed for this buffer, do nothing.
		return
	end

	local f_conf = make_buf_config(bufnr, data.matchconfigs)
	local conf_applicator = f_conf:make_applicator()
	data.buf_configs[bufnr][bufname] = f_conf
	data.buf_applicators[bufnr][bufname] = conf_applicator

	conf_applicator:apply(load_args)
end

-- call before everything else.
function M.initialize(fail_silently)
	set_config_data(default_opts)
	set_derived_data(fail_silently)
end

-- undo config of all buffers we had loaded config for.
local function unload()
	for bufnr, bufnr_configs in pairs(data.buf_applicators) do
		for _, config_applicator in pairs(bufnr_configs) do
			if vim.api.nvim_buf_is_loaded(bufnr) then
				-- only undo for valid buffers.
				config_applicator:undo(bufnr)
			end
		end
	end
	for _, opt in ipairs(data.options) do
		opt:reset()
	end
end

-- apply config to every open buffer.
local function load_open_bufs()
	for _, bufnr in pairs(util.get_loaded_bufs()) do
		M.load_buf_config({ buf = bufnr, file = vim.api.nvim_buf_get_name(bufnr) })
	end
end

-- don't change options, only reload.
function M.reload_same_opts(fail_silently)
	unload()
	set_derived_data(fail_silently)
	load_open_bufs()
end

-- reload with new options.
function M.reload_new_opts(opts, fail_silently)
	unload()
	reset_config()
	set_config_data(opts)
	set_derived_data(fail_silently)
	load_open_bufs()
end

function M.get_config(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(bufnr)

	local conf = data.buf_configs[bufnr][bufname]
	if conf then
		return conf
	end
	error(("No config loaded for bufnr %s (file %s)"):format(bufnr, bufname))
end


return M
