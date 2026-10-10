--- Registration of the user commands exposed by plugin/prime-send.lua.
--- The plugin file is sourced explicitly: the plenary harness runs specs in
--- child sessions where startup plugin loading does not include it.
describe("PrimeSend command registration", function()
  vim.cmd("silent! runtime plugin/prime-send.lua")

  it("accepts a range so visual-mode :'<,'>PrimeSend does not fail with E481", function()
    local command = vim.api.nvim_get_commands({}).PrimeSend
    assert.is_not_nil(command)
    assert.is_not_nil(command.range)
  end)

  it("registers the supporting commands without ranges", function()
    local commands = vim.api.nvim_get_commands({})
    assert.is_not_nil(commands.PrimeSendSelectAgent)
    assert.is_not_nil(commands.PrimeSendMultiple)
    assert.is_not_nil(commands.PrimeSendMultipleCancel)
  end)
end)
