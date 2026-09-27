--- Wire-format helpers (ADR 1.1).
local M = {}

--- Combine a reference and a comment into a single wire-format line.
---@param reference string the `path:line` (or range) location
---@param comment string the user-written comment
---@return string line
function M.single_line(reference, comment)
  return reference .. " Comment: " .. comment
end

--- Combine a reference and a multi-line comment body into the wire format:
--- the first line is the reference plus ` Comment:` alone, and the body
--- follows verbatim.
---@param reference string the `path:line` (or range) location
---@param body string[] the comment lines
---@return string message
function M.multi_line(reference, body)
  local lines = { reference .. " Comment:" }
  for _, line in ipairs(body) do
    lines[#lines + 1] = line
  end
  return table.concat(lines, "\n")
end

return M
