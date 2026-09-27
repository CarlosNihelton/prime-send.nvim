local state = require("prime-send.state")

local M = {}

--- Parse the output of `prime-agent list --json --all` into session tables.
--- Fields are nil when the source record omits them.
---@param json_str string the raw JSON listing
---@return table[] sessions
function M.parse_list(json_str)
  local ok, data = pcall(vim.json.decode, json_str or "")
  if not ok or type(data) ~= "table" or type(data.sessions) ~= "table" then
    return {}
  end

  local sessions = {}
  for _, record in ipairs(data.sessions) do
    if type(record) == "table" then
      local session = {
        id = record.sessionId,
        worker_id = record.id,
        name = record.sessionName,
        lifecycle = record.lifecycle,
        activity = record.activity,
        is_active = record.isSessionActive,
        cwd = record.cwd,
        message_count = record.messageCount,
        modified = record.modified,
      }
      if type(record.model) == "table" then
        session.model = record.model.name or record.model.id
      end
      sessions[#sessions + 1] = session
    end
  end
  return sessions
end

--- Convert an ISO-8601 timestamp to a Unix epoch (0 when unparsable).
---@param iso string|nil
---@return number
local function iso_to_epoch(iso)
  if type(iso) ~= "string" then
    return 0
  end
  local y, mo, d, h, mi, s = iso:match("^(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d):(%d%d):(%d%d)")
  if not y then
    return 0
  end
  return os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s })
end

--- Human relative duration between now and an ISO-8601 timestamp.
---@param iso string|nil
---@return string|nil
local function relative_age(iso)
  if type(iso) ~= "string" then
    return nil
  end
  local seconds = os.time() - iso_to_epoch(iso)
  if seconds < 0 then
    seconds = 0
  end
  local units = {
    { 60, "s" },
    { 3600, "m" },
    { 86400, "h" },
    { 604800, "d" },
  }
  for i, unit in ipairs(units) do
    if seconds < unit[1] then
      local divisor = i == 1 and 1 or units[i - 1][1]
      return string.format("%d%s", math.floor(seconds / divisor), unit[2])
    end
  end
  return string.format("%dw", math.floor(seconds / 604800))
end

--- The basename of a path.
---@param path string|nil
---@return string|nil
local function basename(path)
  if type(path) ~= "string" then
    return nil
  end
  return path:match("[^/]+$") or path
end

--- One display string per session, active sessions first, then most recently
--- modified. Format: `id · name-or-dash · lifecycle · activity · summary`
--- where the summary carries the model for active sessions only.
---@param sessions table[]
---@return string[] entries
function M.selector_entries(sessions)
  local sorted = vim.deepcopy(sessions)
  table.sort(sorted, function(a, b)
    if a.is_active ~= b.is_active then
      return a.is_active
    end
    return iso_to_epoch(a.modified) > iso_to_epoch(b.modified)
  end)

  local entries = {}
  for _, session in ipairs(sorted) do
    local summary
    if session.is_active then
      summary = string.format(
        "%s · %s · %s msgs · %s",
        session.model or "-",
        basename(session.cwd) or "-",
        session.message_count or 0,
        relative_age(session.modified) or "-"
      )
    else
      summary = string.format(
        "%s · %s msgs · %s",
        basename(session.cwd) or "-",
        session.message_count or 0,
        relative_age(session.modified) or "-"
      )
    end
    entries[#entries + 1] = string.format(
      "%s · %s · %s · %s · %s",
      session.id or "-",
      session.name or "-",
      session.lifecycle or "-",
      session.activity or "-",
      summary
    )
  end
  return entries
end

--- The identity of a session: its session id when present, else the worker
--- id, else the session name.
---@param session table
---@return string|nil identity
function M.pick_identity(session)
  return session.id or session.worker_id or session.name
end

--- Spawn the configured command with `list --json --all`, parse the listing,
--- and offer the selector. On confirm the chosen session is pinned and
--- on_pick receives its identity; on cancel on_pick receives nil.
---@param on_pick fun(identity: string|nil)
function M.select_agent(on_pick)
  local config = require("prime-send").config
  local stdout = vim.uv.new_pipe(false)
  local chunks = {}
  local handle
  local exited = false
  local eof = false
  local finished = false

  --- Parse and offer the selector once the process has exited AND the
  --- stdout stream has ended, so the tail of the output is never lost.
  local function finish()
    if finished or not exited or not eof then
      return
    end
    finished = true
    stdout:read_stop()
    stdout:close()
    if handle and not handle:is_closing() then
      handle:close()
    end
    vim.schedule(function()
      local sessions = M.parse_list(table.concat(chunks))
      local entries = M.selector_entries(sessions)

      vim.ui.select(entries, { prompt = "Select an agent" }, function(choice, idx)
        if not choice then
          state.set_pinned(nil)
          if on_pick then
            on_pick(nil)
          end
          return
        end
        local identity = M.pick_identity(sessions[idx])
        state.set_pinned(identity)
        if on_pick then
          on_pick(identity)
        end
      end)
    end)
  end

  handle = vim.uv.spawn(config.cmd, {
    args = { "list", "--json", "--all" },
    stdio = { nil, stdout, nil },
  }, function()
    exited = true
    finish()
  end)

  if not handle then
    stdout:close()
    error(string.format("prime-send: failed to spawn %q", config.cmd))
  end

  stdout:read_start(function(_, data)
    if data then
      chunks[#chunks + 1] = data
    else
      eof = true
      finish()
    end
  end)
end

return M
