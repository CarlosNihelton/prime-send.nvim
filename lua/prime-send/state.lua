--- Pinned-agent state for prime-send.
local M = {}

M.identity = nil

--- The identity (session id, worker id, or session name) of the pinned agent.
---@return string|nil identity
function M.pinned()
  return M.identity
end

M.pending = {}

--- Append a composed entry to the pending queue.
---@param text string the composed entry
function M.add_entry(text)
  M.pending[#M.pending + 1] = text
end

--- The pending entries waiting for an aggregated send.
---@return string[] entries
function M.entries()
  return vim.deepcopy(M.pending)
end

--- Discard every pending entry and return the discarded count.
---@return integer count
function M.clear()
  local count = #M.pending
  M.pending = {}
  return count
end

--- Pin the agent that receives subsequent messages.
---@param identity string|nil
function M.set_pinned(identity)
  M.identity = identity
end

return M
