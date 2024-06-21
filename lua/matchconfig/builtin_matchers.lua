local M = {}

--- @class BufInfo
--- @field bufnr number
--- @field fname string
--- @field filetypes table<string, boolean>
--- @field dir string

local function make_hr(matcher_id, id, full)
	if full then
		return matcher_id .. "(" ..id .. ")"
	else
		return id
	end
end

local DirMatcher = {}
local DirMatcher_mt = {__index = DirMatcher}

DirMatcher.matcher_id = "dir"

function DirMatcher.new(dir)
	return setmetatable({ dir = dir }, DirMatcher_mt)
end

---@param bufinfo BufInfo
function DirMatcher:matches(bufinfo)
	return bufinfo.dir:sub(1, #self.dir) == self.dir
end
function DirMatcher:human_readable(full)
	return make_hr(self.matcher_id, self.dir, full)
end
function DirMatcher:tags()
	return {self.matcher_id, self:human_readable(true)}
end


local FileMatcher = {}
local FileMatcher_mt = {__index = FileMatcher}

FileMatcher.matcher_id = "file"

function FileMatcher.new(file)
	return setmetatable({ file = file }, FileMatcher_mt)
end

---@param bufinfo BufInfo
function FileMatcher:matches(bufinfo)
	return bufinfo.fname == self.file
end
function FileMatcher:human_readable(full)
	return make_hr(self.matcher_id, self.file, full)
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

---@param bufinfo BufInfo
function FiletypeMatcher:matches(bufinfo)
	return bufinfo.filetypes[self.ft] ~= nil
end
function FiletypeMatcher:human_readable(full)
	return make_hr(self.matcher_id, self.ft, full)
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

---@param bufinfo BufInfo
function PatternMatcher:matches(bufinfo)
	return bufinfo.fname:match(self.pattern)
end
function PatternMatcher:human_readable(full)
	return make_hr(self.matcher_id, self.pattern, full)
end
function PatternMatcher:tags()
	return {self.matcher_id, self:human_readable(true)}
end


local GenericMatcher = {}
local GenericMatcher_mt = {__index = GenericMatcher}

GenericMatcher.matcher_id = "generic"

function GenericMatcher.new(fn, id)
	return setmetatable({ fn = fn, id = id }, GenericMatcher_mt)
end

---@param bufinfo BufInfo
function GenericMatcher:matches(bufinfo)
	return self.fn(bufinfo)
end
function GenericMatcher:human_readable(full)
	return make_hr(self.matcher_id, self.id, full)
end
function GenericMatcher:tags()
	return {self.matcher_id, self:human_readable(true)}
end

local function matcher_and(a,b)
	return GenericMatcher.new(function(bufinfo)
		return a:matches(bufinfo) and b:matches(bufinfo)
	end, a:human_readable(true) .. " & " .. b:human_readable(true))
end

local function make_matcher(matcher_mt)
	matcher_mt.__mul = matcher_and
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
