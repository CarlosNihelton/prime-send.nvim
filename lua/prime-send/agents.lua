local selector = require("prime-send.selector")
local state = require("prime-send.state")

local M = {}

local function echo(msg)
  vim.api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
end

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
--- Naive timestamps are UTC. Conversion uses calendar arithmetic so it does
--- not depend on the process timezone or the host's timezone cache.
---@param iso string|nil
---@return number
local function iso_to_epoch(iso)
  if type(iso) ~= "string" then
    return 0
  end

  local y, mo, d, h, mi, s, suffix = iso:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)(.*)$")
  if not y then
    return 0
  end

  y, mo, d, h, mi, s = tonumber(y), tonumber(mo), tonumber(d), tonumber(h), tonumber(mi), tonumber(s)
  local days_in_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  local leap_year = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
  if leap_year then
    days_in_month[2] = 29
  end
  if mo < 1 or mo > 12 or d < 1 or d > days_in_month[mo] or h > 23 or mi > 59 or s > 59 then
    return 0
  end

  local offset = 0
  local remainder = suffix:match("^%.%d+(.*)$")
  if remainder then
    suffix = remainder
  end
  if suffix ~= "" and suffix ~= "Z" and suffix ~= "z" then
    local sign, offset_hours, offset_minutes = suffix:match("^([+-])(%d%d):?(%d%d)$")
    if not sign then
      return 0
    end
    offset_hours, offset_minutes = tonumber(offset_hours), tonumber(offset_minutes)
    if offset_hours > 23 or offset_minutes > 59 then
      return 0
    end
    offset = (offset_hours * 60 + offset_minutes) * 60
    if sign == "-" then
      offset = -offset
    end
  end

  -- Days since 1970-01-01 in the proleptic Gregorian calendar.
  local adjusted_year = y - (mo <= 2 and 1 or 0)
  local era = math.floor(adjusted_year / 400)
  local year_of_era = adjusted_year - era * 400
  local adjusted_month = mo + (mo > 2 and -3 or 9)
  local day_of_year = math.floor((153 * adjusted_month + 2) / 5) + d - 1
  local day_of_era = year_of_era * 365 + math.floor(year_of_era / 4) - math.floor(year_of_era / 100) + day_of_year
  local days = era * 146097 + day_of_era - 719468
  return days * 86400 + h * 3600 + mi * 60 + s - offset
end

M.iso_to_epoch = iso_to_epoch

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

M.relative_age = relative_age

--- The sessions ordered for display: active sessions first, then most
--- recently modified.
---@param sessions table[]
---@return table[] sorted
function M.sorted_sessions(sessions)
  local sorted = vim.deepcopy(sessions)
  table.sort(sorted, function(a, b)
    if a.is_active ~= b.is_active then
      return a.is_active
    end
    return iso_to_epoch(a.modified) > iso_to_epoch(b.modified)
  end)
  return sorted
end

--- Pad a field with spaces to a display width so columns align.
---@param text string
---@param width integer
---@return string
local function pad(text, width)
  local w = vim.fn.strdisplaywidth(text)
  if w >= width then
    return text
  end
  return text .. string.rep(" ", width - w)
end

