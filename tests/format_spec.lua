local format = require("prime-send.format")

describe("prime-send.format.single_line", function()
  it("joins the reference, the marker, and the comment on one line", function()
    assert.are.equal("src/x.lua:42 Comment: fix this", format.single_line("src/x.lua:42", "fix this"))
  end)
end)

describe("prime-send.format.finalize", function()
  it("appends the reply note after one blank line", function()
    assert.are.equal(
      "src/x.lua:42 Comment: fix this\n\n" .. format.REPLY_NOTE,
      format.finalize("src/x.lua:42 Comment: fix this")
    )
  end)

  it("leaves an empty message untouched", function()
    assert.are.equal("", format.finalize(""))
    assert.are.equal(nil, format.finalize(nil))
  end)
end)
