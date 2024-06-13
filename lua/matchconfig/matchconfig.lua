local util = require("matchconfig.util.util")

local Matchconfig = {}
local Matchconfig_mt = {__index = Matchconfig}

function Matchconfig.new(config, matcher, tags, after, before)
	tags = matcher:tags()
	vim.list_extend(matcher:tags(), tags or {})
	return setmetatable({
		config = config,
		matcher = matcher,
		tags = tags,
		-- what configs to run this after
		_after = after and util.list_to_set(after) or util.empty,
		-- what configs to run this before
		_before = before and util.list_to_set(before) or util.empty
	}, Matchconfig_mt)
end

function Matchconfig_mt:__tostring()
	return self.matcher:human_readable(true)
end

function Matchconfig:before(other)
	if self._before == util.empty then
		self._before = {[other] = true}
	else
		self._before[other] = true
	end
end

function Matchconfig:after(other)
	if self._after == util.empty then
		self._after = {[other] = true}
	else
		self._after[other] = true
	end
end

-- return whether `self` should run after `other` (ie. override it).
function Matchconfig:comes_after(other)
	if self._after[other] then
		return true
	end
	if other._before[self] then
		return true
	end
	for _, tag in ipairs(other.tags) do
		if self._after[tag] then
			return true
		end
	end
	for _, tag in ipairs(self.tags) do
		if other._before[tag] then
			return true
		end
	end
	return false
end

Matchconfig.order_before = 1
Matchconfig.order_after = 2
function Matchconfig:order(other)
	local order = {}
	if self:comes_after(other) then
		order[Matchconfig.order_after] = true
	end
	if other:comes_after(self) then
		order[Matchconfig.order_before] = true
	end
	return order
end

-- bufinfo:
-- * bufnr
-- * bufname
-- * set_filetypes (filetypes as table<string, true>)
function Matchconfig:matches(bufinfo)
	return self.matcher:matches(bufinfo)
end

return Matchconfig
