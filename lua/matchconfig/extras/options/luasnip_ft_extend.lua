local util = require("matchconfig.util.util")

--- @class Matchconfig.Extras.LuasnipFT: Matchconfig.Option
--- @field ft_extensions table<string, string[]>
local LuasnipFT = {}
local LuasnipFT_mt = { __index = LuasnipFT }
function LuasnipFT.new(config)
	return setmetatable({
		ft_extensions = config.luasnip_ft_extend or {}
	}, LuasnipFT_mt)
end

function LuasnipFT:copy()
	return setmetatable({
		ft_extensions = vim.deepcopy(self.ft_extensions, true)
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

LuasnipFT.barrier = util.nop

---@class Matchconfig.Extras.LuasnipFTApplicator: Matchconfig.OptionApplicator
---@field ft_extensions table<string, string[]>
local LuasnipFTApplicator = {}
local LuasnipFTApplicator_mt = {__index = LuasnipFTApplicator}

function LuasnipFTApplicator.new(ft_extensions)
	return setmetatable({ft_extensions = ft_extensions}, LuasnipFTApplicator_mt)
end
function LuasnipFTApplicator:apply_to_barrier(i, args)
	-- partial updates don't seem to make sense to me, only set
	-- `luasnip_ft_extend` once.
	if i ~= 1 then
		return
	end
	vim.b[args.buf].luasnip_ft_extend = self.ft_extensions
end
function LuasnipFTApplicator:undo(bufnr)
	vim.b[bufnr].luasnip_ft_extend = nil
end

function LuasnipFT:make_applicator()
	return LuasnipFTApplicator.new(self.ft_extensions)
end

return {
	new = LuasnipFT.new,
	reset = util.nop,
	ft_func = function()
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
}
