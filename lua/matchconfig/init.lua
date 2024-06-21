local gen_config = require("matchconfig.gen_config")
local session = require("matchconfig.session")

local M = {}

function M.setup(opts)
	session.reload_new_opts(opts)
end

M.pick_current = require("matchconfig.config_picker").pick_current

function M.get_config(bufnr)
	return session.get_config(bufnr)
end

M.config = require("matchconfig.primitives.config").new
M.actions = require("matchconfig.util.actions")

M.match_dir = gen_config.match_dir
M.match_pattern = gen_config.match_pattern
M.match_filetype = gen_config.match_filetype
M.match_file = gen_config.match_file
M.match = gen_config.match

M.matchers = vim.tbl_map(function(i)
	return i.new
end, require("matchconfig.builtin_matchers"))

return M
