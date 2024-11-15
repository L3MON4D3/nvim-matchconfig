-- dummy-values, valid values are set in `session.initialize` during plugin/matchconfig.lua
return {
	-- all enabled options
	options = {},
	-- configs by buffer-id and buffer-name.
	buf_configs = {},
	-- config-applicators by buffer-id and buffer-name.
	buf_applicators = {},
	-- configfile (absolute path)
	configfile = "",
	-- id of autocmd watching configfile
	configfile_watcher_id = 0,
	-- all known matchconfigs, loaded from configfile.
	matchconfigs = {},
}
