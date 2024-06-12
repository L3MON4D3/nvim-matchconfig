local autotable = require("auto_table").autotable
local make_config = require("matchconfig.make_buf_config")
local util = require("util")
local gen_config = require("matchconfig.gen_config")
local config_picker = require("matchconfig.config_picker")
local session = require("matchconfig.session")

local M = {}

-- (re)generate global config.
local function gen_global_config()
	session.global_config = gen_config.load_config(session.global_config_fname)
end

-- args: must contain args.buf, the bufnr, and args.file, the filename.
local function load_config(args)
	if session.buf_configs[args.buf][args.file] then
		-- already executed for this buffer, do nothing.
		return
	end

	local bufnr = args.buf
	local bufname = args.file
	local f_conf = session.buf_configs[bufnr][bufname]
	if not f_conf then
		f_conf = make_config(bufnr, session.global_config)
		session.buf_configs[bufnr][bufname] = f_conf
	end

	f_conf:apply(args)
end

function M.setup(opts)
	session.global_config_fname = opts.fname

	session.options = opts.options or require("matchconfig.options")
	session.buf_configs = autotable(2)

	gen_global_config()

	vim.api.nvim_create_autocmd({"BufEnter"}, {
		-- to run under all circumstances I guess?
		callback = load_config
	})
	vim.api.nvim_create_user_command("C", function()
		require("matchconfig.config_picker").pick_current()
	end, {})
	vim.api.nvim_create_autocmd({"BufWritePost"}, {
		-- to run under all circumstances I guess?
		callback = M.reset,
		pattern = opts.fname
	})
end

function M.get_config(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(bufnr)

	local conf = session.buf_configs[bufnr][bufname]
	if conf then
		return conf
	end
	error(("No config loaded for bufnr %s (file %s)"):format(bufnr, bufname))
end


local function load_open_bufs()
	for _, bufnr in pairs(util.get_loaded_bufs()) do
		load_config({ buf = bufnr, file = vim.api.nvim_buf_get_name(bufnr) })
	end
end

function M.reset()
	for bufnr, nr_configs in pairs(session.buf_configs) do
		for _, config in pairs(nr_configs) do
			if vim.api.nvim_buf_is_loaded(bufnr) then
				-- only undo for valid buffers.
				config:undo(bufnr)
			end
		end
	end

	config_picker.reset(session.global_config_fname)

	-- re-generate global configuration.
	gen_global_config()
	-- clear loaded configs.
	session.buf_configs = autotable(2)
	load_open_bufs()
end

M.config = require("matchconfig.config").new
M.actions = require("matchconfig.util.actions")
M.match_dir = gen_config.match_dir
M.match_pattern = gen_config.match_pattern
M.match_filetype = gen_config.match_filetype
M.match_file = gen_config.match_file

return M
