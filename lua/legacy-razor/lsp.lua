-- Start and attach the legacy-razor LSP server to classic Razor views, so
-- Neovim's built-in client drives hover (K), completion (into your completion
-- engine), document-highlight, and receives pushed diagnostics -- the VS
-- "contained language" experience, routed through the editor's own LSP.
local M = {}

local project = require("legacy-razor.project")
local server = require("legacy-razor.server")

local notified_error = false

--- Attach the server to a razor buffer (no-op off Windows / outside an app /
--- if the server isn't built).
--- @param bufnr integer
--- @param config table
function M.attach(bufnr, config)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return
  end
  local root = project.find_root(name)
  if not root then
    return -- not a classic System.Web app; leave the buffer alone
  end
  local exe, err = server.locate(config.server_exe)
  if not exe then
    if config.notify_errors and not notified_error then
      notified_error = true
      vim.notify("legacy-razor: " .. err, vim.log.levels.WARN, { title = "legacy-razor" })
    end
    return
  end

  -- Dedups by { name, root_dir, cmd }: one server process per app, reused
  -- across every view buffer under that root.
  vim.lsp.start({
    name = "legacy-razor",
    cmd = { exe, root, "--lsp" },
    root_dir = root,
  }, { bufnr = bufnr })
end

--- Wire cursor-hold document highlighting for the legacy-razor client only
--- (so occurrence highlighting works even if nothing else drives it).
--- @param config table
local function setup_highlight(config)
  if not config.document_highlight then
    return
  end
  local group = vim.api.nvim_create_augroup("LegacyRazorHighlight", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= "legacy-razor" then
        return
      end
      if not client.server_capabilities.documentHighlightProvider then
        return
      end
      local buf = args.buf
      local hl_group = vim.api.nvim_create_augroup("LegacyRazorHighlight" .. buf, { clear = true })
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = hl_group,
        buffer = buf,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = hl_group,
        buffer = buf,
        callback = vim.lsp.buf.clear_references,
      })
    end,
  })
end

--- On classic views, the Roslyn co-host only produces noise ("No information
--- available" hover + bogus "unnecessary using" diagnostics), so detach it and
--- let legacy-razor own these buffers. Only classic System.Web views are
--- affected -- .cs files and ASP.NET Core .razor keep their Roslyn client.
--- @param config table
local function setup_takeover(config)
  if not config.suppress_roslyn then
    return
  end
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("LegacyRazorTakeover", { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or (client.name ~= "roslyn" and client.name ~= "omnisharp") then
        return
      end
      local name = vim.api.nvim_buf_get_name(args.buf)
      if not project.is_view(name) then
        return
      end
      if not project.find_root(name) then
        return -- not a classic System.Web view; leave Roslyn alone
      end
      vim.schedule(function()
        vim.lsp.buf_detach_client(args.buf, args.data.client_id)
        vim.diagnostic.reset(nil, args.buf)
      end)
    end,
  })
end

--- Install autocmds that attach the server to razor buffers.
--- @param config table
function M.setup(config)
  setup_highlight(config)
  setup_takeover(config)
  local group = vim.api.nvim_create_augroup("LegacyRazorLsp", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    pattern = project.view_globs,
    callback = function(ev)
      M.attach(ev.buf, config)
    end,
  })
  -- Attach to views already open (e.g. on :Lazy reload).
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and project.is_view(vim.api.nvim_buf_get_name(buf)) then
      M.attach(buf, config)
    end
  end
end

return M
