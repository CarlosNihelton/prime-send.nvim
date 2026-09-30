local M = {}

local scratch_count = 0

--- Open the scratch buffer for composing a multi-line comment: an unlisted
--- markdown buffer in a centered floating window, prefilled with the
--- reference line. Writing the buffer delivers the composed message through
--- on_send; quitting without writing delivers nil.
---@param reference string the `path:line` (or range) location
---@param on_send fun(message: string|nil)
---@return integer win the scratch window
---@return integer bufnr the scratch buffer
function M.open(reference, on_send)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].bufhidden = "hide"
  scratch_count = scratch_count + 1
  vim.api.nvim_buf_set_name(bufnr, ("prime-send://scratch-%d"):format(scratch_count))
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { reference .. " Comment:" })

  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.6)
  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    style = "minimal",
  })

  local finished = false

  local function cleanup()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      if finished then
        return
      end
      finished = true
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      cleanup()
      on_send(table.concat(lines, "\n"))
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    callback = function()
      if finished then
        return
      end
      finished = true
      cleanup()
      on_send(nil)
    end,
  })

  return win, bufnr
end

return M
