local do_args_fn = require("matchconfig.util.actions").do_args_fn
local tbl_util = require("matchconfig.util.table")
local util = require("matchconfig.util.util")

--- @class Matchconfig.RunBufOpts
--- @field raw_key string The key that stores the function in the raw tables passed to `c`.
--- @field respect_barrier boolean If set, the functions are executed
---                                completely before some barrier, if not, they
---                                are all executed before the first barrier.

--- @class Matchconfig.RunBuf: Matchconfig.Option
--- @field buf_fns fun(table)[]
--- @field opts Matchconfig.RunBufOpts, read-only.
local RunBuf = {}
local RunBuf_mt = { __index = RunBuf }

local default_opts = {
	raw_key = "run_buf",
	respect_barrier = true
}

function RunBuf.new(config, opts)
	opts = opts or default_opts
	return setmetatable({
		buf_fns = {config[opts.raw_key]},
		opts = opts
	}, RunBuf_mt)
end

function RunBuf:copy()
	local cp = setmetatable({}, RunBuf_mt)
	cp.buf_fns = vim.list_slice(self.buf_fns, 1, #self.buf_fns)
	-- read-only.
	cp.opts = self.opts

	return cp
end

function RunBuf:append_raw(t)
	table.insert(self.buf_fns, t[self.opts.raw_key])
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
function RunBufApplicator.new(session_fns, barrier_args, opts)
	return setmetatable({
		fns = session_fns,
		undolists = {},
		i = 1,
		barrier_args = barrier_args,
		opts = opts
	}, RunBufApplicator_mt)
end
function RunBufApplicator:apply_to_barrier(i, args)
	args = tbl_util.shallow_copy(args)

	if self.opts.respect_barrier then
		while true do
			local fn = self.fns[self.i]
			-- if fn is a barrier, advance past it (can resume behind it in the
			-- next call to apply_next)
			self.i = self.i+1
			if fn == barrier or fn == nil then
				-- stop if opts.respect_barrier is set and 
				return
			end
			args.match_args = self.barrier_args[i]
			table.insert(self.undolists, do_args_fn(fn, args))
		end
	else
		-- apply completely before the first barrier.
		if i ~= 1 then
			return
		end

		local barrier_idx = 1
		for _, fn in ipairs(self.fns) do
			if fn == barrier then
				barrier_idx = barrier_idx + 1
			else
				args.match_args = self.barrier_args[barrier_idx]
				table.insert(self.undolists, do_args_fn(fn, args))
			end
		end
	end

end
function RunBufApplicator:undo(_)
	for _, undolist in ipairs(self.undolists) do
		undolist:run()
	end
end

function RunBuf:make_applicator(barrier_args)
	return RunBufApplicator.new(self.buf_fns, barrier_args, self.opts)
end

return {
	new = RunBuf.new,
	reset = util.nop
}
