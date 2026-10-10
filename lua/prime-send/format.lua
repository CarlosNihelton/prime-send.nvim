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

--- The fixed delivery note (ADR 1.1): identifies the message as editor input
--- and pins the reply convention, so the receiving agent answers in its own
--- session instead of attempting a reply message to the ephemeral CLI sender.
M.REPLY_NOTE = "[Sent via prime-send neovim plugin. Reply inline in your session, do not send messages.]"

--- Append the delivery note to a composed message, separated by one blank
--- line so it never reads as a comment continuation or as an aggregated
--- entry (entries always carry a reference).
---@param message string the composed message
---@return string message
function M.finalize(message)
  if message == nil or message == "" then
    return message
  end
  return message .. "\n\n" .. M.REPLY_NOTE
end

return M
