--- Reference resolution for the buffer under the cursor.
local M = {}

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
---@return string reference
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
