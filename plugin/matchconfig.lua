-- set default values.
-- true: fail silently.
require("matchconfig.session").initialize(true)

vim.api.nvim_create_autocmd({"BufEnter"}, {
	callback = function(event_args)
		-- only pass through some of the args.
		require("matchconfig.session").load_buf_config({file = event_args.file, buf = event_args.buf})
	end
})
