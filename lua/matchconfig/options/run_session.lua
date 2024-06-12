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

function RunSession:apply(args)
	for _, fn in ipairs(self.session_fns) do
		-- make sure we only execute session-fn if it wasn't run already.
		if not RunSession.fn_undolist[fn] then
			RunSession.fn_undolist[fn] = do_args_fn(fn, args)
		end
	end
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
