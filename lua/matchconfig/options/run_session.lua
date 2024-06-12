local do_args_fn = require("matchconfig.util.actions").do_args_fn

--- @class RunSession: Option
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

function RunSession:append_raw(t)
	table.insert(self.session_fns, t.run_session)
end
function RunSession:append(rb)
	local l = #self.session_fns
	for i, fn in ipairs(rb.session_fns) do
		self.session_fns[l+i] = fn
	end
end

local barrier = {}
function RunSession:barrier()
	table.insert(self.session_fns, barrier)
end

local RunSessionApplicator = {}
local RunSessionApplicator_mt = {__index = RunSessionApplicator}
function RunSessionApplicator.new(session_fns)
	return setmetatable({fns = session_fns, i = 1}, RunSessionApplicator_mt)
end
function RunSessionApplicator:apply_to_barrier(_, args)
	while true do
		local fn = self.fns[self.i]
		-- if fn is a barrier, advance past it (can resume behind it in the
		-- next call to apply_next)
		self.i = self.i+1
		if fn == barrier or fn == nil then
			return
		end
		if not RunSession.fn_undolist[fn] then
			RunSession.fn_undolist[fn] = do_args_fn(fn, args)
		end
	end
end


function RunSession:make_applicator()
	return RunSessionApplicator.new(self.session_fns)
end
function RunSession:undo()
	for _, fn in ipairs(self.session_fns) do
		local fn_undolist = RunSession.fn_undolist[fn]
		if fn_undolist then
			fn_undolist:run()
			RunSession.fn_undolist[fn] = nil
		end
	end
end
function RunSession.reset() RunSession.executed_fns = {} end

return RunSession
