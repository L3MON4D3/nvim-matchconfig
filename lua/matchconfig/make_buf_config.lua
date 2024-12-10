local new_config = require("matchconfig.primitives.config").new
local tbl_util = require("matchconfig.util.table")
local labeled_digraph = require("matchconfig.util.digraph").new_labeled
local matchconfig = require("matchconfig.primitives.matchconfig")

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

	local sorted_whitelisted = {}

	for i = 1, #sorted do
		local mc = sorted[i]
		local whitelisted = true
		-- whitelisted-status is only influenced by higher-priority mc => only
		-- iterate over these.
		for j = i+1, #sorted do
			if sorted[j]:blacklists(mc) then
				whitelisted = false
			elseif sorted[j]:unblacklists(mc) then
				whitelisted = true
			end
		end
		if whitelisted then
			table.insert(sorted_whitelisted, mc)
		end
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
