local util = require("matchconfig.util.util")

--- @class LuasnipFT: Option
--- @field ft_extensions table<string, string[]>
local LuasnipFT = {}
local LuasnipFT_mt = { __index = LuasnipFT }
function LuasnipFT.new(config)
	return setmetatable({
		ft_extensions = config.luasnip_ft_extend or {}
	}, LuasnipFT_mt)
end

local function extend_ft_extensions(extendee, extend_vals)
	for ft, extensions in pairs(extend_vals) do
		if not extendee[ft] then
			extendee[ft] = extensions
		else
			vim.list_extend(extendee[ft], extensions)
		end
	end
end
function LuasnipFT:append_raw(t)
	extend_ft_extensions(self.ft_extensions, t.luasnip_ft_extend or {})
end
function LuasnipFT:append(l)
	extend_ft_extensions(self.ft_extensions, l.ft_extensions)
end

function LuasnipFT:undo(bufnr)
	vim.b[bufnr].luasnip_ft_extend = {}
end
function LuasnipFT.reset() end

LuasnipFT.barrier = util.nop
function LuasnipFT:make_applicator()
	return self
end
function LuasnipFT:apply_to_barrier(i, args)
	if i ~= 0 then
		return
	end
	vim.b[args.buf].luasnip_ft_extend = self.ft_extensions
end

-- supply to luasnip.
function LuasnipFT.ft_func()
	local fts = require("luasnip.extras.filetype_functions").from_pos_or_filetype()
		-- should be possible to extend `all`-filetype.
		table.insert(fts, "all")
		local effective_fts = {}

		local buflocal_extend = vim.b.luasnip_ft_extend
		if buflocal_extend then
			for _, ft in ipairs(fts) do
				vim.list_extend(effective_fts, buflocal_extend[ft] or {})
			end
			vim.list_extend(effective_fts, fts)
		else
			effective_fts = fts
		end

		return effective_fts
end

return LuasnipFT
