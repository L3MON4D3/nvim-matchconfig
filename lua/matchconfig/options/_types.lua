--- @class Matchconfig.Option
--- @field append_raw fun(Matchconfig.Option, table)
--- @field append fun(Matchconfig.Option, Matchconfig.Option)
--- @field make_applicator fun(Matchconfig.Option): Matchconfig.OptionApplicator
--- @field barrier fun()
--- @field copy fun(Matchconfig.Option): Matchconfig.Option

--- @class Matchconfig.OptionApplicator
--- @field apply_to_barrier fun(Matchconfig.OptionApplicator, number, table)
--- @field undo fun(Matchconfig.OptionApplicator, number)
