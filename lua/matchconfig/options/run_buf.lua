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

function RunBuf:apply(args)
	for _, fn in ipairs(self.buf_fns) do
		table.insert(self.undolists, do_args_fn(fn, args))
	end
end
function RunBuf:undo()
	for _, undolist in ipairs(self.undolists) do
		undolist:run()
	end
end
function RunBuf:reset() end

return RunBuf
