-- set default values.
-- true: fail silently.
require("matchconfig.session").initialize(true)

vim.api.nvim_create_autocmd({"BufEnter"}, {
	-- to run under all circumstances I guess?
	callback = require("matchconfig.session").load_buf_config
})
