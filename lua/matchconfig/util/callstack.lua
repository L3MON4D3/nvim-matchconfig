local M = {}

function M.stack_fenv_find_vars(...)
	local varnames = {...}
	-- don't check this and caller.
	local current = 3

	-- I guess 10000 is a reasonable depth-limit.
	while current < 10000 do
		local fenv = getfenv(current)

		local var_content = {}
		local all_vars_valid = true
		for i, varname in ipairs(varnames) do
			local fenv_var = fenv[varname]
			if not fenv_var then
				all_vars_valid = false
				break
			end
			var_content[i] = fenv_var
		end

		-- I'd rather use goto :(
		if all_vars_valid then
			return unpack(var_content)
		end

		current = current + 1
	end
	error("called callstack_find_undo_buf while not in ActionContext:do_args_fn")
end

function M.stack_fenv_get_marked_level(markname)
	-- don't check this and caller.
	local current = 1

	while current < 10000 do
		local fenv = getfenv(current)
		if fenv[markname] then
			-- marked stacklevel is one lower for caller.
			return current-1
		end

		current = current + 1
	end
	error("Could not find mark " .. markname)
end

return M
