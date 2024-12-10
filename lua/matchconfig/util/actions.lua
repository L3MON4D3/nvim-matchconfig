local stack_util = require("matchconfig.util.callstack")

--- @class Matchconfig.Undolist
local Undolist = {}
local Undolist_mt = { __index = Undolist }

function Undolist.new()
	return setmetatable({}, Undolist_mt)
end

function Undolist:copy()
	return setmetatable(vim.list_slice(self, 1, #self), Undolist_mt)
end
function Undolist:run()
	for i = #self, 1, -1 do
		self[i]()
	end
end
function Undolist:append(fn)
	table.insert(self, fn)
end

local undo_callbacks_name = "__action_undo"
local bufnr_name = "__action_bufnr"
-- args like the argument passed to autocmd-callback.
local function do_args_fn(fn, args, ...)
	local undolist = Undolist.new()
	setfenv(fn, setmetatable({
		[undo_callbacks_name] = undolist,
		[bufnr_name] = args.buf,
	}, {__index = _G}))
	fn(args, ...)
	return undolist
end

return {
	do_args_fn = do_args_fn,
	nnoremapsilent_buf = function(lhs, rhs)
		local undo, buf = stack_util.stack_fenv_find_vars(undo_callbacks_name, bufnr_name)

		local callback = nil
		if type(rhs) == "function" then
			callback = rhs
			rhs = ""
		end
		vim.api.nvim_buf_set_keymap(buf, "n", lhs, rhs, {noremap = true, silent = true, callback = callback})

		undo:append(function()
			-- pcall in the case that the mapping is already removed somehow.
			-- (maybe two run_buf map the same lhs, then there would be an
			-- error on undoing both of them)
			pcall(vim.api.nvim_buf_del_keymap, buf, "n", lhs)
		end)
	end,
	-- the same, up to the obvious change.
	vnoremapsilent_buf = function(lhs, rhs)
		local undo, buf = stack_util.stack_fenv_find_vars(undo_callbacks_name, bufnr_name)

		local callback = nil
		if type(rhs) == "function" then
			callback = rhs
			rhs = ""
		end
		vim.api.nvim_buf_set_keymap(buf, "v", lhs, rhs, {noremap = true, silent = true, callback = callback})

		undo:append(function()
			pcall(vim.api.nvim_buf_del_keymap, buf, "v", lhs)
		end)
	end,
	cabbrev_buf = function(lhs, rhs)
		local undo, buf = stack_util.stack_fenv_find_vars(undo_callbacks_name, bufnr_name)

		vim.api.nvim_buf_set_keymap(buf, "ca", lhs, rhs, {})

		undo:append(function()
			pcall(vim.api.nvim_buf_del_keymap, buf, "ca", lhs)
		end)
	end,
	usercommand_buf = function(id, fn, opts)
		opts = opts or {}

		local undo, buf = stack_util.stack_fenv_find_vars(undo_callbacks_name, bufnr_name)

		vim.api.nvim_buf_create_user_command(buf, id, fn, opts)
		undo:append(function()
			pcall(vim.api.nvim_buf_del_user_command, buf, id)
		end)
	end,
	autocmd_buf = function(event, callback)
		local undo, buf = stack_util.stack_fenv_find_vars(undo_callbacks_name, bufnr_name)

		local autocmd_id = vim.api.nvim_create_autocmd(event, {
			callback = callback,
			buffer = buf
		})
		undo:append(function()
			pcall(vim.api.nvim_del_autocmd, autocmd_id)
		end)
	end,
	undo_append = function(fn)
		local undo, _ = stack_util.stack_fenv_find_vars(undo_callbacks_name, bufnr_name)
		undo:append(fn)
	end
}
