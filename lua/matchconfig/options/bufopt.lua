local util = require("matchconfig.util.util")

--- @class Matchconfig.BufOpt: Matchconfig.Option
--- @field barrier_opts table<string, any>[]: opts_to_barrier[1] contains all options that
--- should be applied before the first barrier.
local BufOpt = {}
local BufOpt_mt = { __index = BufOpt }

local function get_buf_opt(config_raw)
	local opts = config_raw.buf_opts or {}
	for optname, _ in pairs(opts) do
		local ok, _ = pcall(function()
			return vim.bo[optname]
		end)
		if not ok then
			error("BufOpt received invalid option-name " .. optname)
		end
	end
	return opts
end

function BufOpt.new(config_raw)
	return setmetatable({
		barrier_opts = {get_buf_opt(config_raw)},
	}, BufOpt_mt)
end

function BufOpt:copy()
	local cp = setmetatable({}, BufOpt_mt)
	cp.barrier_opts = vim.deepcopy(self.barrier_opts)

	return cp
end

function BufOpt:append_raw(t)
	vim.tbl_deep_extend("force", self.barrier_opts[#self.barrier_opts], get_buf_opt(t))
end
function BufOpt:append(rb)
	-- carefule: rb may have barriers in place, so: add the first set to the
	-- last one of self, then append the remaining sets.
	self.barrier_opts[#self.barrier_opts] = vim.tbl_deep_extend("force", self.barrier_opts[#self.barrier_opts], rb.barrier_opts[1])
	vim.list_extend(self.barrier_opts, rb.barrier_opts, 2, #rb.barrier_opts)
end

function BufOpt:barrier()
	table.insert(self.barrier_opts, {})
end

---@class Matchconfig.BufOptApplicator: Matchconfig.OptionApplicator
---@field barrier_opts table<string, any>[]: 
---@field opts_orig table<string, any>[]

local BufOptApplicator = {}
local BufOptApplicator_mt = {__index = BufOptApplicator}
function BufOptApplicator.new(barrier_opts)
	return setmetatable({
		barrier_opts = vim.deepcopy(barrier_opts),
		opts_orig = {},
	}, BufOptApplicator_mt)
end
function BufOptApplicator:apply_to_barrier(i, args)
	for optname, optval in pairs(self.barrier_opts[i]) do
		-- if we set an option twice, opts_orig should contain the value before
		-- we first set it.
		self.opts_orig[optname] = self.opts_orig[optname] or vim.bo[args.buf][optname]
		vim.bo[args.buf][optname] = optval
	end
end
function BufOptApplicator:undo(bufnr)
	for optname, optval_orig in pairs(self.opts_orig) do
		vim.bo[bufnr][optname] = optval_orig
	end
end

function BufOpt:make_applicator()
	return BufOptApplicator.new(self.barrier_opts)
end

function BufOpt:reset() end

return {
	new = BufOpt.new,
	reset = util.nop
}
