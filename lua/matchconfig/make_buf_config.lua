local new_config = require("matchconfig.config").new
local tbl_util = require("matchconfig.util.table")
local labeled_digraph = require("matchconfig.util.digraph").new_labeled
local matchconfig = require("matchconfig.matchconfig")


local function gen_configs_from_patterns(buf, bufname, configs)
	-- use cwd if buffer for initial buffer (I guess fname == "" is the only
	-- way to detect that one).
	if bufname == "" then
		bufname = vim.loop.cwd()
	end

	local pattern_configs = {dir = {}, filetype = {}, file = {}}
	for pattern, config in pairs(configs.pattern) do
		local match = bufname:match(pattern)
		if match then
			if pattern_configs[config.category][match] then
				-- the order in which we force does not matter (for now), the
				-- only guarantee regarding priority is that file overrides
				-- dir overrides filetype.
				pattern_configs[config.category][match] = pattern_configs[config.category][match]:_append(config)
			else
				pattern_configs[config.category][match] = config
			end
		end
	end

	return pattern_configs
end

-- return list of configs, with least specific at [1], most specific at [#t].
local function dir_configs_sorted(buf, bufname, pattern_configs, configs, cwd)
	local path_so_far = ""
	local matching_configs = {}

	for _, path_component in ipairs(vim.split(cwd, "/", {plain=true})) do
		path_so_far = path_so_far .. path_component
		-- important: insert the pattern-generated config before the one that
		-- is exactly meant for this directory.
		-- Makes more sense priority-wise.
		table.insert(matching_configs, pattern_configs.dir[path_so_far])

		if configs.dir[path_so_far] then
			table.insert(matching_configs, configs.dir[path_so_far])
		end

		path_so_far = path_so_far .. "/"
	end

	return matching_configs
end

-- generate filetype-configs:
-- first filetypes from global configs, the earlier a ft in the comma-separated
-- enumeration, the higher its priority, eg the later it appears in the
-- returned list.
-- Also, all filetype-configs from global config are higher-priority than those
-- of the pattern-config.
local function filetype_configs_sorted(buf, bufname, pattern_configs, configs, filetype_string)
	local fts_reversed = {}
	for _, ft in ipairs(vim.split(filetype_string, ",", {plain=true})) do
		table.insert(fts_reversed, 1, ft)
	end

	local matching_configs = {}
	for _, ft in ipairs(fts_reversed) do
		table.insert(matching_configs, pattern_configs.filetype[ft])
	end
	for _, ft in ipairs(fts_reversed) do
		if configs.filetype[ft] then
			table.insert(matching_configs, configs.filetype[ft])
		end
	end
	return matching_configs
end

local function bufname_to_dir(bufname)
	if bufname == "" then
		return vim.loop.cwd()
	end
	if bufname:sub(1, 11) == "fugitive://" then
		-- filename is like fugitive://<.git-directory-with-trailing-slash>/
		-- omit appended / and fugitive://
		return bufname:sub(12, -2)
	end
	return vim.fn.fnamemodify(bufname, ":h")
end

-- generate config for buffer by
-- * finding all applicable configs in `configs`
-- * merging them, with more specific configs overriding/extending those more
--   general ones.
--   The exact order, by ascending priority, is
--   * dir
--   * filetype
--   * filename
--   The priority inside these categories is described further in their
--   respective functions/in this function.
local function gen_buf_config(buf, configs)
	local bufname = vim.api.nvim_buf_get_name(buf)

	local bufinfo = {
		bufnr = buf,
		fname = bufname,
		filetypes = tbl_util.list_to_set(vim.split(vim.bo[buf].filetype, ",", {plain=true})),
		dir = bufname_to_dir(bufname)
	}

	local matching_configs = {}
	for _, mc in ipairs(configs) do
		if mc:matches(bufinfo) then
			table.insert(matching_configs, mc)
		end
	end

	local digraph = labeled_digraph()
	for i, mc1 in ipairs(matching_configs) do
		digraph:set_vertex(mc1)
		for j = 1, i-1 do
			local mc2 = matching_configs[j]
			-- topological sort give us vertices with no incoming edges first
			-- => vertex that should be last needs incoming edges
			local order = mc1:order(mc2)
			if order[matchconfig.order_before] then
				-- arbitrary edge-label.
				digraph:set_edge(mc1, mc2, 1)
			end
			if order[matchconfig.order_after] then
				digraph:set_edge(mc2, mc1, 1)
			end
		end
	end

	local sorted = digraph:topological_sort({consume = true})
	if sorted == nil then
		error("There is a cycle in your config-ordering! The cycle is contained in " .. digraph:describe())
	end

	-- return empty config if there is no matching config.
	local config = new_config({})
	for _, app_conf in ipairs(sorted) do
		config:barrier()
		config:append(app_conf.config)
	end

	return config
end

return gen_buf_config
