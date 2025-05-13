local gen_config = require("matchconfig.gen_config")
local data = require("matchconfig.session.data")
local session = require("matchconfig.session")

---@class Matchconfig.init
local M = {}

---@source session/init.lua
function M.setup(opts)
	session.reload_new_opts(opts)
end

M.pick_current = require("matchconfig.config_picker").pick_current

function M.get_configfile()
	return data.configfile
end

function M.get_config(bufnr)
	return session.get_config(bufnr)
end

M.config = require("matchconfig.primitives.config").new
M.actions = require("matchconfig.util.actions")
M.eval = require("matchconfig.options.util.eval").new

M.match_dir = gen_config.match_dir
M.match_pattern = gen_config.match_pattern
M.match_filetype = gen_config.match_filetype
M.match_file = gen_config.match_file
M.register = gen_config.register

M.matchers = vim.tbl_map(function(i)
	return i.new
end, require("matchconfig.builtin_matchers"))
M.log = require("matchconfig.util.log")

return M
