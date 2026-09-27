local diffmap = require("prime-send.diffmap")
local reference = require("prime-send.reference")

local modification_diff = table.concat({
  "diff --git a/src/app.lua b/src/app.lua",
  "index 1111111..2222222 100644",
  "--- a/src/app.lua",
  "+++ b/src/app.lua",
  "@@ -1,4 +1,5 @@",
  " line one",
  "-line two",
  "+line two modified",
  "+line two added",
  " line three",
  " line four",
  "@@ -20,4 +21,5 @@",
  " line twenty",
  "-line twenty one",
  "+line twenty one changed",
  " line twenty two",
  " line twenty three",
}, "\n")

local new_file_diff = table.concat({
  "diff --git a/src/new.lua b/src/new.lua",
  "new file mode 100644",
  "--- /dev/null",
  "+++ b/src/new.lua",
  "@@ -0,0 +1,2 @@",
  "+first",
  "+second",
}, "\n")

local deleted_file_diff = table.concat({
  "diff --git a/src/old.lua b/src/old.lua",
  "deleted file mode 100644",
  "--- a/src/old.lua",
  "+++ /dev/null",
  "@@ -1,2 +0,0 @@",
  "-first",
  "-second",
}, "\n")

describe("prime-send.diffmap.parse", function()
  it("takes the path from the +++ header without the b/ prefix", function()
    local sections = diffmap.parse(modification_diff)
    assert.are.equal(1, #sections)
    assert.are.equal("src/app.lua", sections[1].path)
    assert.are.equal(2, #sections[1].hunks)
  end)

  it("strips a trailing tab or timestamp from the +++ header", function()
    local with_stamp =
      modification_diff:gsub("^%+%+%+ b/src/app%.lua$", "+++ b/src/app.lua\t2026-09-27 10:00:00.000000000 +0000")
    local sections = diffmap.parse(with_stamp)
    assert.are.equal("src/app.lua", sections[1].path)
  end)

  it("falls back to the diff --git paths when the +++ header is absent", function()
    local sections = diffmap.parse({
      "diff --git a/src/fallback.lua b/src/fallback.lua",
      "index 1111111..2222222 100644",
    })
    assert.are.equal("src/fallback.lua", sections[1].path)
  end)

  it("yields the +++ path for new files with --- /dev/null", function()
    local sections = diffmap.parse(new_file_diff)
    assert.are.equal("src/new.lua", sections[1].path)
  end)

  it("yields the --- path for deleted files", function()
    local sections = diffmap.parse(deleted_file_diff)
    assert.are.equal("src/old.lua", sections[1].path)
  end)
end)

describe("prime-send.diffmap.locate", function()
  it("maps context and added lines to the new side in a multi-hunk modification", function()
    local sections = diffmap.parse(modification_diff)
    -- First hunk: @@ -1,4 +1,5 @@
    local path, line = diffmap.locate(sections, 6) -- context " line one"
    assert.are.equal("src/app.lua", path)
    assert.are.equal(1, line)

    local _, added = diffmap.locate(sections, 8) -- "+line two modified"
    assert.are.equal(2, added)

    local _, second_added = diffmap.locate(sections, 9) -- "+line two added"
    assert.are.equal(3, second_added)

    -- Second hunk: the line below its header maps to the new start.
    local _, below = diffmap.locate(sections, 13) -- context " line twenty"
    assert.are.equal(21, below)
  end)

  it("yields nil on hunk headers and between hunks", function()
    local sections = diffmap.parse(modification_diff)
    local p1, l1 = diffmap.locate(sections, 5) -- @@ header of the first hunk
    assert.is_nil(p1)
    assert.is_nil(l1)
    local p2, l2 = diffmap.locate(sections, 12) -- @@ header of the second hunk
    assert.is_nil(p2)
    assert.is_nil(l2)
    local p3, l3 = diffmap.locate(sections, 3) -- "--- a/src/app.lua"
    assert.is_nil(p3)
    assert.is_nil(l3)
  end)

  it("maps deletion-only hunks to old-side line numbers", function()
    local sections = diffmap.parse(deleted_file_diff)
    local path, line = diffmap.locate(sections, 6) -- "-first"
    assert.are.equal("src/old.lua", path)
    assert.are.equal(1, line)
    local _, second = diffmap.locate(sections, 7) -- "-second"
    assert.are.equal(2, second)
  end)

  it("maps new-file additions to new-side line numbers with the +++ path", function()
    local sections = diffmap.parse(new_file_diff)
    local path, line = diffmap.locate(sections, 6) -- "+first"
    assert.are.equal("src/new.lua", path)
    assert.are.equal(1, line)
    local _, second = diffmap.locate(sections, 7) -- "+second"
    assert.are.equal(2, second)
  end)

  it("yields nil past the end of the diff", function()
    local sections = diffmap.parse(modification_diff)
    local p, l = diffmap.locate(sections, 100)
    assert.is_nil(p)
    assert.is_nil(l)
  end)
end)

describe("prime-send.reference.for_buffer on diff buffers", function()
  it("returns a root-relative reference built from locate", function()
    local repo = vim.fn.tempname() .. "-repo-diff"
    vim.fn.mkdir(repo .. "/src", "p")
    vim.fn.writefile({ "line one", "line two", "line three" }, repo .. "/src/patched.lua")
    vim.fn.system({ "git", "-C", repo, "init", "--quiet" })
    vim.fn.system({ "git", "-C", repo, "config", "user.email", "t@t" })
    vim.fn.system({ "git", "-C", repo, "config", "user.name", "t" })
    vim.fn.system({ "git", "-C", repo, "add", "src/patched.lua" })
    vim.fn.system({ "git", "-C", repo, "commit", "--quiet", "-m", "init" })
    vim.fn.writefile({ "line one", "line two changed", "line three" }, repo .. "/src/patched.lua")
    local diff_out = vim.fn.system({ "git", "-C", repo, "diff" })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, repo .. "/work.patch")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(diff_out, "\n", { plain = true }))

    local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = 40,
      height = 20,
      row = 1,
      col = 1,
    })
    -- Park the cursor on the "+line two changed" line of the real diff.
    local target
    for i, l in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
      if l == "+line two changed" then
        target = i
      end
    end
    assert.truthy(target)
    vim.api.nvim_win_set_cursor(win, { target, 0 })

    assert.are.equal("src/patched.lua:2", reference.for_buffer(bufnr))
  end)
end)
