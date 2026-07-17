local project = require("legacy-razor.project")

local function tmpdir()
  local d = vim.fn.tempname()
  vim.fn.mkdir(d, "p")
  return vim.fs.normalize(d)
end

describe("project.is_view", function()
  it("recognizes razor view extensions", function()
    assert.is_true(project.is_view("Index.cshtml"))
    assert.is_true(project.is_view("Layout.vbhtml"))
  end)

  it("rejects non-views and empty names", function()
    assert.is_false(project.is_view("Program.cs"))
    assert.is_false(project.is_view("web.config"))
    assert.is_false(project.is_view(""))
  end)
end)

describe("project.find_root", function()
  it("walks up to the directory containing Global.asax", function()
    local root = tmpdir()
    vim.fn.writefile({}, root .. "/Global.asax")
    vim.fn.mkdir(root .. "/Views/Home", "p")
    local view = root .. "/Views/Home/Index.cshtml"
    vim.fn.writefile({}, view)
    assert.equals(root, project.find_root(view))
  end)

  it("recognizes an MVC app by its Views/web.config", function()
    local root = tmpdir()
    vim.fn.mkdir(root .. "/Views", "p")
    vim.fn.writefile({}, root .. "/Views/web.config")
    assert.equals(root, project.find_root(root .. "/Views/web.config"))
  end)

  it("returns nil outside any System.Web app", function()
    local d = tmpdir()
    assert.is_nil(project.find_root(d .. "/loose.cshtml"))
  end)
end)
