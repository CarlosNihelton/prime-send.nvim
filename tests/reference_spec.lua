local reference = require("prime-send.reference")

describe("prime-send.reference.for_buffer", function()
  after_each(function()
    vim.cmd("silent! %bwipeout!")
  end)

  it("returns a root-relative path inside a temporary git repository", function()
    local repo = vim.fn.tempname() .. "-repo"
    vim.fn.mkdir(repo .. "/src", "p")
    vim.fn.writefile({ "line one", "line two" }, repo .. "/src/a.lua")
    vim.fn.system({ "git", "-C", repo, "init", "--quiet" })
    vim.fn.system({ "git", "-C", repo, "config", "user.email", "t@t" })
    vim.fn.system({ "git", "-C", repo, "config", "user.name", "t" })
    vim.fn.system({ "git", "-C", repo, "commit", "--quiet", "--allow-empty", "-m", "init" })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, repo .. "/src/a.lua")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line one", "line two" })

    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 2, 0 })

    local ref = reference.for_buffer(bufnr)
    assert.are.equal("src/a.lua:2", ref)
  end)

  it("returns a range for a line-wise selection of lines 5 through 9", function()
    local repo = vim.fn.tempname() .. "-repo2"
    vim.fn.mkdir(repo .. "/src", "p")
    local lines = {}
    for i = 1, 10 do
      lines[i] = "line " .. i
    end
    vim.fn.writefile(lines, repo .. "/src/ranged.lua")
    vim.fn.system({ "git", "-C", repo, "init", "--quiet" })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, repo .. "/src/ranged.lua")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 5, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("V9G<Esc>", true, false, true), "mx", false)

    assert.are.equal("src/ranged.lua:5-9", reference.for_buffer(bufnr))
  end)

  it("normalizes a selection marked bottom-to-top", function()
    local repo = vim.fn.tempname() .. "-repo3"
    vim.fn.mkdir(repo .. "/src", "p")
    local lines = {}
    for i = 1, 10 do
      lines[i] = "line " .. i
    end
    vim.fn.writefile(lines, repo .. "/src/reversed.lua")
    vim.fn.system({ "git", "-C", repo, "init", "--quiet" })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, repo .. "/src/reversed.lua")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 9, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("V5G<Esc>", true, false, true), "mx", false)

    assert.are.equal("src/reversed.lua:5-9", reference.for_buffer(bufnr))
  end)

  it("rounds a character-wise selection spanning lines 3 and 4", function()
    local repo = vim.fn.tempname() .. "-repo4"
    vim.fn.mkdir(repo .. "/src", "p")
    local lines = {}
    for i = 1, 10 do
      lines[i] = "line " .. i
    end
    vim.fn.writefile(lines, repo .. "/src/charwise.lua")
    vim.fn.system({ "git", "-C", repo, "init", "--quiet" })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, repo .. "/src/charwise.lua")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 3, 2 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("v4G<Esc>", true, false, true), "mx", false)

    assert.are.equal("src/charwise.lua:3-4", reference.for_buffer(bufnr))
  end)

  it("returns an absolute path outside any repository", function()
    local outside = vim.fn.tempname() .. "-outside"
    vim.fn.mkdir(outside, "p")
    vim.fn.writefile({ "hello" }, outside .. "/b.lua")

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, outside .. "/b.lua")

    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 1, 0 })

    local ref = reference.for_buffer(bufnr)
    assert.truthy(ref:find("^/"))
    assert.truthy(ref:find("b%.lua:1$"))
  end)
end)
