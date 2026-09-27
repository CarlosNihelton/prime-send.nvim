local agents = require("prime-send.agents")
local state = require("prime-send.state")

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

local format = require("prime-send.format")
local reference = require("prime-send.reference")
local sender = require("prime-send.send")

local function echo(msg)
  vim.api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
end

local function failure_matches(stderr)
  if type(stderr) ~= "string" then
    return false
  end
  return stderr:find("Unknown active session", 1, true) ~= nil
    or stderr:find("Ambiguous active session", 1, true) ~= nil
end

--- Send a message about the current buffer position to the pinned agent.
--- Prompts for the comment, ensures a pinned agent, composes the wire-format
--- message, and delivers it. A failed delivery caused by an unknown or
--- ambiguous active session reopens the selector and resends once.
function M.prime_send()
  vim.ui.input({ prompt = "Comment: " }, function(comment)
    if not comment or comment == "" then
      echo("prime-send: empty message")
      return
    end

    local message = format.single_line(reference.for_buffer(vim.api.nvim_get_current_buf()), comment)

    local function deliver(identity, retried)
      sender.send(identity, message, function(result)
        if result.code == 0 then
          return
        end
        if not failure_matches(result.stderr) or retried then
          return
        end
        agents.select_agent(function(new_identity)
          if not new_identity then
            echo("prime-send: aborted")
            return
          end
          deliver(new_identity, true)
        end)
      end)
    end

    local identity = state.pinned()
    if not identity then
      agents.select_agent(function(chosen)
        if not chosen then
          echo("prime-send: aborted")
          return
        end
        deliver(chosen, false)
      end)
      return
    end

    deliver(identity, false)
  end)
end

--- Open the selector and pin the chosen agent for subsequent messages.
function M.select_agent(on_pick)
  return agents.select_agent(on_pick)
end

--- Open the pending queue view for an aggregated send.
function M.send_multiple() end

--- Cancel the pending queue of an aggregated send.
function M.send_multiple_cancel() end

return M
