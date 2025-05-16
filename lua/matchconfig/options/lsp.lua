local util = require("matchconfig.util.util")
local tbl_util = require("matchconfig.util.table")
local eval_util = require("matchconfig.options.util.eval")
local log = require("matchconfig.util.log").new("lsp")

local merge = require("matchconfig.options.util.merge")

--- @class Matchconfig.LSP: Matchconfig.Option
--- @field lsp_specs table[]
local LSP = {}
local LSP_mt = { __index = LSP }

local function get_lsp_spec(config_raw)
	local spec = vim.deepcopy(config_raw.lsp)

	return spec
end

function LSP.new(config_raw)
	return setmetatable({
		lsp_specs = {get_lsp_spec(config_raw)}
	}, LSP_mt)
end

function LSP:copy()
	return vim.deepcopy(self)
end

function LSP:append_raw(t)
	table.insert(self.lsp_specs, get_lsp_spec(t))
end
function LSP:append(rb)
	vim.list_extend(self.lsp_specs, rb.lsp_specs)
end

-- use function to guarantee by-value copying!
local barrier = util.nop
function LSP:barrier()
	-- insert barriers to access correct barrier_args.
	table.insert(self.lsp_specs, barrier)
end

---@class Matchconfig.LSPApplicator: Matchconfig.OptionApplicator
---@field lsp_specs table[]
---@field attached_clients Matchconfig.LspClientExt[] list of clients attached by this applicator.
---@field barrier_args any[]
---@field bufnr integer store bufnr to restore with.
---@field
local LSPApplicator = {}
local LSPApplicator_mt = {__index = LSPApplicator}
function LSPApplicator.new(lsp_specs, barrier_args)
	return setmetatable({
		lsp_specs = lsp_specs,
		barrier_args = barrier_args,
		attached_clients = {}
	}, LSPApplicator_mt)
end

-- leaves are all datatypes except tables with only non-numerical values.
local function is_inner_node(t)
	return type(t) == "table" and (not t[1]) and getmetatable(t) == nil
end

local default_capabilities = vim.lsp.protocol.make_client_capabilities()

local lsp_client_pool = require("matchconfig.options.util.lsp_client_pool").new()

function LSPApplicator:apply_to_barrier(call_b_idx, args)
	if call_b_idx ~= 1 then
		return
	end
	args = vim.deepcopy(args)

	local specs_no_eval = {}

	local lsp_types = {}

	local barrier_i = 1
	for _, spec in ipairs(self.lsp_specs) do
		if spec == barrier then
			barrier_i = barrier_i + 1
		else
			for lsp_name, _ in pairs(spec) do
				lsp_types[lsp_name] = true
			end
			tbl_util.tbl_do(spec, function(imm_parent, keys_abs, v)
				if eval_util.is_eval(v) then
					args.match_args = self.barrier_args[barrier_i]
					imm_parent[keys_abs[#keys_abs]] = v:apply(args)
					return false
				end
				return true
			end)
			table.insert(specs_no_eval, spec)
		end
	end

	local specs_merged = {}
	log.debug("buffer %s has lsp-specs %s", args.buf, vim.inspect(specs_no_eval))

	for lsp_name, _ in pairs(lsp_types) do
		specs_merged[lsp_name] = {
			capabilities = default_capabilities
		}
	end

	for _, spec in ipairs(specs_no_eval) do
		tbl_util.tbl_do(spec, function(_, keys_abs, v)
			if is_inner_node(v) then
				return true
			end
			-- we are dealing with a terminal value.
			if merge.is_mergeop(v) then
				-- replace value in specs_merged with apply-value.
				v = v:apply(tbl_util.get(specs_merged, keys_abs))
			else
				if type(v) == "table" and getmetatable(v) then
					error("Unexpected metatable in spec at " .. vim.inspect(keys_abs))
				end
			end

			tbl_util.set(specs_merged, keys_abs, v)
			-- don't recurse
			return false
		end)
	end

	local clients = {}
	for lsp_name, lsp_spec in pairs(specs_merged) do
		lsp_spec.name = lsp_name

		tbl_util.tbl_do(lsp_spec.settings or {}, function(_, keys_abs, v)
			assert(type(v) ~= "function", "lsp-config may not contain a function, please check " .. vim.inspect(keys_abs) .. " for a function-value")
		end)

		local client = lsp_client_pool:attach_matching(args.buf, lsp_spec)
		if client then
			table.insert(clients, client)
		end
	end

	self.attached_clients = clients
	self.bufnr = args.buf
	self.run_restore_connection = true
	if #clients > 0 then
		-- currently, all clients are detached on :edit, make sure we correctly
		-- reattach after.
		self:setup_restore_connection_on_detach()
	end
end

function LSPApplicator:setup_restore_connection_on_detach()
	vim.api.nvim_buf_attach(self.bufnr, false, {
		on_detach = function()
			vim.schedule(function()
				if not self.run_restore_connection then
					return
				end
				for _, client in ipairs(self.attached_clients) do
					client:restore_connection(self.bufnr)
				end
				self:setup_restore_connection_on_detach()
			end)
		end
	})
end

function LSPApplicator:undo(_)
	for _, client in ipairs(self.attached_clients) do
		client:detach_buf(self.bufnr)
	end
	self.run_restore_connection = false
end

function LSP:make_applicator(barrier_args)
	return LSPApplicator.new(vim.deepcopy(self.lsp_specs), barrier_args)
end

function LSP:reset() end

return {
	new = LSP.new,
	reset = util.nop,
	set_default_capabilities = function(caps)
		default_capabilities = caps
	end,
	clean_unattached = function() lsp_client_pool:clean_unattached() end
}
