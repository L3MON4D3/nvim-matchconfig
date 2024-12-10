--- @class Matchconfig.Option
--- @field append_raw fun(Matchconfig.Option, table)
--- @field append fun(Matchconfig.Option, Matchconfig.Option)
--- @field make_applicator fun(Matchconfig.Option, any): Matchconfig.OptionApplicator
--- @field barrier fun()
--- @field copy fun(Matchconfig.Option): Matchconfig.Option

--- @class Matchconfig.OptionApplicator
--- @field apply_to_barrier fun(Matchconfig.OptionApplicator, number, table, any)
--- @field undo fun(Matchconfig.OptionApplicator, number)

--- @class Matchconfig.BufInfo
--- @field bufnr number
--- @field fname string
--- @field filetypes table<string, boolean>
--- @field dir string

--- @class Matchconfig.Matcher
--- @field matches fun(Matchconfig.BufInfo): boolean Whether the matcher matches some buffer represented by BufInfo.
--- @field human_readable fun(boolean): string human-readable id of the matcher. Does not have to be unique
--- @field tags fun(): string[] tags that are associated with this matcher-instance. Usually also related to the class of this instance.
