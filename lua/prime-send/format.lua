--- Wire-format helpers (ADR 1.1).
local M = {}

--- Combine a reference and a comment into a single wire-format line.
---@param reference string the `path:line` (or range) location
---@param comment string the user-written comment
---@return string line
function M.single_line(reference, comment)
  return reference .. " Comment: " .. comment
end

--- Join the entries of an aggregated send with a single blank line and no
--- numbering (ADR 1.1).
---@param texts string[] the composed entries
---@return string message
function M.aggregate(texts)
  return table.concat(texts, "\n\n")
end

return M
