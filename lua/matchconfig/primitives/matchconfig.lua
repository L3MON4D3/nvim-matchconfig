local util = require("matchconfig.util.util")

local Matchconfig = {}
local Matchconfig_mt = {__index = Matchconfig}

function Matchconfig.new(config, matcher, tags)
	local effective_tags = matcher:tags()
	vim.list_extend(effective_tags, tags or {})
	return setmetatable({
		config = config,
		matcher = matcher,
		tags = effective_tags,
		-- what configs to run this after
		_after = util.empty,
		-- what configs to run this before
		_before = util.empty,

		-- which configs should be disabled, and which re-enabled.
		_blacklist = util.empty,
		_unblacklist = util.empty,

		_blacklist_by = util.empty,
		_unblacklist_by = util.empty,
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

-- blacklist and unblacklist imply that this mc is run after the other mc
-- (blacklisting implies higher priority)
function Matchconfig:blacklist(other_or_tag)
	self:after(other_or_tag)
	if self._blacklist == util.empty then
		self._blacklist = {[other_or_tag] = true}
	else
		self._blacklist[other_or_tag] = true
	end
end
function Matchconfig:unblacklist(other_or_tag)
	self:after(other_or_tag)
	if self._unblacklist == util.empty then
		self._unblacklist = {[other_or_tag] = true}
	else
		self._unblacklist[other_or_tag] = true
	end
end

function Matchconfig:blacklist_by(other_or_tag)
	self:before(other_or_tag)
	if self._blacklist_by == util.empty then
		self._blacklist_by = {[other_or_tag] = true}
	else
		self._blacklist_by[other_or_tag] = true
	end
end
function Matchconfig:unblacklist_by(other_or_tag)
	self:before(other_or_tag)
	if self._unblacklist_by == util.empty then
		self._unblacklist_by = {[other_or_tag] = true}
	else
		self._unblacklist_by[other_or_tag] = true
	end
end

function Matchconfig:blacklists(other)
	if self._blacklist[other] then
		return true
	end
	if other._blacklist_by[self] then
		return true
	end

	for _, tag in ipairs(other.tags) do
		if self._blacklist[tag] then
			return true
		end
	end
	for _, tag in ipairs(self.tags) do
		if other._blacklist_by[tag] then
			return true
		end
	end

	return false
end
function Matchconfig:unblacklists(other)
	if self._unblacklist[other] then
		return true
	end
	if other._unblacklist_by[self] then
		return true
	end

	for _, tag in ipairs(other.tags) do
		if self._unblacklist[tag] then
			return true
		end
	end
	for _, tag in ipairs(self.tags) do
		if other._unblacklist_by[tag] then
			return true
		end
	end

	return false
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
