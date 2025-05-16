local log = require("matchconfig.util.log").new("lsp-pool")
local util = require("matchconfig.util.util")
local fs = require("matchconfig.util.fs")

-- taken from neovim runtime.
local function lookup_section(table, section)
	local keys = vim.split(section, '.', { plain = true }) --- @type string[]
	return vim.tbl_get(table, unpack(keys))
end

---@class Matchconfig.LspClientExt
---Wraps neovims LspClient, and adds a layer for handling per-workspace
---configs.
---@field client_id integer `client_id` in neovim.
---@field settings_by_root_dir table<string, table> Maps a
---`workspace_name` with at least one attached buffer to the settings to use.
---@field buf_to_workspace table<integer, string> Map attached bufnrs to workspace name.
---@field n_workspace_bufs table<string, integer> Number of bufs attached to a workspace.
---Once this drops to 0, we have to remove the workspace from the LspClient.
---May contain workspaces with n=0.
---
---@field enable_per_workspace_config boolean
---@field cmd string[] cmd of languageserver
---@field name string name of languageserver
---@field initial_root_dir string
local LspClientExt = {}
local LspClientExt_mt = {__index = LspClientExt}

local fallback_root_dir = "_fallback_"
function LspClientExt.start(bufnr, config)
	-- normalization
	local root_dir = config.root_dir and fs.normalize_dir(config.root_dir) or fallback_root_dir
	config.settings = config.settings or {}

	-- override all custom handlers, let's say we don't support them for now.
	if config.handlers then
		log.warn(
			"custom handler detected in config %s, they are not supported for now and will be overwritten.",
			vim.inspect(config))
	end


	-- declare new LspClientExt early so we can capture it in the
	-- workspace/configuration handler.

	---@as Matchconfig.LspClientExt
	local o = {}

	config.handlers = {
		-- adapted from neovim runtime.
		["workspace/configuration"] = function(_, params)
			if not params.items then
				return {}
			end

			local response = {}
			for _, item in pairs(params.items) do
				if item.section then
					-- fall back to initial root_dir if it is nil.
					-- This works for at least lua-language-server.
					local scope = item.scopeUri and vim.uri_to_fname(item.scopeUri) or root_dir
					local settings = o.settings_by_root_dir[scope]

					if not settings then
						log.error("%s: server requests config for scope \"%s\", but settings do not exist in %s", o:identify(), scope, vim.inspect(o.settings_by_root_dir))
						settings = {}
					end
					local value = lookup_section(settings, item.section)
					if value == nil and item.section == "" then
						value = settings
					end
					if value == nil then
						value = vim.NIL
					end
					table.insert(response, value)
				end
			end
			log.debug("%s: returning %s for request %s.", o:identify(), vim.inspect(response), vim.inspect(params))
			return response
		end
	}

	log.info("starting new client for client-name %s with settings %s", config.name, vim.inspect(config.settings))
	-- simulate old start_client behaviour (ie. never reuse, don't yet attach).
	local client_id = vim.lsp.start(config, {reuse_client = util.no, attach = false})
	if not client_id then
		log.error("vim.lsp.start did not return a client_id with config %s", client_id, vim.inspect(config))
		return nil
	end

	log.info("attaching buffer %s to client %s", bufnr, config.name)
	vim.lsp.buf_attach_client(bufnr, client_id)

	o.client_id = client_id
	o.settings_by_root_dir = {
		[root_dir] = config.settings
	}
	o.buf_to_workspace = {
		[bufnr] = root_dir
	}
	o.n_workspace_bufs = {
		[root_dir] = 1
	}
	o.enable_per_workspace_config = config.enable_per_workspace_config
	o.cmd = config.cmd
	o.name = config.name
	o.initial_root_dir = root_dir

	setmetatable(o, LspClientExt_mt)

	return o
end

---@private
function LspClientExt:add_workspace(root_dir, settings)
	self.settings_by_root_dir[root_dir] = settings

	-- this may be called when a server wtih enable_per_workspace_config is
	-- reused.
	-- Since the server always has the initial_root_dir active, we don't add it
	-- specially here.
	if root_dir ~= self.initial_root_dir then
		self:client():_add_workspace_folder(root_dir)
	end
end

---@private
function LspClientExt:set_workspace_settings(root_dir, settings)
	self.settings_by_root_dir[root_dir] = settings
	-- TODO: check how servers use the settings passed here.
	-- I think they should be ignored/replaced with the settings the server
	-- retrieves via the pull that is initiated by this.
	self:client():notify("workspace/didChangeConfiguration", {settings = settings})
end

---Add some buffer to a workspace
---@param root_dir string Workspace-root.
---@param bufnr integer
function LspClientExt:workspace_add_buf(root_dir, bufnr)
	self.buf_to_workspace[bufnr] = root_dir

	local current = self.n_workspace_bufs[root_dir]
	self.n_workspace_bufs[root_dir] = current and (current + 1) or 1

	vim.lsp.buf_attach_client(bufnr, self.client_id)
end

function LspClientExt:client()
	local client = vim.lsp.get_client_by_id(self.client_id)
	-- client exists as long as clientExt exists.
	---@cast client -nil
	return client
end

function LspClientExt:identify()
	return self.client_id .. "[" .. self.name .. "]"
end

---Try to attach the buffer `bufnr` with config `config` to this lsp-client.
---@param bufnr number
---@param config table
function LspClientExt:try_reuse(bufnr, config)
	local root_dir = config.root_dir or fallback_root_dir

	if
		not vim.deep_equal(self.cmd, config.cmd) or
		not self.name == config.name or
		not self.enable_per_workspace_config == config.enable_per_workspace_config then

		-- todo: look into what other options may make servers incompatible.
		log.debug(
			"skipping client %s, incompatible non-setting config. Has: %s, wants: %s.",
			self:identify(),
			vim.inspect({
				cmd = self.cmd,
				name = self.name,
				enable_per_workspace_config = self.enable_per_workspace_config
			}),
			vim.inspect({
				cmd = config.cmd,
				name = config.name,
				enable_per_workspace_config = config.enable_per_workspace_config
			})
		)
		return false
	end

	local current_workspace_settings = self.settings_by_root_dir[root_dir]

	if current_workspace_settings then
		if vim.deep_equal(current_workspace_settings, config.settings) then
			log.info("attaching buffer %s to client %s workspace \"%s\"", bufnr, self:identify(), root_dir)
			-- all good, just attach to workspace.
			self:workspace_add_buf(root_dir, bufnr)
			return true
		else
			log.debug(
				"skipping client %s because current workspace settings %s and desired settings %s do not match.",
				self:identify(),
				vim.inspect(current_workspace_settings),
				vim.inspect(config.settings))

			-- workspace exists and has settings different from what we want =>
			-- cannot use this client.
			return false
		end
	else
		-- workspace does not currently exist.
		if not self.enable_per_workspace_config then
			-- in this case, we can upload the config only if `initial_root_dir`
			-- matches.
			-- We may land in this case if the client is reused.
			if self.initial_root_dir == root_dir then
				log.info(
					"attaching buffer %s to client %s, currently unused workspace \"%s\"",
					bufnr,
					self:identify(),
					root_dir)
				self:set_workspace_settings(root_dir, config.settings)
				self:workspace_add_buf(root_dir, bufnr)
				return true
			else
				-- Seems like servers that do not support workspaces properly
				-- only receive the rootDir on initialization => cannot change
				-- it => cannot use this server.
				log.debug(
					"skipping client %s, it has root_dir \"%s\" vs desired root_dir \"%s\"",
					self:identify(),
					self.initial_root_dir,
					root_dir)
				return false
			end
		else
			-- workspace does not exist => add it and attach the buffer.
			self:add_workspace(root_dir, config.settings)
			self:workspace_add_buf(root_dir, bufnr)
			return true
		end
	end
end

function LspClientExt:remove_workspace(root_dir)
	self.settings_by_root_dir[root_dir] = nil
	-- initial_root_dir is not added as a workspace_folder, so don't invoke the
	-- nvim api for that.
	if self.enable_per_workspace_config and root_dir ~= self.initial_root_dir then
		self:client():_remove_workspace_folder(root_dir)
	end
end

function LspClientExt:detach_buf(bufnr)
	local root_dir = self.buf_to_workspace[bufnr]
	self.buf_to_workspace[bufnr] = nil

	self.n_workspace_bufs[root_dir] = self.n_workspace_bufs[root_dir] - 1

	if self.n_workspace_bufs[root_dir] == 0 then
		self:remove_workspace(root_dir)
	end

	vim.lsp.buf_detach_client(bufnr, self.client_id)
end

function LspClientExt:stop()
	vim.lsp.stop_client(self.client_id, true)
end

function LspClientExt:has_attached_buffers()
	return next(self.buf_to_workspace) ~= nil
end

function LspClientExt:restore_connection(bufnr)
	vim.lsp.buf_attach_client(bufnr, self.client_id)
end

--- @class Matchconfig.LspClientPool
--- @field clients Matchconfig.LspClientExt all known clients.
--- @field attach_matching fun(client_pool, bufnr, lsp_spec): integer attach buffer bufnr to a
--- lsp-client matching the given lsp-spec. May also start a new lsp-client.
--- @field clean_unattached fun(client_pool) Remove clients that are not attached to any buffer.
local LspClientPool = {}
local LspClientPool_mt = {__index = LspClientPool}

local function new()
	return setmetatable({
		clients = {},
	}, LspClientPool_mt)
end


---Find an existing lsp-client to attach to, or, if none match, initialise a
---new server.
---@param bufnr integer
---@param config table
---@return Matchconfig.LspClientExt?
function LspClientPool:attach_matching(bufnr, config)
	for _, ext_client in ipairs(self.clients) do
		if ext_client:try_reuse(bufnr, config) then
			return ext_client
		end
	end

	local client_ext = LspClientExt.start(bufnr, config)
	if not client_ext then
		return nil
	end
	table.insert(self.clients, client_ext)

	return client_ext
end

function LspClientPool:clean_unattached()
	local valid_clients = {}
	for _, client in ipairs(self.clients) do
		if client:has_attached_buffers() then
			table.insert(valid_clients, client)
		else
			client:stop()
		end
	end
	self.clients = valid_clients
end

return {
	new = new,
}
