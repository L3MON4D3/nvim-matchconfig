--- @class ConfigSource
--- @field type string
--- @field fname string
--- @field id string

--- @class Config
--- @field options Option[]
--- @field sources ConfigSource[]
--- @field n_barriers number How many barriers do the options have at most.
local Config = {}
local Config_mt = {__index = Config}

local session = require("matchconfig.session")

function Config.new(t)
	local options = {}
	for id, Opt in pairs(session.options) do
		options[id] = Opt.new(t)
	end

	return setmetatable({
		options = options,
		category = t.category,
		sources = {},
		n_barriers = 0
	}, Config_mt)
end
function Config.as_config(t_or_c)
	if getmetatable(t_or_c) == Config_mt then
		return t_or_c
	else
		return Config.new(t_or_c)
	end
end

--- Extend this config with the values from t.
---@param t table
function Config:_append_raw(t)
	for _, opt in pairs(self.options) do
		opt:append_raw(t)
	end
	if t.category then
		self.category = t.category
	end
	-- facilitate function-chaining.
	return self
end

--- Extend this config with the values from other config c.
---@param c Config
function Config:_append(c)
	for id, opt in pairs(self.options) do
		opt:append(c.options[id])
	end
	if c.category then
		self.category = c.category
	end
	if c.sources then
		vim.list_extend(self.sources, c.sources)
	end
	-- facilitate function-chaining.
	return self
end

--- Extend this config with the values from other config or table t_or_c.
---@param t_or_c table table or Config, but if I use Config here, using it as
---table complains about required fields :(
function Config:append(t_or_c)
	if getmetatable(t_or_c) == Config_mt then
		self:_append(t_or_c)
	else
		self:_append_raw(t_or_c)
	end
	return self
end

function Config:barrier()
	for _, opt in pairs(self.options) do
		opt:barrier()
	end
	self.n_barriers = self.n_barriers + 1
end

function Config:apply(args)
	local applicators = {}
	for name, opt in pairs(self.options) do
		applicators[name] = opt:make_applicator()
	end
	-- lua-for is end-inclusive => don't need +1.
	for i = 0, self.n_barriers do
		for _, applicator in pairs(applicators) do
			applicator:apply_to_barrier(i, args)
		end
	end
end

function Config:undo(bufnr)
	for _, opt in pairs(self.options) do
		opt:undo(bufnr)
	end
end

--- Set source for this config
---@param fname string
---@param line number
---@param type "pattern"|"dir"|"file"|"pattern"
---@param id string
function Config:set_source(fname, line, type, id)
	-- override source.
	self.sources = {{
		fname = fname,
		line = line,
		type = type,
		id = id,
	}}
end

return Config
