local make_human_readable = require("matchconfig.util.util").make_human_readable
local fs = require("matchconfig.util.fs")

local M = {}

--- @class Matchconfig.DirMatcher : Matchconfig.Matcher
--- @field dir string
local DirMatcher = {}
local DirMatcher_mt = {__index = DirMatcher}

DirMatcher.matcher_id = "dir"

function DirMatcher.new(dir)
	return setmetatable({ dir = fs.normalize_dir(dir) }, DirMatcher_mt)
end

---@param bufinfo Matchconfig.BufInfo
function DirMatcher:matches(bufinfo)
	return bufinfo.dir:sub(1, #self.dir) == self.dir and (
		bufinfo.dir:sub(#self.dir+1, #self.dir+1) == "/" or
		bufinfo.dir:sub(#self.dir+1, #self.dir+1) == "") and self.dir
end

function DirMatcher:human_readable(include_matcher_id)
	return make_human_readable(self.matcher_id, self.dir, include_matcher_id)
end
function DirMatcher:tags()
	return {self.matcher_id, self:human_readable(true)}
end


--- @class Matchconfig.FileMatcher : Matchconfig.Matcher
--- @field file string
local FileMatcher = {}
local FileMatcher_mt = {__index = FileMatcher}

FileMatcher.matcher_id = "file"

function FileMatcher.new(file)
	return setmetatable({ file = file }, FileMatcher_mt)
end

---@param bufinfo Matchconfig.BufInfo
function FileMatcher:matches(bufinfo)
	return bufinfo.fname == self.file and self.file
end
function FileMatcher:human_readable(include_matcher_id)
	return make_human_readable(self.matcher_id, self.file, include_matcher_id)
end
function FileMatcher:tags()
	return {self.matcher_id, self:human_readable(true)}
end


local FiletypeMatcher = {}
local FiletypeMatcher_mt = {__index = FiletypeMatcher}

FiletypeMatcher.matcher_id = "filetype"

function FiletypeMatcher.new(filetype)
	return setmetatable({ ft = filetype }, FiletypeMatcher_mt)
end

---@param bufinfo Matchconfig.BufInfo
function FiletypeMatcher:matches(bufinfo)
	return bufinfo.filetypes[self.ft] ~= nil and self.ft
end
function FiletypeMatcher:human_readable(include_matcher_id)
	return make_human_readable(self.matcher_id, self.ft, include_matcher_id)
end
function FiletypeMatcher:tags()
	return {self.matcher_id, self:human_readable(true)}
end


local PatternMatcher = {}
local PatternMatcher_mt = {__index = PatternMatcher}

PatternMatcher.matcher_id = "pattern"

function PatternMatcher.new(pattern)
	return setmetatable({ pattern = pattern }, PatternMatcher_mt)
end

---@param bufinfo Matchconfig.BufInfo
function PatternMatcher:matches(bufinfo)
	return bufinfo.fname:match(self.pattern)
end
function PatternMatcher:human_readable(include_matcher_id)
	return make_human_readable(self.matcher_id, self.pattern, include_matcher_id)
end
function PatternMatcher:tags()
	return {self.matcher_id, self:human_readable(true)}
end


local GenericMatcher = {}
local GenericMatcher_mt = {__index = GenericMatcher}

function GenericMatcher.new(fn, id, matcher_id)
	return setmetatable({ fn = fn, id = id, matcher_id = matcher_id or "generic" }, GenericMatcher_mt)
end

---@param bufinfo Matchconfig.BufInfo
function GenericMatcher:matches(bufinfo)
	return self.fn(bufinfo)
end
function GenericMatcher:human_readable(include_matcher_id)
	return make_human_readable(self.matcher_id, self.id, include_matcher_id)
end
function GenericMatcher:tags()
	return {self.matcher_id, self:human_readable(true)}
end

local function matcher_and(a,b)
	return GenericMatcher.new(function(bufinfo)
		local match_a = a:matches(bufinfo)
		local match_b = b:matches(bufinfo)
		return (match_a and match_b) and {match_a, match_b}
	end, a:human_readable(true) .. " & " .. b:human_readable(true))
end
local function matcher_or(a,b)
	return GenericMatcher.new(function(bufinfo)
		local match_a = a:matches(bufinfo)
		local match_b = b:matches(bufinfo)
		return (match_a or match_b) and {match_a, match_b}
	end, a:human_readable(true) .. " | " .. b:human_readable(true))
end

local function make_matcher(matcher_mt)
	matcher_mt.__mul = matcher_and
	matcher_mt.__add = matcher_or
end

make_matcher(DirMatcher_mt)
make_matcher(FileMatcher_mt)
make_matcher(FiletypeMatcher_mt)
make_matcher(PatternMatcher_mt)
make_matcher(GenericMatcher_mt)

M.dir = DirMatcher
M.file = FileMatcher
M.filetype = FiletypeMatcher
M.pattern = PatternMatcher
M.generic = GenericMatcher

return M