--- One display string per session, active sessions first, then most recently
--- modified. Every field is padded to the widest value across entries so the
--- columns align: `name · lifecycle · activity · model · cwd · msgs · age ·
--- id`, where the model column stays empty for saved sessions and the id
--- sits far right.
---@param sessions table[]
---@return string[] entries
function M.selector_entries(sessions)
  local sorted = M.sorted_sessions(sessions)

  local name_w, lifecycle_w, activity_w, model_w, cwd_w, msgs_w, age_w = 1, 1, 1, 1, 1, 1, 1
  for _, session in ipairs(sorted) do
    name_w = math.max(name_w, vim.fn.strdisplaywidth(session.name or "-"))
    lifecycle_w = math.max(lifecycle_w, vim.fn.strdisplaywidth(session.lifecycle or "-"))
    activity_w = math.max(activity_w, vim.fn.strdisplaywidth(session.activity or "-"))
    if session.is_active then
      model_w = math.max(model_w, vim.fn.strdisplaywidth(session.model or "-"))
    end
    cwd_w = math.max(cwd_w, vim.fn.strdisplaywidth(basename(session.cwd) or "-"))
    msgs_w = math.max(msgs_w, vim.fn.strdisplaywidth(tostring(session.message_count or 0) .. " msgs"))
    age_w = math.max(age_w, vim.fn.strdisplaywidth(relative_age(session.modified) or "-"))
  end

  local entries = {}
  for _, session in ipairs(sorted) do
    local fields = {
      pad(session.name or "-", name_w),
      pad(session.lifecycle or "-", lifecycle_w),
      pad(session.activity or "-", activity_w),
    }
    if session.is_active then
      fields[#fields + 1] = pad(session.model or "-", model_w)
    else
      fields[#fields + 1] = pad("", model_w)
    end
    fields[#fields + 1] = pad(basename(session.cwd) or "-", cwd_w)
    fields[#fields + 1] = pad(tostring(session.message_count or 0) .. " msgs", msgs_w)
    fields[#fields + 1] = pad(relative_age(session.modified) or "-", age_w)
    fields[#fields + 1] = session.id or "-"
    entries[#entries + 1] = table.concat(fields, " · ")
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
--- and offer the floating selector. On confirm the chosen session is pinned
--- and on_pick receives its identity; on cancel on_pick receives nil. A
--- command that cannot be spawned or a listing that yields no sessions
--- echoes a warning instead, and on_pick is never called.
---@param on_pick fun(identity: string|nil)
function M.select_agent(on_pick)
  local config = require("prime-send").config
  local stdout = vim.uv.new_pipe(false)
  local stderr = vim.uv.new_pipe(false)
  local out_chunks, err_chunks = {}, {}
  local handle
  local exit_code = 0
  local pending = 3 -- process exit + two pipe end-of-streams
  local finished = false

  --- Parse and offer the selector once the process has exited AND both
  --- stdout and stderr have ended, so the tail of the output is never lost.
  local function finish()
    if finished or pending > 0 then
      return
    end
    finished = true
    stdout:read_stop()
    stderr:read_stop()
    stdout:close()
    stderr:close()
    if handle and not handle:is_closing() then
      handle:close()
    end
    vim.schedule(function()
      local sessions = M.parse_list(table.concat(out_chunks))
      local sorted = M.sorted_sessions(sessions)
      local entries = M.selector_entries(sessions)
      if #entries == 0 then
        if exit_code ~= 0 then
          local detail = vim.trim(table.concat(err_chunks))
          if detail == "" then
            detail = "no output"
          end
          echo(string.format("prime-send: prime-agent list failed: %s", detail))
        else
          echo("prime-send: no agents found")
        end
        return
      end

      selector.open(entries, function(choice)
        if not choice then
          state.set_pinned(nil)
          if on_pick then
            on_pick(nil)
          end
          return
        end
        local identity = M.pick_identity(sorted[choice])
        state.set_pinned(identity)
        if on_pick then
          on_pick(identity)
        end
      end)
    end)
  end

  handle = vim.uv.spawn(config.cmd, {
    args = { "list", "--json", "--all" },
    stdio = { nil, stdout, stderr },
  }, function(code)
    exit_code = code
    pending = pending - 1
    finish()
  end)

  if not handle then
    finished = true
    stdout:close()
    stderr:close()
    echo(string.format("prime-send: failed to spawn %q", config.cmd))
    return
  end

  stdout:read_start(function(_, data)
    if data then
      out_chunks[#out_chunks + 1] = data
    else
      pending = pending - 1
      finish()
    end
  end)
  stderr:read_start(function(_, data)
    if data then
      err_chunks[#err_chunks + 1] = data
    else
      pending = pending - 1
      finish()
    end
  end)
end

return M
