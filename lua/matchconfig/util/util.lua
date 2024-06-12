local M = {}

-- for read-only empty tables, so we don't allocate a bunch of them.
M.empty = {}
M.nop = function() end

return M
