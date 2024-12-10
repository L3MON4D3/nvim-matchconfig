local do_args_fn = require("matchconfig.util.actions").do_args_fn
local tbl_util = require("matchconfig.util.table")
local util = require("matchconfig.util.util")

--- @class Matchconfig.RunBufNamed: Matchconfig.Option
--- @field barrier_fns table<fun(args)>[]: opts_to_barrier[1] contains all functions that
--- should be run before the first barrier.
local RunBufNamed = {}
local RunBufNamed_mt = { __index = RunBufNamed }

local function get_buf_fns(config_raw)
	return config_raw.run_buf_named or {}
end

function RunBufNamed.new(config_raw)
	return setmetatable({
		barrier_fns = {get_buf_fns(config_raw)},
	}, RunBufNamed_mt)
end

function RunBufNamed:copy()
	local cp = setmetatable({}, RunBufNamed_mt)
	cp.barrier_fns = vim.deepcopy(self.barrier_fns)

	return cp
end

-- for appending: don't delete functions from previous barriers that would not
-- be executed.
function RunBufNamed:append_raw(t)
	vim.tbl_extend("force", self.barrier_fns[#self.barrier_fns], get_buf_fns(t))
end
function RunBufNamed:append(rb)
	-- carefule: rb may have barriers in place, so: add the first set to the
	-- last one of self, then append the remaining sets.
	self.barrier_fns[#self.barrier_fns] = vim.tbl_extend("force", self.barrier_fns[#self.barrier_fns], rb.barrier_fns[1])
	vim.list_extend(self.barrier_fns, rb.barrier_fns, 2, #rb.barrier_fns)
end

function RunBufNamed:barrier()
	table.insert(self.barrier_fns, {})
end

---@class Matchconfig.RunBufNamedApplicator: Matchconfig.OptionApplicator
---@field barrier_fns table<string, any>[]: 
---@field opts_orig table<string, any>[]

local RunBufNamedApplicator = {}
local RunBufNamedApplicator_mt = {__index = RunBufNamedApplicator}
function RunBufNamedApplicator.new(barrier_fns, barrier_args)
	local bf = vim.deepcopy(barrier_fns)

	-- for a table like
	-- {
	--  {a = <fn>, b = <fn>},
	--  {a = <fn>, c = <fn>},
	--  {a = <fn>, b = <fn>},
	-- },
	-- produce
	-- {
	--  {},
	--  {c = <fn>},
	--  {a = <fn>, b = <fn>},
	-- },
	-- such that functions that are overwritten later are not executed.
	local used_names = {}
	for i = #bf, 1, -1 do
		for name, _ in pairs(used_names) do
			bf[i][name] = nil
		end
		for name, _ in pairs(bf[i]) do
			used_names[name] = true
		end
	end

	return setmetatable({
		barrier_fns = bf,
		undolists = {},
		barrier_args = barrier_args
	}, RunBufNamedApplicator_mt)
end
function RunBufNamedApplicator:apply_to_barrier(i, args)
	args = tbl_util.shallow_copy(args)
	for _, fn in pairs(self.barrier_fns[i]) do
		args.match_args = self.barrier_args[i]
		table.insert(self.undolists, do_args_fn(fn, args))
	end
end
function RunBufNamedApplicator:undo(_)
	for _, undolist in ipairs(self.undolists) do
		undolist:run()
	end
end

function RunBufNamed:make_applicator(barrier_args)
	return RunBufNamedApplicator.new(self.barrier_fns, barrier_args)
end

function RunBufNamed:reset() end

return {
	new = RunBufNamed.new,
	reset = util.nop
}
