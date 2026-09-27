--- Wire-format helpers (ADR 1.1).
local M = {}

--- Combine a reference and a comment into a single wire-format line.
---@param reference string the `path:line` (or range) location
---@param comment string the user-written comment
---@return string line
function M.single_line(reference, comment)
  return reference .. " Comment: " .. comment
end

return M
