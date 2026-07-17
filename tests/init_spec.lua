local lr = require("legacy-razor")

describe("legacy-razor.config", function()
  it("exposes sensible defaults", function()
    assert.is_true(lr.config.lsp.enabled)
    assert.is_true(lr.config.open_quickfix)
    assert.is_false(lr.config.check_on_save)
    assert.is_true(lr.config.lsp.suppress_roslyn)
  end)

  it("deep-merges setup opts, preserving sibling keys", function()
    lr.setup({ open_quickfix = false, lsp = { enabled = false, document_highlight = false } })
    assert.is_false(lr.config.open_quickfix)
    assert.is_false(lr.config.lsp.enabled)
    assert.is_false(lr.config.lsp.document_highlight)
    assert.is_true(lr.config.lsp.notify_errors) -- untouched sibling preserved by the deep merge
  end)
end)
