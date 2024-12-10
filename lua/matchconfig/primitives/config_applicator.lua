--- @class Matchconfig.ConfigApplicator
--- @field option_applicators Matchconfig.OptionApplicator[]
--- @field n_barriers number How many barriers do the options have at most.
local ConfigApplicator = {}
local ConfigApplicator_mt = {
	__index = ConfigApplicator,
}

function ConfigApplicator.new(option_applicators, n_barriers)
	return setmetatable({
		option_applicators = option_applicators,
		n_barriers = n_barriers
	}, ConfigApplicator_mt)
end
function ConfigApplicator:apply(args)
	for i = 1, self.n_barriers do
		for _, applicator in ipairs(self.option_applicators) do
			applicator:apply_to_barrier(i, args)
		end
	end
end

function ConfigApplicator:undo(bufnr)
	for _, applicator in ipairs(self.option_applicators) do
		applicator:undo(bufnr)
	end
end

return {
	new = ConfigApplicator.new,
}
