return {
	-- override in setup, would love to set as nil, but lua-languageserver
	-- complains then when used, {} it is :(
	options = {},
	-- set as autotable, but {} suffices for correct diagnostics.
	buf_configs = {},
	global_config_fname = "",
	global_config = {}
}
