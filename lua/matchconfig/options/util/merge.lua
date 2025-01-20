local util = require("matchconfig.util.util")

---@class Matchconfig.Merge.Extend
---@field extend_with any May be a list or a function
local Extend = {}
local Extend_mt = {__index = Extend}

local function new_Extend(extend_with)
	return setmetatable({
		extend_with = extend_with,
	}, Extend_mt)
end

function Extend:apply(t)
	if t == nil then
		if type(self.extend_with) == "function" then
			t = util.nop
		else
			t = {}
		end
	else
		if vim.islist(t) then
			assert(vim.islist(self.extend_with), "Can only extend list with another list.")
			local t_cp = vim.list_slice(t)
			return vim.list_extend(t_cp, self.extend_with)
		elseif type(t) == "function" then
			assert(type(self.extend_with) == "function", "Can only extend function with another function.")
			return function(...)
				t(...)
				self.extend_with(...)
			end
		else
			error("Cannot extend t of type " .. type(t))
		end
	end
end

---@class Matchconfig.Merge.Replace
---@field t any
local Replace = {}
local Replace_mt = {__index = Replace}

local function new_Replace(t)
	return setmetatable({
		t = t,
	}, Replace_mt)
end

function Replace:apply()
	return self.t
end

return {
	list_extend = new_Extend,
	replace = new_Replace,
	is_mergeop = function(t)
		local t_mt = getmetatable(t)
		return t_mt == Extend_mt or t_mt == Replace_mt
	end
}
