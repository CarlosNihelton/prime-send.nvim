--- Delivery of composed messages through the configured command.
local M = {}

--- Spawn the configured command to deliver a message to an agent.
--- Refuses to spawn on an empty message. Reports the exit code with the
--- captured stdout and stderr to on_result as
--- `{ code = integer, stdout = string, stderr = string }`, or
--- `{ error = string }` when nothing was spawned.
---@param identity string the target agent identity
---@param message string the composed message
---@param on_result fun(result: table)
function M.send(identity, message, on_result)
  if message == nil or message == "" then
    if on_result then
      on_result({ error = "prime-send: empty message" })
    end
    return
  end

  local config = require("prime-send").config
  local args = { "send", identity }
  if config.busy and config.busy ~= "send" then
    args[#args + 1] = "--" .. config.busy
  end
  args[#args + 1] = "--message"
  args[#args + 1] = message

  local stdout = vim.uv.new_pipe(false)
  local stderr = vim.uv.new_pipe(false)
  local out_chunks, err_chunks = {}, {}

  local result = { code = 0, stdout = "", stderr = "" }
  local pending = 3 -- exit + two pipes

  local function maybe_finish()
    if pending > 0 then
      return
    end
    result.stdout = table.concat(out_chunks)
    result.stderr = table.concat(err_chunks)
    stdout:close()
    stderr:close()
    vim.schedule(function()
      if on_result then
        on_result(result)
      end
    end)
  end

  local handle = vim.uv.spawn(config.cmd, {
    args = args,
    stdio = { nil, stdout, stderr },
  }, function(exit_code)
    result.code = exit_code
    pending = pending - 1
    maybe_finish()
  end)

  if not handle then
    pending = -1 -- never finish from the callbacks
    stdout:close()
    stderr:close()
    if on_result then
      on_result({ error = string.format("prime-send: failed to spawn %q", config.cmd) })
    end
  end

  stdout:read_start(function(_, data)
    if data then
      out_chunks[#out_chunks + 1] = data
    else
      pending = pending - 1
      maybe_finish()
    end
  end)
  stderr:read_start(function(_, data)
    if data then
      err_chunks[#err_chunks + 1] = data
    else
      pending = pending - 1
      maybe_finish()
    end
  end)
end

return M
