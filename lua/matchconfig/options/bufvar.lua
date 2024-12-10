local util = require("matchconfig.util.util")

--- @class Matchconfig.BufVar: Matchconfig.Option
--- @field vars table<string, any>: map var_name to value.
local BufVar = {}
local BufVar_mt = { __index = BufVar }

local function get_buf_vars(config_raw)
	return config_raw.buf_vars or {}
end

function BufVar.new(config_raw)
	return setmetatable({
		vars = get_buf_vars(config_raw),
	}, BufVar_mt)
end

function BufVar:copy()
	local cp = setmetatable({}, BufVar_mt)
	cp.vars = vim.deepcopy(self.vars)
	return cp
end

function BufVar:append_raw(t)
	self.vars = vim.tbl_extend("force", self.vars, get_buf_vars(t))
end
function BufVar:append(rb)
	self.vars = vim.tbl_extend("force", self.vars, rb.vars)
end

BufVar.barrier = util.nop

---@class Matchconfig.BufVarApplicator: Matchconfig.OptionApplicator
---@field vars table<string, any>
---@field vars_orig table<string, any>

local BufVarApplicator = {}
local BufVarApplicator_mt = {__index = BufVarApplicator}
function BufVarApplicator.new(vars)
	return setmetatable({
		vars = vim.deepcopy(vars),
		vars_orig = {},
	}, BufVarApplicator_mt)
end
function BufVarApplicator:apply_to_barrier(i, args)
	if i ~= 1 then
		return
	end

	for k, v in pairs(self.vars) do
		self.vars_orig[k] = vim.b[args.buf][k]
		vim.b[args.buf][k] = v
	end
end
function BufVarApplicator:undo(bufnr)
	for k, v_orig in pairs(self.vars_orig) do
		vim.b[bufnr][k] = v_orig
	end
end

function BufVar:make_applicator()
	return BufVarApplicator.new(self.vars)
end

function BufVar:reset() end

return {
	new = BufVar.new,
	reset = util.nop
}
