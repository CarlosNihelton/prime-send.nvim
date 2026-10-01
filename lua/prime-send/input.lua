--- Floating input window for composing a one-line comment.
local float = require("prime-send.float")

local M = {}

--- Open the floating comment input and call ``on_input`` with the typed
--- line. Submitting with <CR> delivers the buffer line with leading and
--- trailing spaces stripped (the empty string when nothing was typed);
--- <Esc> and closing the window deliver nil. The window opens in insert
--- mode so typing starts right away.
---@param prompt string the prompt shown on the window border
---@param on_input fun(text: string|nil)
---@return integer win the input window
---@return integer bufnr the input buffer
function M.open(prompt, on_input)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "hide"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })

  -- 75-column minimum, user-tuned.
  local width = math.min(math.max(75, #prompt + 8), math.floor(vim.o.columns * 0.9))
  local win = float.centered(bufnr, width, 1, { title = prompt })

  local finished = false

  local function cleanup()
    pcall(vim.cmd, "stopinsert")
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end

  local function submit()
    if finished then
      return
    end
    finished = true
    local text = vim.trim(vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or "")
    cleanup()
    on_input(text)
  end

  local function cancel()
    if finished then
      return
    end
    finished = true
    cleanup()
    on_input(nil)
  end

  vim.keymap.set({ "i", "n" }, "<CR>", submit, { buffer = bufnr, nowait = true })
  vim.keymap.set({ "i", "n" }, "<Esc>", cancel, { buffer = bufnr })

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = cancel,
  })

  vim.cmd.startinsert()

  return win, bufnr
end

return M
