local M = {}

--- Decode the percent-escapes of a URL component.
---@param component string
---@return string
local function url_decode(component)
  return (component:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

--- Parse a fugitive buffer name of the form
--- `fugitive://<git-dir>//<rev>[/<path>]` where the rev is a 40-or-more hex
--- sha or a single digit 0 to 3. Returns the URL-decoded git-dir, rev, and
--- path; an empty path means the index itself. Returns nil for anything else.
---@param name string
---@return table|nil parsed
function M.parse_url(name)
  if type(name) ~= "string" then
    return nil
  end

  local rest = name:match("^fugitive://(.+)$")
  if not rest then
    return nil
  end

  local git_dir, rev, tail = rest:match("^(.+)//([^/]+)(.*)$")
  if not git_dir or not rev then
    return nil
  end

  local path = tail and tail:sub(2) or ""

  local is_sha = #rev >= 40 and rev:match("^%x+$") ~= nil
  local is_index_stage = #rev == 1 and rev:match("^[0-3]$") ~= nil
  if not is_sha and not is_index_stage then
    return nil
  end

  return {
    git_dir = url_decode(git_dir),
    rev = rev,
    path = url_decode(path),
  }
end

--- The working-tree file path of a parsed fugitive buffer, preferring the
--- fugitive-provided FugitiveReal function when it exists, else resolving
--- the toplevel of the git dir and joining it with the decoded path.
---@param parsed table
---@return string|nil path nil when the buffer denotes the index itself
function M.worktree_path(parsed)
  if not parsed or parsed.path == "" then
    return nil
  end

  if vim.fn.exists("*FugitiveReal") == 1 then
    return vim.fn.FugitiveReal("fugitive://" .. parsed.git_dir .. "//" .. parsed.rev .. "/" .. parsed.path)
  end

  -- `--show-toplevel` is unreliable with an explicit --git-dir when the
  -- current directory belongs to another repository, so resolve the git dir
  -- absolutely and derive the toplevel from it.
  local git_dir = vim.trim(vim.fn.system({ "git", "--git-dir=" .. parsed.git_dir, "rev-parse", "--absolute-git-dir" }))
  if vim.v.shell_error ~= 0 or git_dir == "" then
    return nil
  end

  local toplevel = vim.fn.fnamemodify(git_dir, ":h")
  local admin_dir = git_dir:match("^(.+)/%.git/worktrees/[^/]+$")
  if admin_dir then
    -- A linked-worktree admin directory: its gitdir file points at the
    -- linked worktree's .git file, whose parent is the worktree root.
    local gitdir_file = vim.fn.readfile(git_dir .. "/gitdir")
    if gitdir_file and #gitdir_file > 0 then
      local linked_root = vim.trim(gitdir_file[1]):match("^(.+)/%.git$")
      if linked_root then
        toplevel = linked_root
      end
    end
  end

  return toplevel .. "/" .. parsed.path
end

return M
