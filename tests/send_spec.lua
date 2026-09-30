local tests_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local send = require("prime-send.send")
local prime_send_module = require("prime-send")
local selector = require("prime-send.selector")
local state = require("prime-send.state")

local function result_of(fn)
  local result = "unset"
  fn(function(r)
    result = r
  end)
  vim.wait(3000, function()
    return result ~= "unset"
  end, 10)
  return result
end

describe("prime-send.send", function()
  before_each(function()
    prime_send_module.setup({ cmd = tests_dir .. "/fake-prime-agent" })
    state.set_pinned(nil)
    os.remove(tests_dir .. "/fail-once")
  end)

  after_each(function()
    os.remove(tests_dir .. "/fail-once")
  end)

  it("delivers the argv as NUL-separated elements to on_result", function()
    local result = result_of(function(on_result)
      send.send("sess-1", "fix this", on_result)
    end)
    assert.are.equal(0, result.code)
    local argv = vim.split(result.stdout, "\0", { plain = true })
    assert.are.equal("send", argv[1])
    assert.are.equal("sess-1", argv[2])
    assert.are.equal("--message", argv[3])
    assert.are.equal("fix this", argv[4])
  end)

  it("refuses to spawn on an empty message", function()
    local result = "unset"
    send.send("sess-1", "", function(r)
      result = r
    end)
    assert.not_equal("unset", result)
    assert.truthy(result.error)
    assert.is_nil(result.code)
  end)

  it("places --steer between the identity and --message when busy is steer", function()
    prime_send_module.setup({ cmd = tests_dir .. "/fake-prime-agent", busy = "steer" })
    local result = result_of(function(on_result)
      send.send("sess-1", "fix this", on_result)
    end)
    local argv = vim.split(result.stdout, "\0", { plain = true })
    assert.are.equal("sess-1", argv[2])
    assert.are.equal("--steer", argv[3])
    assert.are.equal("--message", argv[4])
    assert.are.equal("fix this", argv[5])
  end)
  it("reopens the selector and resends once after an unknown-session failure", function()
    local agents = require("prime-send.agents")
    -- A stale pinned identity, as if the agent worker moved on.
    state.set_pinned("stale-identity")

    -- The fake fails the first send and succeeds the second.
    local marker = io.open(tests_dir .. "/fail-once", "w")
    marker:close()

    local saved_input = vim.ui.input
    vim.ui.input = function(_opts, on_confirm)
      on_confirm("fix this")
    end

    local new_identity
    local saved_open = selector.open
    selector.open = function(entries, on_choice)
      local sessions = agents.parse_list(table.concat(vim.fn.readfile(tests_dir .. "/golden/list.json"), "\n"))
      new_identity = sessions[2].id
      -- Pick the entry matching the expected new identity.
      for i, entry in ipairs(entries) do
        if entry:find(new_identity, 1, true) then
          on_choice(i)
          return
        end
      end
      on_choice(1)
    end

    -- prime_send composes the reference from the current buffer.
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "/tmp/prime-send-spec-c.lua")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "x" })
    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 1, 0 })

    prime_send_module.prime_send()

    -- Recovery pinned the new choice after the resend.
    vim.wait(5000, function()
      return new_identity ~= nil and state.pinned() == new_identity
    end, 10)

    vim.ui.input = saved_input
    selector.open = saved_open
    assert.are.equal(new_identity, state.pinned())
    assert.are.equal(0, vim.fn.filereadable(tests_dir .. "/fail-once"))
  end)
end)

describe("delivery failure reporting", function()
  local echoed

  before_each(function()
    state.set_pinned(nil)
    os.remove(tests_dir .. "/fail-once")
    vim.env.PRIME_SEND_TEST_FAIL = nil
    echoed = nil
  end)

  after_each(function()
    os.remove(tests_dir .. "/fail-once")
    vim.env.PRIME_SEND_TEST_FAIL = nil
    vim.cmd("silent! %bwipeout!")
  end)

  local function capture_echo()
    local saved = vim.api.nvim_echo
    vim.api.nvim_echo = function(chunks, _hist, _opts)
      echoed = echoed or chunks[1][1]
    end
    return function()
      vim.api.nvim_echo = saved
    end
  end

  local function open_buffer_at()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "/tmp/prime-send-failure-spec.lua")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "x" })
    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
  end

  it("echoes the spawn failure when the pinned identity cannot be delivered", function()
    state.set_pinned("sess-1")
    prime_send_module.setup({ cmd = "definitely-missing-binary-xyz" })
    local restore = capture_echo()
    local saved_input = vim.ui.input
    vim.ui.input = function(_opts, on_confirm)
      on_confirm("fix this")
    end

    open_buffer_at()
    prime_send_module.prime_send()

    vim.wait(3000, function()
      return echoed ~= nil
    end, 10)
    vim.ui.input = saved_input
    restore()

    assert.truthy(echoed:find("failed to spawn", 1, true))
  end)

  it("echoes the CLI error when the delivery keeps failing after the one retry", function()
    state.set_pinned("stale-identity")
    prime_send_module.setup({ cmd = tests_dir .. "/fake-prime-agent" })
    vim.env.PRIME_SEND_TEST_FAIL = "always"
    local saved_open = selector.open
    selector.open = function(_entries, on_choice)
      on_choice(1)
    end
    local restore = capture_echo()
    local saved_input = vim.ui.input
    vim.ui.input = function(_opts, on_confirm)
      on_confirm("fix this")
    end

    open_buffer_at()
    prime_send_module.prime_send()

    vim.wait(5000, function()
      return echoed ~= nil
    end, 10)
    vim.ui.input = saved_input
    selector.open = saved_open
    restore()

    assert.truthy(echoed:find("prime-send: delivery failed", 1, true))
  end)
end)
