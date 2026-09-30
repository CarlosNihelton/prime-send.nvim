local selector = require("prime-send.selector")

describe("prime-send.selector.open", function()
  local choice

  before_each(function()
    choice = "unset"
  end)

  after_each(function()
    vim.cmd("silent! %bwipeout!")
  end)

  it("lists the entries in a floating window and returns the chosen index", function()
    local win, bufnr = selector.open({ "one", "two", "three" }, function(c)
      choice = c
    end)

    assert.is_true(vim.api.nvim_win_is_valid(win))
    assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
    assert.are.equal(3, vim.api.nvim_buf_line_count(bufnr))
    assert.is_true(vim.wo[win].cursorline)

    vim.api.nvim_win_set_cursor(win, { 2, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)

    assert.are.equal(2, choice)
    assert.is_false(vim.api.nvim_win_is_valid(win))
    assert.is_false(vim.api.nvim_buf_is_valid(bufnr))
  end)

  it("cancels on Escape", function()
    local win = selector.open({ "one", "two" }, function(c)
      choice = c
    end)

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

    assert.is_nil(choice)
    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)

  it("cancels on q", function()
    local win = selector.open({ "one", "two" }, function(c)
      choice = c
    end)

    vim.api.nvim_feedkeys("q", "x", false)

    assert.is_nil(choice)
    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)

  it("cancels when the window is closed", function()
    local win = selector.open({ "one", "two" }, function(c)
      choice = c
    end)

    vim.api.nvim_win_close(win, true)
    assert.is_true(vim.wait(2000, function()
      return choice ~= "unset"
    end))

    assert.is_nil(choice)
  end)

  it("cancels immediately for an empty list without opening a window", function()
    local win, bufnr = selector.open({}, function(c)
      choice = c
    end)

    assert.is_nil(win)
    assert.is_nil(bufnr)
    assert.is_nil(choice)
  end)
end)
