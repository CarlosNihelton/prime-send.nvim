local fugitive = require("prime-send.fugitive")
local reference = require("prime-send.reference")

local sha = string.rep("a1b2", 10) -- 40 hex chars

describe("prime-send.fugitive.parse_url", function()
  it("extracts git-dir, rev, and decoded path from a sha URL", function()
    local parsed = fugitive.parse_url("fugitive:///tmp/some%20repo/.git//" .. sha .. "/src/a%20file.lua")
    assert.truthy(parsed)
    assert.are.equal("/tmp/some repo/.git", parsed.git_dir)
    assert.are.equal(sha, parsed.rev)
    assert.are.equal("src/a file.lua", parsed.path)
  end)

  it("reads rev 0 and a missing path as the index buffer", function()
    local parsed = fugitive.parse_url("fugitive:///repo/.git//0")
    assert.truthy(parsed)
    assert.are.equal("/repo/.git", parsed.git_dir)
    assert.are.equal("0", parsed.rev)
    assert.are.equal("", parsed.path)
  end)

  it("rejects URLs with an unsupported rev", function()
    assert.is_nil(fugitive.parse_url("fugitive:///repo/.git//main/src/x.lua"))
    assert.is_nil(fugitive.parse_url("/repo/.git/src/x.lua"))
  end)
end)

describe("prime-send.fugitive.worktree_path", function()
  local repo

  before_each(function()
    repo = vim.fn.tempname() .. "-fugitive-repo"
    vim.fn.mkdir(repo .. "/src", "p")
    vim.fn.writefile({ "one", "two", "three" }, repo .. "/src/tracked.lua")
    vim.fn.system({ "git", "-C", repo, "init", "--quiet" })
    vim.fn.system({ "git", "-C", repo, "config", "user.email", "t@t" })
    vim.fn.system({ "git", "-C", repo, "config", "user.name", "t" })
    vim.fn.system({ "git", "-C", repo, "add", "src/tracked.lua" })
    vim.fn.system({ "git", "-C", repo, "commit", "--quiet", "-m", "init" })
  end)

  it("resolves to the working-tree file path without FugitiveReal", function()
    if vim.fn.exists("*FugitiveReal") == 1 then
      pending("FugitiveReal is loaded")
      return
    end
    local parsed = fugitive.parse_url("fugitive://" .. repo .. "/.git//" .. sha .. "/src/tracked.lua")
    local resolved = fugitive.worktree_path(parsed)
    assert.are.equal(repo .. "/src/tracked.lua", resolved)
  end)

  it("resolves a linked worktree file through its worktree root", function()
    if vim.fn.exists("*FugitiveReal") == 1 then
      pending("FugitiveReal is loaded")
      return
    end
    local linked = repo .. "-linked"
    vim.fn.system({ "git", "-C", repo, "worktree", "add", "--quiet", linked, "HEAD" })

    local parsed = fugitive.parse_url("fugitive://" .. linked .. "/.git//" .. sha .. "/src/tracked.lua")
    local resolved = fugitive.worktree_path(parsed)
    assert.are.equal(linked .. "/src/tracked.lua", resolved)

    vim.fn.system({ "git", "-C", repo, "worktree", "remove", "--force", linked })
  end)

  it("prefers a stubbed FugitiveReal when the function exists", function()
    vim.cmd("function! FugitiveReal(f) abort\n return '/stubbed/real.lua'\nendfunction")
    local parsed = fugitive.parse_url("fugitive://" .. repo .. "/.git//" .. sha .. "/src/tracked.lua")
    assert.are.equal("/stubbed/real.lua", fugitive.worktree_path(parsed))
    vim.cmd("delfunction FugitiveReal")
  end)
end)

describe("prime-send.reference.for_buffer on fugitive buffers", function()
  it("yields a root-relative path with the cursor line", function()
    local repo = vim.fn.tempname() .. "-fugitive-ref-repo"
    vim.fn.mkdir(repo .. "/src", "p")
    vim.fn.writefile({ "one", "two", "three" }, repo .. "/src/committed.lua")
    vim.fn.system({ "git", "-C", repo, "init", "--quiet" })
    vim.fn.system({ "git", "-C", repo, "config", "user.email", "t@t" })
    vim.fn.system({ "git", "-C", repo, "config", "user.name", "t" })
    vim.fn.system({ "git", "-C", repo, "add", "src/committed.lua" })
    vim.fn.system({ "git", "-C", repo, "commit", "--quiet", "-m", "init" })
    local head_sha = vim.trim(vim.fn.system({ "git", "-C", repo, "rev-parse", "HEAD" }))

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "fugitive://" .. repo .. "/.git//" .. head_sha .. "/src/committed.lua")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two", "three" })

    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 2, 0 })

    assert.are.equal("src/committed.lua:2", reference.for_buffer(bufnr))
  end)

  it("returns nil for an index buffer without a file path", function()
    local repo = vim.fn.tempname() .. "-fugitive-index-repo"
    vim.fn.mkdir(repo, "p")
    vim.fn.system({ "git", "-C", repo, "init", "--quiet" })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "fugitive://" .. repo .. "/.git//0")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "staged" })

    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 1, 0 })

    assert.is_nil(reference.for_buffer(bufnr))
  end)
end)

describe("prime_send on an unsendable fugitive index buffer", function()
  before_each(function()
    vim.cmd("silent! %bwipeout!")
  end)

  after_each(function()
    vim.cmd("silent! %bwipeout!")
  end)

  it("echoes the no-reference message, prompts nothing, and sends nothing", function()
    local repo = vim.fn.tempname() .. "-fugitive-abort-repo"
    vim.fn.mkdir(repo, "p")
    vim.fn.system({ "git", "-C", repo, "init", "--quiet" })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "fugitive://" .. repo .. "/.git//0")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "staged" })

    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 10,
      row = 1,
      col = 1,
    })
    vim.api.nvim_win_set_cursor(win, { 1, 0 })

    local echoed, prompted
    local saved_echo = vim.api.nvim_echo
    vim.api.nvim_echo = function(chunks)
      echoed = table.concat(vim.tbl_map(function(c)
        return c[1]
      end, chunks))
    end
    local saved_input = vim.ui.input
    vim.ui.input = function()
      prompted = true
    end

    require("prime-send").prime_send()

    vim.api.nvim_echo = saved_echo
    vim.ui.input = saved_input

    assert.are.equal("prime-send: no reference for this buffer", echoed)
    assert.is_nil(prompted)
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if w ~= win then
        assert.are.equal("", vim.api.nvim_win_get_config(w).relative, "no floating window should open")
      end
    end
  end)
end)
