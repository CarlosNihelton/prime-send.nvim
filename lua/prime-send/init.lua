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
local scratch = require("prime-send.scratch")
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

--- Deliver a composed message through the pinning and send path: ensure a
--- pinned agent, deliver, and on an unknown or ambiguous active session
--- failure reopen the selector and resend once.
---@param message string
---@param on_delivered nil|fun()
local function deliver_pinned(message, on_delivered)
  local function deliver(identity, retried)
    sender.send(identity, message, function(result)
      if result.code == 0 then
        if on_delivered then
          on_delivered()
        end
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
end

--- The shared capture flow: prompt for the comment, opening the scratch
--- buffer on empty input, and hand the composed entry to on_entry.
---@param on_entry fun(message: string|nil)
local function capture(on_entry)
  vim.ui.input({ prompt = "Comment: " }, function(comment)
    if not comment then
      on_entry(nil)
      return
    end

    if comment == "" then
      local ref = reference.for_buffer(vim.api.nvim_get_current_buf())
      scratch.open(ref, on_entry)
      return
    end

    on_entry(format.single_line(reference.for_buffer(vim.api.nvim_get_current_buf()), comment))
  end)
end

--- Send a message about the current buffer position to the pinned agent.
--- Prompts for the comment, ensures a pinned agent, composes the wire-format
--- message, and delivers it. An empty comment opens the scratch buffer for
--- extended input instead. A failed delivery caused by an unknown or
--- ambiguous active session reopens the selector and resends once.
function M.prime_send()
  capture(function(message)
    if not message then
      return
    end
    deliver_pinned(message)
  end)
end

--- The aggregated send flow. Without a bang, run the same capture flow as
--- prime_send but append the composed entry to the pending queue instead of
--- delivering. With a bang, deliver every pending entry as one message
--- composed by aggregate and clear the queue.
---@param opts nil|table { bang = boolean }
function M.send_multiple(opts)
  if opts and opts.bang then
    local entries = state.entries()
    if #entries == 0 then
      echo("prime-send: nothing pending")
      return
    end
    deliver_pinned(format.aggregate(entries), function()
      state.clear()
    end)
    return
  end

  capture(function(message)
    if not message then
      return
    end
    state.add_entry(message)
    echo(string.format("prime-send: %d pending", #state.entries()))
  end)
end

--- Clear the pending queue and echo the discarded count.
function M.send_multiple_cancel()
  echo(string.format("prime-send: discarded %d", state.clear()))
end

--- Open the selector and pin the chosen agent for subsequent messages.
function M.select_agent(on_pick)
  return agents.select_agent(on_pick)
end

return M
