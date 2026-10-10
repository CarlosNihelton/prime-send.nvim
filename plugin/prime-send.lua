if vim.g.loaded_prime_send then
  return
end
vim.g.loaded_prime_send = true

local prime_send = require("prime-send")

vim.api.nvim_create_user_command("PrimeSend", function()
  prime_send.prime_send()
end, { desc = "Send the current entry to the pinned agent", range = true })

vim.api.nvim_create_user_command("PrimeSendSelectAgent", function()
  prime_send.select_agent(function() end)
end, { desc = "Select and pin the agent that receives subsequent messages" })

vim.api.nvim_create_user_command("PrimeSendMultiple", function(opts)
  prime_send.send_multiple({ bang = opts.bang })
end, { desc = "Send every pending entry as a single aggregated message", bang = true })

vim.api.nvim_create_user_command("PrimeSendMultipleCancel", function()
  prime_send.send_multiple_cancel()
end, { desc = "Cancel the pending queue of an aggregated send" })
