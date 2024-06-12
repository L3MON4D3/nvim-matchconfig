--- @class Dap: Option
--- @field type_configs table<string, table>
local Dap = {}
local Dap_mt = { __index = Dap }

function Dap.new(config)
	local type_configs = {}
	if config.dap then
		for _, dap_conf in ipairs(config.dap) do
			type_configs[dap_conf.my_type] = dap_conf
		end
	end

	return setmetatable({
		type_configs = type_configs,
	}, Dap_mt)
end

function Dap:apply(args)
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

function Dap:undo(bufnr, _)
	pcall(vim.keymap.del, "n", "<F5>", { buffer = bufnr })
end

return Dap
