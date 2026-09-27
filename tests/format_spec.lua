local format = require("prime-send.format")

describe("prime-send.format.single_line", function()
  it("joins the reference, the marker, and the comment on one line", function()
    assert.are.equal("src/x.lua:42 Comment: fix this", format.single_line("src/x.lua:42", "fix this"))
  end)
end)
