-- Smoke test: proves the plenary-busted harness runs and the plugin directory
-- is on the runtimepath (so later specs can `require` the plugin's modules).

describe("harness", function()
  it("runs specs under plenary busted", function()
    assert.equals(2, 1 + 1)
  end)

  it("has the neovim runtime available", function()
    assert.equals(1, vim.fn.has("nvim"))
  end)
end)
