local do_args_fn = require("matchconfig.util.actions").do_args_fn

--- @class RunBuf: Option
--- @field buf_fns fun(table)[]
--- @field undolists Undolist[]
local RunBuf = {}
local RunBuf_mt = { __index = RunBuf }
function RunBuf.new(configs)
	return setmetatable({
		buf_fns = {configs.run_buf},
		undolists = {}
	}, RunBuf_mt)
end

function RunBuf:append_raw(t)
	table.insert(self.buf_fns, t.run_buf)
end
function RunBuf:append(rb)
	local l = #self.buf_fns
	for i, fn in ipairs(rb.buf_fns) do
		self.buf_fns[l+i] = fn
	end
end

local barrier = {}
function RunBuf:barrier()
	table.insert(self.buf_fns, barrier)
end

local RunBufApplicator = {}
local RunBufApplicator_mt = {__index = RunBufApplicator}
function RunBufApplicator.new(session_fns, undolists)
	return setmetatable({
		fns = session_fns,
		undolists = undolists,
		i = 1
	}, RunBufApplicator_mt)
end
function RunBufApplicator:apply_to_barrier(_, args)
	while true do
		local fn = self.fns[self.i]
		-- if fn is a barrier, advance past it (can resume behind it in the
		-- next call to apply_next)
		self.i = self.i+1
		if fn == barrier or fn == nil then
			return
		end
		table.insert(self.undolists, do_args_fn(fn, args))
	end
end

function RunBuf:make_applicator()
	return RunBufApplicator.new(self.buf_fns, self.undolists)
end


function RunBuf:undo()
	for _, undolist in ipairs(self.undolists) do
		undolist:run()
	end
end
function RunBuf:reset() end

return RunBuf
