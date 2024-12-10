local ConfigApplicator = require("matchconfig.primitives.config_applicator")

--- @class Matchconfig.ConfigSource
--- @field type string
--- @field fname string
--- @field id string

--- @class Matchconfig.Config
--- @field options Matchconfig.Option[]
--- @field sources Matchconfig.ConfigSource[]
--- @field n_barriers number How many barriers do the options have at most.
local Config = {}
local Config_mt = {
	__index = Config,
	__concat = function(a,b)
		return a:append(b)
	end
}

local session_data = require("matchconfig.session.data")

function Config.new(t)
	local options = {}
	for id, Opt in ipairs(session_data.options) do
		options[id] = Opt.new(t)
	end

	return setmetatable({
		options = options,
		sources = {},
		n_barriers = 0
	}, Config_mt)
end

function Config:copy()
	local c = setmetatable({}, Config_mt)

	local options = {}
	for id, opt in ipairs(self.options) do
		options[id] = opt:copy()
	end
	c.options = options

	-- noref=true => sources-table doesn't have cyclic fields.
	c.sources = vim.deepcopy(self.sources, true)
	c.n_barriers = self.n_barriers

	return c
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
	for _, opt in ipairs(self.options) do
		opt:append_raw(t)
	end
	-- facilitate function-chaining.
	return self
end

--- Extend this config with the values from other config c.
---@param c Matchconfig.Config
function Config:_append(c)
	for id, opt in ipairs(self.options) do
		opt:append(c.options[id])
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
	for _, opt in ipairs(self.options) do
		opt:barrier()
	end
	self.n_barriers = self.n_barriers + 1
end

function Config:make_applicator()
	local applicators = {}
	for name, opt in ipairs(self.options) do
		applicators[name] = opt:make_applicator()
	end
	return ConfigApplicator.new(applicators, self.n_barriers)
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
