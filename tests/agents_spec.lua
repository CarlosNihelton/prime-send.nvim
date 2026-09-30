local tests_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local agents = require("prime-send.agents")
local selector = require("prime-send.selector")
local state = require("prime-send.state")
local prime_send = require("prime-send")

local function fixture()
  return table.concat(vim.fn.readfile(tests_dir .. "/golden/list.json"), "\n")
end

describe("prime-send.agents.parse_list", function()
  it("maps the golden listing nil-safely", function()
    local sessions = agents.parse_list(fixture())
    assert.are.equal(3, #sessions)

    local active = sessions[1]
    assert.are.equal("11111111-2222-3333-4444-555555555555", active.id)
    assert.are.equal("abcd1234ef01", active.worker_id)
    assert.is_nil(active.name)
    assert.are.equal("live", active.lifecycle)
    assert.are.equal("working", active.activity)
    assert.is_true(active.is_active)
    assert.are.equal("Z.ai: GLM 5.3", active.model)
    assert.are.equal("/home/user/project", active.cwd)
    assert.are.equal(42, active.message_count)

    local named = sessions[2]
    assert.are.equal("my-session", named.name)
    assert.are.equal("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", named.id)
    assert.is_false(named.is_active)

    local archived = sessions[3]
    assert.are.equal("cccccccc-dddd-eeee-ffff-000000000000", archived.id)
    assert.is_nil(archived.name)
    assert.is_nil(archived.model)
    assert.are.equal("archived", archived.lifecycle)
  end)

  it("returns an empty list for malformed input", function()
    assert.are.same({}, agents.parse_list("not json"))
  end)
end)

describe("prime-send.agents.selector_entries", function()
  it("lists the active session before both saved sessions", function()
    local sessions = agents.parse_list(fixture())
    local entries = agents.selector_entries(sessions)
    assert.are.equal(3, #entries)
    assert.truthy(entries[1]:find("11111111%-2222%-3333%-4444%-555555555555"))
    assert.truthy(entries[2]:find("my%-session"))
    assert.truthy(entries[3]:find("cccccccc%-dddd%-eeee%-ffff%-000000000000"))
    -- summary shape for the active session: model, cwd basename, msg count
    assert.truthy(entries[1]:find("Z%.ai: GLM 5%.3"))
    assert.truthy(entries[1]:find("project · 42 msgs"))
    -- summary shape for a saved session: no model, cwd basename, msg count
    assert.truthy(entries[2]:find("other · 7 msgs"))
    assert.is_nil(entries[2]:find("GLM"))
    -- dash placeholder when the session has no name
    assert.truthy(entries[1]:find(" · %- · live · "))
  end)

  it("sorts saved sessions by most recently modified", function()
    local sessions = agents.parse_list(fixture())
    local entries = agents.selector_entries(sessions)
    assert.truthy(entries[2]:find("my%-session"))
    assert.truthy(entries[3]:find("cccccccc%-dddd%-eeee%-ffff%-000000000000"))
  end)
end)

describe("prime-send.agents.iso_to_epoch", function()
  it("maps 1970-01-01T00:00:00 to exactly 0", function()
    assert.are.equal(0, agents.iso_to_epoch("1970-01-01T00:00:00.000Z"))
  end)

  it("applies an explicit ISO-8601 UTC offset", function()
    assert.are.equal(0, agents.iso_to_epoch("1970-01-01T05:30:00+05:30"))
  end)

  it("maps 1970-01-01T00:00:00 to 0 under a non-UTC timezone", function()
    local saved_tz = os.getenv("TZ")
    vim.env.TZ = "Asia/Kolkata"
    local ok, epoch = pcall(agents.iso_to_epoch, "1970-01-01T00:00:00.000Z")
    vim.env.TZ = saved_tz
    if not ok then
      error(epoch)
    end
    assert.are.equal(0, epoch)
  end)
end)

describe("prime-send.agents.relative_age", function()
  it("returns 1m for a UTC timestamp exactly 90 seconds before now", function()
    local iso = os.date("!%Y-%m-%dT%H:%M:%S", os.time() - 90)
    assert.are.equal("1m", agents.relative_age(iso))
  end)
end)

describe("prime-send.agents.pick_identity", function()
  it("falls back session id, then worker id, then name", function()
    assert.are.equal("sid", agents.pick_identity({ id = "sid", worker_id = "wid", name = "nm" }))
    assert.are.equal("wid", agents.pick_identity({ worker_id = "wid", name = "nm" }))
    assert.are.equal("nm", agents.pick_identity({ name = "nm" }))
  end)
end)

describe("prime-send.agents.select_agent", function()
  local chosen_identity
  local offered_entries

  local function stub_selector(choice)
    local saved = selector.open
    selector.open = function(entries, on_choice)
      offered_entries = entries
      on_choice(choice)
    end
    return function()
      selector.open = saved
    end
  end

  before_each(function()
    state.set_pinned(nil)
    chosen_identity = "unset"
    offered_entries = nil
    prime_send.setup({ cmd = tests_dir .. "/fake-prime-agent" })
  end)

  after_each(function()
    state.set_pinned(nil)
  end)

  it("pins the chosen session and calls on_pick with its identity", function()
    local sessions = agents.parse_list(fixture())
    local expected_id = sessions[2].id

    local restore = stub_selector(2)
    agents.select_agent(function(identity)
      chosen_identity = identity
    end)

    vim.wait(3000, function()
      return chosen_identity ~= "unset"
    end, 10)
    restore()

    assert.are.equal(expected_id, state.pinned())
    assert.are.equal(expected_id, chosen_identity)
  end)

  it(
    "pins the session displayed at the chosen line when the raw listing order differs from the display order",
    function()
      local raw_sessions = {
        {
          id = "saved-old",
          is_active = false,
          modified = "2026-09-01T00:00:00.000Z",
          message_count = 1,
          cwd = "/w/one",
        },
        {
          id = "active-one",
          is_active = true,
          modified = "2026-09-27T00:00:00.000Z",
          message_count = 2,
          cwd = "/w/two",
        },
        {
          id = "saved-new",
          is_active = false,
          modified = "2026-09-26T00:00:00.000Z",
          message_count = 3,
          cwd = "/w/three",
        },
      }
      local saved_parse = agents.parse_list
      agents.parse_list = function()
        return raw_sessions
      end

      local restore = stub_selector(1)
      agents.select_agent(function(identity)
        chosen_identity = identity
      end)

      vim.wait(3000, function()
        return chosen_identity ~= "unset"
      end, 10)
      restore()
      agents.parse_list = saved_parse

      -- The displayed first line is the active session, and choosing it pins
      -- that session, not the first one of the raw listing.
      assert.truthy(offered_entries[1]:find("active%-one"))
      assert.are.equal("active-one", state.pinned())
      assert.are.equal("active-one", chosen_identity)
    end
  )

  it("offers all 300 sessions of the large golden listing", function()
    local restore = stub_selector(1)

    vim.env.PRIME_SEND_TEST_LISTING = "large"
    agents.select_agent(function(id)
      chosen_identity = id
    end)
    vim.wait(5000, function()
      return offered_entries ~= nil
    end, 10)
    vim.env.PRIME_SEND_TEST_LISTING = nil
    restore()

    assert.are.equal(300, #offered_entries)
    -- The active session is offered first and carries its session id.
    assert.truthy(offered_entries[1]:find("session%-000"))
    local large = agents.parse_list(table.concat(vim.fn.readfile(tests_dir .. "/golden/list-large.json"), "\n"))
    assert.are.equal(large[1].id, chosen_identity)
    assert.are.equal(chosen_identity, state.pinned())
  end)

  it("opens the selector only after the process exited and stdout ended", function()
    local opened_at
    local saved_open = selector.open
    selector.open = function(entries, on_choice)
      opened_at = vim.uv.hrtime()
      assert.are.equal(3, #entries)
      on_choice(1)
    end

    vim.env.PRIME_SEND_TEST_LISTING = "slow"
    local start = vim.uv.hrtime()
    agents.select_agent(function(id)
      chosen_identity = id
    end)
    vim.wait(5000, function()
      return opened_at ~= nil
    end, 10)
    vim.env.PRIME_SEND_TEST_LISTING = nil
    selector.open = saved_open

    assert.truthy(opened_at)
    assert.truthy((opened_at - start) / 1e9 >= 0.25, "selector opened before the listing process finished")
    assert.are.equal(agents.parse_list(fixture())[1].id, chosen_identity)
  end)

  it("calls on_pick with nil when the selector is cancelled", function()
    local restore = stub_selector(nil)
    local called, cancelled = false, "unset"

    agents.select_agent(function(identity)
      called = true
      cancelled = identity
    end)

    vim.wait(3000, function()
      return called
    end, 10)
    restore()

    assert.is_true(called)
    assert.is_nil(cancelled)
    assert.is_nil(state.pinned())
  end)

  it("echoes no agents found when the listing yields no sessions", function()
    local echoed
    local saved_echo = vim.api.nvim_echo
    vim.api.nvim_echo = function(chunks, _hist, _opts)
      echoed = echoed or chunks[1][1]
    end

    vim.env.PRIME_SEND_TEST_LISTING = "broken"
    agents.select_agent(function(identity)
      chosen_identity = identity
    end)
    vim.wait(3000, function()
      return echoed ~= nil
    end, 10)
    vim.env.PRIME_SEND_TEST_LISTING = nil
    vim.api.nvim_echo = saved_echo

    assert.are.equal("prime-send: no agents found", echoed)
    assert.are.equal("unset", chosen_identity)
  end)

  it("echoes instead of raising when the command cannot be spawned", function()
    prime_send.setup({ cmd = "definitely-missing-binary-xyz" })
    local echoed
    local saved_echo = vim.api.nvim_echo
    vim.api.nvim_echo = function(chunks, _hist, _opts)
      echoed = echoed or chunks[1][1]
    end

    agents.select_agent(function(identity)
      chosen_identity = identity
    end)
    vim.wait(2000, function()
      return echoed ~= nil
    end, 10)
    vim.api.nvim_echo = saved_echo

    assert.truthy(echoed:find("failed to spawn", 1, true))
    assert.are.equal("unset", chosen_identity)
  end)
end)
