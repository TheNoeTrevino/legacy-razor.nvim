local server = require("legacy-razor.server")

describe("server.locate", function()
  it("returns an explicit override that exists on disk", function()
    local f = vim.fn.tempname()
    vim.fn.writefile({}, f)
    local exe, err = server.locate(f)
    assert.equals(f, exe)
    assert.is_nil(err)
  end)

  it("errors on a configured override that is missing", function()
    local exe, err = server.locate(vim.fn.tempname() .. "-nope.exe")
    assert.is_nil(exe)
    assert.is_truthy(err and err:find("not found", 1, true))
  end)

  it("without an override, resolves the built exe or explains how to build it", function()
    local exe, err = server.locate(nil)
    if exe then
      assert.is_truthy(exe:find("LegacyRazor.Server.exe", 1, true))
      assert.is_nil(err)
    else
      assert.is_truthy(err:find("dotnet build", 1, true))
    end
  end)
end)
