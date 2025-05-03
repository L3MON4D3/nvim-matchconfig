local log = require("matchconfig.util.log").new("lsp-pool")
local util = require("matchconfig.util.util")

--- @class Matchconfig.LspClientPool
--- @field client_ids integer[] ids of all known clients
--- @field attach_matching fun(client_pool, bufnr, lsp_spec): integer attach buffer bufnr to a
--- lsp-client matching the given lsp-spec. May also start a new lsp-client.
--- @field clean_unattached fun(client_pool) Remove clients that are not attached to any buffer.
local LspClientPool = {}
local LspClientPool_mt = {__index = LspClientPool}

local function new()
	return setmetatable({client_ids = {}}, LspClientPool_mt)
end

function LspClientPool:attach_matching(bufnr, config)
	for _, client_id in ipairs(self.client_ids) do
		local client = vim.lsp.get_client_by_id(client_id)
		-- We know that the client_id is valid (unless some other plugin messed
		-- with the clients)
		---@cast client -nil

		local cl_config = client.config
		if
			cl_config.name == config.name and
			cl_config.root_dir == config.root_dir and
			vim.deep_equal(cl_config.cmd, config.cmd) then

			-- launched programs are compatible, check settings.

			if vim.deep_equal(cl_config.settings, config.settings) then
				log.info("attaching buffer %s to client %s", bufnr, config.name)
				vim.lsp.buf_attach_client(bufnr, client_id)
				return client_id
			end

			-- TODO: how to handle changed callbacks (on_exit, on_init)??
			-- For now, only provide command for reloading some client.
			if #vim.lsp.get_buffers_by_client_id(client_id) == 0 then
				log.info("reusing client %s and sending didChangeConfiguration with settings %s", client_id, vim.inspect(config.settings))

				-- update stored settings too, seems to be necessary for lua_ls at least.
				client.settings = config.settings
				client:notify("workspace/didChangeConfiguration", {settings = config.settings})

				log.info("attaching buffer %s to client %s", bufnr, config.name)
				vim.lsp.buf_attach_client(bufnr, client_id)

				return client_id
			end
		end
	end

	log.info("starting new client for client-name %s with config %s", config.name, vim.inspect(config))
	-- simulate old start_client behaviour.
	local client_id = vim.lsp.start(config, {reuse_client = util.no, attach = false})
	if not client_id then
		error("vim.lsp.start_client did not return an id!")
	end
	log.info("attaching buffer %s to client %s", bufnr, config.name)
	vim.lsp.buf_attach_client(bufnr, client_id)
	table.insert(self.client_ids, client_id)
	return client_id
end

function LspClientPool:clean_unattached()
	local i = 1
	while true do
		local client_id = self.client_ids[i]
		if client_id == nil then
			return
		end
		if #vim.lsp.get_buffers_by_client_id(client_id) == 0 then
			vim.lsp.stop_client(client_id, true)
			table.remove(self.client_ids, i)
		else
			i = i + 1
		end
	end
end

return {
	new = new,
}
