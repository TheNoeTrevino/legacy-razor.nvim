local lsp = require("legacy-razor.lsp")

-- The attach path is mostly editor wiring (vim.lsp.start against a real server
-- process), so the unit-testable surface is its guards: it must leave a buffer
-- alone when there's no name and when the file isn't inside a System.Web app.
describe("lsp.attach guards", function()
  it("is a no-op for an unnamed buffer", function()
    local buf = vim.api.nvim_create_buf(false, true)
    assert.has_no.errors(function()
      lsp.attach(buf, { notify_errors = false })
    end)
    assert.equals(0, #vim.lsp.get_clients({ bufnr = buf }))
  end)

  it("is a no-op for a view outside any System.Web app", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local dir = vim.fs.normalize(vim.fn.tempname())
    vim.fn.mkdir(dir, "p")
    vim.api.nvim_buf_set_name(buf, dir .. "/loose.cshtml")
    assert.has_no.errors(function()
      lsp.attach(buf, { notify_errors = false })
    end)
    assert.equals(0, #vim.lsp.get_clients({ bufnr = buf }))
  end)
end)
