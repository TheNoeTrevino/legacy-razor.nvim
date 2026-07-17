local compiler = require("legacy-razor.compiler")

describe("compiler.parse", function()
  it("parses an absolute-path error into a quickfix item", function()
    local items = compiler.parse({
      [[C:\app\Views\Home\Index.cshtml(15): error CS1061: 'Foo' has no 'Bar']],
    }, "C:/app")
    assert.equals(1, #items)
    assert.equals([[C:\app\Views\Home\Index.cshtml]], items[1].filename)
    assert.equals(15, items[1].lnum)
    assert.equals("E", items[1].type)
    assert.equals("CS1061: 'Foo' has no 'Bar'", items[1].text)
  end)

  it("resolves a virtual path against the app root", function()
    local items = compiler.parse({
      "/Views/Home/Index.cshtml(12): error ASPPARSE: unexpected token",
    }, "C:/app")
    assert.equals(1, #items)
    assert.equals("C:/app/Views/Home/Index.cshtml", items[1].filename)
    assert.equals(12, items[1].lnum)
  end)

  it("marks warnings as type W", function()
    local items = compiler.parse({
      [[C:\app\Views\X.cshtml(3): warning CS0219: 'x' is assigned but never used]],
    }, "C:/app")
    assert.equals("W", items[1].type)
  end)

  it("dedups the same error reported twice", function()
    local line = [[C:\app\Views\X.cshtml(5): error CS1002: ; expected]]
    assert.equals(1, #compiler.parse({ line, line }, "C:/app"))
  end)

  it("ignores lines that are not compiler diagnostics", function()
    assert.equals(0, #compiler.parse({ "Building directory '/'.", "" }, "C:/app"))
  end)
end)

describe("compiler.find_exe", function()
  it("accepts an explicit override that exists on disk", function()
    local f = vim.fn.tempname()
    vim.fn.writefile({}, f)
    assert.equals(f, compiler.find_exe(f))
  end)

  it("returns nil for a missing override", function()
    assert.is_nil(compiler.find_exe(vim.fn.tempname() .. "-does-not-exist.exe"))
  end)
end)
