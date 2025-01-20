---@class Matchconfig.Eval
---@field fn fun(any): any
local Eval = {}
local Eval_mt = {__index = Eval}

local function new_eval(fn)
	return setmetatable({fn = fn}, Eval_mt)
end

function Eval:apply(args)
	return self.fn(args)
end

local function is_eval(t)
	return getmetatable(t) == Eval_mt
end

return {
	new = new_eval,
	is_eval = is_eval
}
