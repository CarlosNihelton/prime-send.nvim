--- Floating selector window for picking an entry from a list.
local M = {}

--- Open the selector over ``entries`` and call ``on_choice`` with the
--- 1-based index of the chosen entry, or nil when cancelled. The selector is
--- a centered floating window: Enter picks the line under the cursor, Esc
--- and q cancel, and closing the window cancels too. An empty list cancels
--- immediately without opening a window.
---@param entries string[] the display lines, one per choice
---@param on_choice fun(choice: integer|nil)
---@return integer|nil win the selector window, nil for an empty list
---@return integer|nil bufnr the selector buffer, nil for an empty list
function M.open(entries, on_choice)
  if #entries == 0 then
    on_choice(nil)
    return nil, nil
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "hide"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, entries)
  vim.bo[bufnr].modifiable = false

  local width = 1
  for _, line in ipairs(entries) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width + 2, math.floor(vim.o.columns * 0.9))
  local height = math.max(1, math.min(#entries, math.floor(vim.o.lines * 0.6)))

  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    style = "minimal",
  })
  vim.wo[win].cursorline = true

  local finished = false

  local function cleanup()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end

  local function choose()
    if finished then
      return
    end
    finished = true
    local choice = vim.api.nvim_win_get_cursor(win)[1]
    cleanup()
    on_choice(choice)
  end

  local function cancel()
    if finished then
      return
    end
    finished = true
    cleanup()
    on_choice(nil)
  end

  vim.keymap.set("n", "<CR>", choose, { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "q", cancel, { buffer = bufnr, nowait = true })

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = cancel,
  })

  return win, bufnr
end

return M
