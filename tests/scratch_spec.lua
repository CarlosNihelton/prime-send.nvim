local format = require("prime-send.format")
local scratch = require("prime-send.scratch")

describe("prime-send.format.multi_line", function()
  it("keeps body lines verbatim, including blank and indented lines", function()
    local message = format.multi_line("src/x.lua:42", { "first", "", "  indented" })
    assert.are.equal("src/x.lua:42 Comment:\nfirst\n\n  indented", message)
  end)
end)

describe("prime-send.scratch.open", function()
  local sent

  before_each(function()
    sent = "unset"
  end)

  after_each(function()
    vim.cmd("silent! %bwipeout!")
  end)

  it("opens a centered floating markdown buffer prefilled with the reference line", function()
    local win, bufnr = scratch.open("src/x.lua:42", function(message)
      sent = message
    end)
    local config = vim.api.nvim_win_get_config(win)
    assert.are.equal("editor", config.relative)
    assert.truthy(config.border)
    assert.are.equal("markdown", vim.bo[bufnr].filetype)
    assert.are.equal(false, vim.bo[bufnr].buflisted)
    local first = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
    assert.are.equal("src/x.lua:42 Comment:", first)

    vim.api.nvim_win_close(win, true)
    sent = nil
    assert.is_nil(sent)
  end)

  it("calls on_send with the first line plus the body and closes on write", function()
    local win, bufnr = scratch.open("src/x.lua:42", function(message)
      sent = message
    end)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "src/x.lua:42 Comment:", "body", "", "  indented" })

    vim.api.nvim_set_current_win(win)
    vim.cmd("silent! write")

    assert.are.equal("src/x.lua:42 Comment:\nbody\n\n  indented", sent)
    assert.is_false(vim.api.nvim_win_is_valid(win))
    assert.is_false(vim.api.nvim_buf_is_valid(bufnr))
  end)

  it("calls on_send with nil when quitting without writing", function()
    local win = scratch.open("src/x.lua:42", function(message)
      sent = message
    end)
    vim.api.nvim_win_close(win, true)
    assert.is_nil(sent)
  end)

  it("allows a second scratch while the first is live, each delivering to its own callback", function()
    local first_message, second_message
    local win1, bufnr1 = scratch.open("src/one.lua:1", function(message)
      first_message = message
    end)
    local win2, bufnr2 = scratch.open("src/two.lua:2", function(message)
      second_message = message
    end)

    assert.is_true(vim.api.nvim_win_is_valid(win1))
    assert.is_true(vim.api.nvim_win_is_valid(win2))
    assert.are_not.equal(bufnr1, bufnr2)

    vim.api.nvim_buf_set_lines(bufnr2, 0, -1, false, { "src/two.lua:2 Comment:", "from second" })
    vim.api.nvim_set_current_win(win2)
    vim.cmd("silent! write")

    assert.are.equal("src/two.lua:2 Comment:\nfrom second", second_message)
    assert.is_nil(first_message)
    assert.is_false(vim.api.nvim_win_is_valid(win2))
    assert.is_false(vim.api.nvim_buf_is_valid(bufnr2))
    assert.is_true(vim.api.nvim_win_is_valid(win1))
    assert.is_true(vim.api.nvim_buf_is_valid(bufnr1))

    vim.api.nvim_buf_set_lines(bufnr1, 0, -1, false, { "src/one.lua:1 Comment:", "from first" })
    vim.api.nvim_set_current_win(win1)
    vim.cmd("silent! write")

    assert.are.equal("src/one.lua:1 Comment:\nfrom first", first_message)
    assert.is_false(vim.api.nvim_win_is_valid(win1))
    assert.is_false(vim.api.nvim_buf_is_valid(bufnr1))
  end)
end)

describe("prime_send with cancelled comment", function()
  after_each(function()
    vim.cmd("silent! %bwipeout!")
  end)

  it("opens no scratch window and sends nothing", function()
    local repo = vim.fn.tempname() .. "-repo-cancel"
    vim.fn.mkdir(repo .. "/src", "p")
    local lines = {}
    for i = 1, 50 do
      lines[i] = "line " .. i
    end
    vim.fn.writefile(lines, repo .. "/src/cancelled.lua")
    vim.fn.system({ "git", "-C", repo, "init", "--quiet" })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, repo .. "/src/cancelled.lua")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 42, 0 })

    local saved_input = vim.ui.input
    vim.ui.input = function(_opts, on_confirm)
      on_confirm(nil)
    end
    local prime_send_module = require("prime-send")
    prime_send_module.prime_send()
    vim.ui.input = saved_input

    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if w ~= win then
        assert.are.equal("", vim.api.nvim_win_get_config(w).relative, "no floating window should open")
      end
    end
  end)
end)

describe("prime_send with empty comment", function()
  after_each(function()
    vim.cmd("silent! %bwipeout!")
  end)

  it("opens the scratch buffer with the current reference", function()
    local repo = vim.fn.tempname() .. "-repo-scratch"
    vim.fn.mkdir(repo .. "/src", "p")
    local lines = {}
    for i = 1, 50 do
      lines[i] = "line " .. i
    end
    vim.fn.writefile(lines, repo .. "/src/scratched.lua")
    vim.fn.system({ "git", "-C", repo, "init", "--quiet" })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, repo .. "/src/scratched.lua")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 42, 0 })

    local saved_input = vim.ui.input
    vim.ui.input = function(_opts, on_confirm)
      on_confirm("")
    end

    local prime_send_module = require("prime-send")
    prime_send_module.prime_send()
    vim.ui.input = saved_input

    -- A floating scratch window exists beyond the window we opened.
    local scratch_buf
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if w ~= win and vim.api.nvim_win_get_config(w).relative ~= "" then
        scratch_buf = vim.api.nvim_win_get_buf(w)
      end
    end
    assert.truthy(scratch_buf, "expected a floating scratch window")
    local first = vim.api.nvim_buf_get_lines(scratch_buf, 0, 1, false)[1]
    assert.are.equal("src/scratched.lua:42 Comment:", first)
  end)
end)
