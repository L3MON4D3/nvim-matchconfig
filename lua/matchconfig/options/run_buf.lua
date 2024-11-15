local do_args_fn = require("matchconfig.util.actions").do_args_fn
local util = require("matchconfig.util.util")

--- @class Matchconfig.RunBuf: Matchconfig.Option
--- @field buf_fns fun(table)[]
--- @field undolists Matchconfig.Undolist[]
local RunBuf = {}
local RunBuf_mt = { __index = RunBuf }

function RunBuf.new(config)
	return setmetatable({
		buf_fns = {config.run_buf},
		undolists = {}
	}, RunBuf_mt)
end

function RunBuf:copy()
	local cp = setmetatable({}, RunBuf_mt)
	cp.buf_fns = vim.list_slice(self.buf_fns, 1, #self.buf_fns)
	local undolists_cp = {}
	for i, undolist in ipairs(self.undolists) do
		undolists_cp[i] = undolist:copy()
	end
	cp.undolists = undolists_cp

	return cp
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

local barrier = util.nop
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
function RunBufApplicator:undo()
	for _, undolist in ipairs(self.undolists) do
		undolist:run()
	end
end

function RunBuf:make_applicator()
	return RunBufApplicator.new(self.buf_fns, self.undolists)
end

return {
	new = RunBuf.new,
	reset = util.nop
}
