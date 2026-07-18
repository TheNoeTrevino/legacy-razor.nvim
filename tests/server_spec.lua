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

  it("without an override, resolves an installed server or explains how to get one", function()
    local exe, err = server.locate(nil)
    if exe then
      assert.is_truthy(exe:find("LegacyRazor.Server.exe", 1, true))
      assert.is_nil(err)
    else
      assert.is_truthy(err:find("LegacyRazorUpdate", 1, true))
      assert.is_truthy(err:find("MasonInstall", 1, true))
    end
  end)
end)

describe("server release coordinates", function()
  it("names the win-x64 asset for the pinned version", function()
    assert.equals(
      "legacy-razor-server-v" .. server.required_server .. "-win-x64.zip",
      server.asset_name(server.required_server)
    )
  end)

  it("builds a github release download url", function()
    local url = server.asset_url(server.required_server)
    assert.is_truthy(
      url:find("github.com/TheNoeTrevino/legacy-razor-ls/releases/download/v", 1, true)
    )
    assert.is_truthy(url:find(server.asset_name(server.required_server), 1, true))
  end)

  it("appends a suffix for the checksum url", function()
    assert.is_truthy(server.asset_url(server.required_server, ".sha256"):find("%.sha256$"))
  end)

  it("caches downloads per-version under stdpath data", function()
    local p = server.cache_exe("9.9.9")
    assert.is_truthy(p:find("9.9.9", 1, true))
    assert.is_truthy(p:find("LegacyRazor.Server.exe", 1, true))
  end)
end)
