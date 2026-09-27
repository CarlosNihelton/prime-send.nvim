local tests_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local state = require("prime-send.state")
local format = require("prime-send.format")
local prime_send_module = require("prime-send")

local marker

local function spawn_count()
  if vim.fn.filereadable(marker) == 0 then
    return 0
  end
  return #vim.fn.readfile(marker)
end

local function wait_for(cond, timeout)
  vim.wait(timeout or 3000, cond, 10)
  return cond()
end

describe("prime-send.format.aggregate", function()
  it("joins entries with one blank line and no numbering", function()
    local message = format.aggregate({ "src/x.lua:42 Comment: first", "src/y.lua:7 Comment:\nsecond line" })
    local lines = vim.split(message, "\n", { plain = true })
    assert.are.equal("src/x.lua:42 Comment: first", lines[1])
    assert.are.equal("", lines[2])
    assert.are.equal("src/y.lua:7 Comment:", lines[3])
    assert.are.equal("second line", lines[4])
  end)
end)

describe("PrimeSendMultiple flow", function()
  before_each(function()
    marker = tests_dir .. "/.spawned"
    os.remove(marker)
    vim.env.PRIME_SEND_TEST_MARKER = marker
    state.set_pinned(nil)
    state.clear()
    prime_send_module.setup({ cmd = tests_dir .. "/fake-prime-agent" })
  end)

  after_each(function()
    os.remove(marker)
    os.remove(tests_dir .. "/.argv")
    vim.env.PRIME_SEND_TEST_ARGV = nil
    vim.env.PRIME_SEND_TEST_MARKER = nil
    state.clear()
    state.set_pinned(nil)
    vim.cmd("silent! %bwipeout!")
  end)

  local function open_buffer_at()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "/tmp/prime-send-aggregate.lua")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two", "three" })
    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 2, 0 })
    return bufnr
  end

  it("appends the composed entry without spawning", function()
    open_buffer_at()
    local saved_input = vim.ui.input
    vim.ui.input = function(_opts, on_confirm)
      on_confirm("first comment")
    end

    prime_send_module.send_multiple({})
    vim.ui.input = saved_input

    local entries = state.entries()
    assert.are.equal(1, #entries)
    assert.truthy(entries[1]:find("/tmp/prime%-send%-aggregate%.lua:2 Comment: first comment$"))
    assert.are.equal(0, spawn_count())
  end)

  it("delivers every pending entry as one message and clears the queue on bang", function()
    state.add_entry("src/x.lua:42 Comment: first")
    state.add_entry("src/y.lua:7 Comment:\nsecond line")

    -- Capture the spawned argv NUL-separated, as the real command sees it.
    local argv_file = tests_dir .. "/.argv"
    os.remove(argv_file)
    vim.env.PRIME_SEND_TEST_ARGV = argv_file

    -- The selector opens at the last moment: on the bang form only.
    local saved_select = vim.ui.select
    vim.ui.select = function(items, _opts, on_choice)
      on_choice(items[2], 2)
    end

    prime_send_module.send_multiple({ bang = true })

    assert.is_true(wait_for(function()
      return spawn_count() == 1 and #state.entries() == 0
    end))
    vim.ui.select = saved_select
    assert.truthy(state.pinned())

    local fh = io.open(argv_file, "rb")
    assert.truthy(fh, "the spawned argv was not captured")
    local data = fh:read("*a")
    fh:close()

    local argv = vim.split(data, "\0", { plain = true })
    assert.are.equal("send", argv[1])
    assert.are.equal("--message", argv[3])
    assert.are.equal("src/x.lua:42 Comment: first\n\nsrc/y.lua:7 Comment:\nsecond line", argv[4])
  end)

  it("echoes nothing pending and spawns nothing on an empty queue", function()
    local echoed
    local saved_echo = vim.api.nvim_echo
    vim.api.nvim_echo = function(chunks, _hist, _opts)
      echoed = chunks[1][1]
    end

    prime_send_module.send_multiple({ bang = true })
    vim.api.nvim_echo = saved_echo

    assert.are.equal("prime-send: nothing pending", echoed)
    assert.are.equal(0, spawn_count())
  end)

  it("clears the queue and echoes the discarded count on cancel", function()
    state.add_entry("src/x.lua:42 Comment: first")
    state.add_entry("src/y.lua:7 Comment: second")

    local echoed
    local saved_echo = vim.api.nvim_echo
    vim.api.nvim_echo = function(chunks, _hist, _opts)
      echoed = chunks[1][1]
    end

    prime_send_module.send_multiple_cancel()
    vim.api.nvim_echo = saved_echo

    assert.are.equal(0, #state.entries())
    assert.are.equal("prime-send: discarded 2", echoed)
  end)

  it("lets a plain prime_send deliver its own message and keep pending entries", function()
    state.add_entry("src/x.lua:42 Comment: pending entry")
    open_buffer_at()
    local saved_input = vim.ui.input
    vim.ui.input = function(_opts, on_confirm)
      on_confirm("direct comment")
    end
    local saved_select = vim.ui.select
    vim.ui.select = function(items, _opts, on_choice)
      on_choice(items[1], 1)
    end

    prime_send_module.prime_send()

    assert.is_true(wait_for(function()
      return spawn_count() == 1
    end))
    vim.ui.input = saved_input
    vim.ui.select = saved_select

    assert.is_true(wait_for(function()
      return spawn_count() == 1
    end))
    local entries = state.entries()
    assert.are.equal(1, #entries)
    assert.are.equal("src/x.lua:42 Comment: pending entry", entries[1])
  end)
end)
