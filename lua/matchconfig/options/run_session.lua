local do_args_fn = require("matchconfig.util.actions").do_args_fn
local util = require("matchconfig.util.util")

--- @class Matchconfig.RunSession: Matchconfig.Option
--- @field session_fns fun(table)[]
local RunSession = {
	fn_undolist = {}
}
local RunSession_mt = { __index = RunSession }
function RunSession.new(config)
	return setmetatable({
		session_fns = {config.run_session},
	}, RunSession_mt)
end

function RunSession:copy()
	local cp = setmetatable({}, RunSession_mt)
	cp.session_fns = vim.list_slice(self.session_fns, 1, #self.session_fns)

	return cp
end

function RunSession:append_raw(t)
	table.insert(self.session_fns, t.run_session)
end
function RunSession:append(rb)
	vim.list_extend(self.session_fns, rb.session_fns, 1, #rb.session_fns)
end

local barrier = util.nop
function RunSession:barrier()
	table.insert(self.session_fns, barrier)
end

---@class Matchconfig.RunSessionApplicator: Matchconfig.OptionApplicator
---@field session_fns fun()[]
---@field undolist fun()[]
local RunSessionApplicator = {
	fn_undolist = {}
}
local RunSessionApplicator_mt = {__index = RunSessionApplicator}
function RunSessionApplicator.new(session_fns)
	return setmetatable({session_fns = session_fns, i = 1}, RunSessionApplicator_mt)
end
function RunSessionApplicator:apply_to_barrier(_, args)
	while true do
		local fn = self.session_fns[self.i]
		-- if fn is a barrier, advance past it (can resume behind it in the
		-- next call to apply_next)
		self.i = self.i+1
		if fn == barrier or fn == nil then
			return
		end
		if not RunSessionApplicator.fn_undolist[fn] then
			RunSessionApplicator.fn_undolist[fn] = do_args_fn(fn, args)
		end
	end
end

-- undo handled in reset.
function RunSessionApplicator:undo() end


function RunSession:make_applicator()
	return RunSessionApplicator.new(self.session_fns)
end

return {
	new = RunSession.new,
	reset = function()
		-- don't care for order, for now.
		for _, fn_undolist in pairs(RunSessionApplicator.fn_undolist) do
			fn_undolist:run()
		end
	end
}
