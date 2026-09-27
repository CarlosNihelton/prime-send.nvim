local M = {}

M.config = {
  cmd = "prime-agent",
  busy = "send",
}

local valid_busy_modes = {
  send = true,
  steer = true,
  ["follow-up"] = true,
}

--- Merge user options over the defaults, validate, and store them.
--- Returns the merged configuration.
---@param opts table|nil user options
---@return table config the merged configuration
function M.setup(opts)
  local config = vim.tbl_deep_extend("force", vim.deepcopy(M.config), opts or {})

  if not valid_busy_modes[config.busy] then
    error(string.format('prime-send: invalid busy mode %q, expected one of "send", "steer", "follow-up"', config.busy))
  end

  M.config = config
  return M.config
end

--- Send a message about the current entry to the pinned agent.
function M.send() end

--- Open the selector and pin the chosen agent for subsequent messages.
function M.select_agent() end

--- Open the pending queue view for an aggregated send.
function M.send_multiple() end

--- Cancel the pending queue of an aggregated send.
function M.send_multiple_cancel() end

return M
