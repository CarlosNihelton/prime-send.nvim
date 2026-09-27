--- Reference resolution for the buffer under the cursor.
local diffmap = require("prime-send.diffmap")
local fugitive = require("prime-send.fugitive")

local M = {}

--- Whether a buffer carries diff content: a diff filetype or a .patch/.diff
--- file name.
---@param bufnr integer
---@param path string
---@return boolean
local function is_diff_buffer(bufnr, path)
  if vim.bo[bufnr].filetype == "diff" then
    return true
  end
  return path:match("%.patch$") ~= nil or path:match("%.diff$") ~= nil
end

--- The project root of a buffer: the git toplevel of its directory when the
--- buffer lives in a repository, else the root of the first attached LSP
--- client, else nil.
---@param path string the absolute buffer file path
---@param bufnr integer
---@return string|nil root
local function project_root(path, bufnr)
  local dir = vim.fn.fnamemodify(path, ":h")
  local git = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }):wait()
  if git.code == 0 then
    local toplevel = vim.trim(git.stdout or "")
    if toplevel ~= "" then
      return toplevel
    end
  end

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    local root = client.config and (client.config.root_dir or client.config.root_uri)
    if type(root) == "string" and root ~= "" then
      if root:sub(1, 7) == "file://" then
        root = vim.uri_to_fname(root)
      end
      return root
    end
  end

  return nil
end

--- Map the cursor in a diff buffer to the referenced file line via diffmap.
--- The mapped path is kept relative to the project root when that file
--- exists under the root, else the patch-relative path is kept.
---@param bufnr integer
---@param path string the absolute path of the diff buffer
---@param cursor integer the cursor buffer line
---@return string|nil reference
local function diff_reference(bufnr, path, cursor)
  local sections = diffmap.parse(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
  local mapped_path, line = diffmap.locate(sections, cursor)
  if not mapped_path or not line then
    return nil
  end

  local root = project_root(path, bufnr)
  if root and vim.uv.fs_stat(root .. "/" .. mapped_path) then
    return string.format("%s:%d", mapped_path, line)
  end
  return string.format("%s:%d", mapped_path, line)
end

--- Build the reference of a fugitive buffer from the working-tree file
--- path relative to the project root, keeping the cursor line number
--- unchanged for index and commit revisions.
---@param bufnr integer
---@param name string the fugitive buffer name
---@param cursor integer the cursor line
---@return string|nil reference
local function fugitive_reference(_bufnr, name, cursor)
  local parsed = fugitive.parse_url(name)
  if not parsed then
    return nil
  end

  local worktree_path = fugitive.worktree_path(parsed)
  if not worktree_path then
    return nil
  end

  local toplevel =
    vim.trim(vim.fn.system({ "git", "-C", vim.fn.fnamemodify(worktree_path, ":h"), "rev-parse", "--show-toplevel" }))
  if vim.v.shell_error == 0 and toplevel ~= "" and worktree_path:sub(1, #toplevel + 1) == toplevel .. "/" then
    worktree_path = worktree_path:sub(#toplevel + 2)
  end
  return string.format("%s:%d", worktree_path, cursor)
end

--- The visual selection of a buffer, read from the marks and normalized so
--- that the start never exceeds the end. Rounded to whole lines for
--- line-wise and character-wise selections. Returns nil when no selection
--- is active.
---@param bufnr integer
---@return integer|nil start
---@return integer|nil stop
local function visual_range(bufnr)
  local start = vim.api.nvim_buf_get_mark(bufnr, "<")[1]
  local stop = vim.api.nvim_buf_get_mark(bufnr, ">")[1]
  if start == 0 and stop == 0 then
    return nil
  end
  if start > stop then
    start, stop = stop, start
  end
  return start, stop
end

--- The reference of a buffer: its file path relative to the project root,
--- then a colon, then the cursor line number, or `path:start-end` for the
--- active visual selection.
---@param bufnr integer
---@return string|nil reference nil when the buffer has no sendable reference
function M.for_buffer(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local line = 1
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      line = vim.api.nvim_win_get_cursor(win)[1]
      break
    end
  end

  local start, stop = visual_range(bufnr)

  if path:sub(1, 11) == "fugitive://" then
    local ref = fugitive_reference(bufnr, path, line)
    if ref then
      return ref
    end
    return nil
  end

  if is_diff_buffer(bufnr, path) then
    local ref = diff_reference(bufnr, path, line)
    if ref then
      return ref
    end
  end

  if path == "" then
    if start then
      return string.format("buffer:%d:%d-%d", bufnr, start, stop)
    end
    return string.format("buffer:%d:%d", bufnr, line)
  end

  path = vim.fn.fnamemodify(path, ":p")
  local root = project_root(path, bufnr)
  local prefix = root and root .. "/" or ""
  if prefix ~= "" and path:sub(1, #prefix) == prefix then
    path = path:sub(#prefix + 1)
  end

  if start then
    return string.format("%s:%d-%d", path, start, stop)
  end
  return string.format("%s:%d", path, line)
end

return M
