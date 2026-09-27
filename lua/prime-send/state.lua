--- Pinned-agent state for prime-send.
local M = {}

M.identity = nil

--- The identity (session id, worker id, or session name) of the pinned agent.
---@return string|nil identity
function M.pinned()
  return M.identity
end

--- Pin the agent that receives subsequent messages.
---@param identity string|nil
function M.set_pinned(identity)
  M.identity = identity
end

return M
