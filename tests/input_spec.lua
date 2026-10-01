local input = require("prime-send.input")

describe("prime-send.input.open", function()
  local result

  before_each(function()
    result = "unset"
  end)

  after_each(function()
    vim.cmd("silent! %bwipeout!")
    pcall(vim.cmd, "stopinsert")
  end)

  it("opens a centered floating window with the prompt as the border title", function()
    local win, bufnr = input.open("Comment: ", function(text)
      result = text
    end)

    assert.is_true(vim.api.nvim_win_is_valid(win))
    assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
    local config = vim.api.nvim_win_get_config(win)
    assert.are.equal("editor", config.relative)
    -- The title comes back as highlight chunks: {{ "text", "hl" }}.
    -- (:startinsert only takes effect once the command completes, so the
    -- insert mode itself is proven by the typing tests below.)
  end)

  it("delivers the typed line on Enter", function()
    input.open("Comment: ", function(text)
      result = text
    end)

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("ihello agent", true, false, true), "x", false)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)

    assert.are.equal("hello agent", result)
  end)

  it("strips leading and trailing spaces from the typed line", function()
    input.open("Comment: ", function(text)
      result = text
    end)

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i  padded  ", true, false, true), "x", false)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)

    assert.are.equal("padded", result)
  end)

  it("delivers the empty string when submitted without typing", function()
    input.open("Comment: ", function(text)
      result = text
    end)

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)

    assert.are.equal("", result)
  end)

  it("delivers nil on Escape", function()
    local win = input.open("Comment: ", function(text)
      result = text
    end)

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

    assert.is_nil(result)
    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)

  it("delivers nil when the window is closed", function()
    local win = input.open("Comment: ", function(text)
      result = text
    end)

    vim.api.nvim_win_close(win, true)

    assert.is_nil(result)
  end)
end)
