--- Shared centered floating-window helper.
local M = {}

--- Open a centered floating window over ``bufnr`` and focus it.
---@param bufnr integer the window buffer
---@param width integer the window width
---@param height integer the window height
---@param opts table|nil extra nvim_open_win options, e.g. a border title
---@return integer win the window
function M.centered(bufnr, width, height, opts)
  return vim.api.nvim_open_win(
    bufnr,
    true,
    vim.tbl_extend("force", {
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      border = "rounded",
      style = "minimal",
    }, opts or {})
  )
end

return M
