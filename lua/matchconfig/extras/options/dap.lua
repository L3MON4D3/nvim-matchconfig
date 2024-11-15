local util = require("matchconfig.util.util")

--- @class Matchconfig.Extras.Dap: Matchconfig.Option
--- @field type_configs table<string, table>
local Dap = {}
local Dap_mt = { __index = Dap }

function Dap.new(config)
	return setmetatable({
		type_configs = config.dap or {},
	}, Dap_mt)
end

function Dap:copy()
	-- noref: true
	return setmetatable({
		type_configs = vim.deepcopy(self.type_configs, true)
	}, Dap_mt)
end

function Dap:append_raw(t)
	if t.dap then
		for _, dap_conf in ipairs(t.dap) do
			self.type_configs[dap_conf.my_type] = dap_conf
		end
	end
end
function Dap:append(dap)
	for type, dap_conf in pairs(dap.type_configs) do
		self.type_configs[type] = dap_conf
	end
end
Dap.barrier = util.nop

local DapApplicator = {}
local DapApplicator_mt = {__index = DapApplicator}

function DapApplicator.new(type_configs)
	return setmetatable({type_configs = type_configs}, DapApplicator_mt)
end
function DapApplicator:apply_to_barrier(j, args)
	-- only apply once, partial apply doesn't really make sense.
	if j ~= 1 then
		return
	end

	local dap = require("dap")
	local config_list = {}
	for _, v in pairs(self.type_configs) do
		table.insert(config_list, v)
	end

	vim.keymap.set("n", "<F5>", function()
		if dap.session() then
			-- session active, just do regular continue.
			dap.continue()
			return
		end

		-- otherwise, open picker to select from possible configs.
		require("dap.ui").pick_if_many(
			config_list,
			"Configuration: ",
			function(i) return i.name end,
			function(configuration)
				if configuration then
					vim.notify('Running configuration ' .. configuration.name, vim.log.levels.INFO, {title = "DAP"})
					dap.run(configuration)
				else
					vim.notify('No configuration selected', vim.log.levels.INFO, {title = "DAP"})
				end
			end
		)
	end, { buffer = args.buf })
end

function DapApplicator:undo(bufnr)
	-- pcall in case the keymap was already deleted.
	pcall(vim.keymap.del, "n", "<F5>", { buffer = bufnr })
end

function Dap:make_applicator()
	return DapApplicator.new(self.type_configs)
end

return {
	new = Dap.new,
	reset = util.nop
}
