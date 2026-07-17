-- legacy-razor: language support for classic ASP.NET MVC (System.Web) Razor.
--
-- Modern Razor tooling (the Roslyn LSP's co-hosted Razor engine, rzls) only
-- understands ASP.NET Core Razor. Views based on System.Web.Mvc.WebViewPage
-- get nothing model-aware in any LSP-based editor. This plugin fills the gap
-- two ways:
--   * lsp.lua  -- a Roslyn-backed LSP server: hover, completion, document
--                 highlight, and live diagnostics (see server/).
--   * M.check  -- :LegacyRazorCheck, a whole-app aspnet_compiler sweep into
--                 quickfix (the same pipeline IIS runs), for checking every
--                 view at once.
local M = {}

local compiler = require("legacy-razor.compiler")
local project = require("legacy-razor.project")

---@class LegacyRazorConfig
M.config = {
  -- Explicit path to aspnet_compiler.exe. nil = auto-detect from %SystemRoot%.
  aspnet_compiler = nil,
  -- Open the quickfix window when :LegacyRazorCheck finds errors.
  open_quickfix = true,
  -- Run the full-app aspnet_compiler check after writing a razor buffer. Off
  -- by default: the first (cold-cache) compile of a large site is slow.
  check_on_save = false,

  -- Full language support (hover, completion, document-highlight, diagnostics)
  -- via the Roslyn-backed LSP server, driven by Neovim's built-in client.
  lsp = {
    enabled = true,
    -- Explicit path to LegacyRazor.Server.exe. nil = auto-detect in the plugin.
    server_exe = nil,
    -- Drive occurrence highlighting on CursorHold for the legacy-razor client.
    document_highlight = true,
    -- Detach Roslyn/OmniSharp from classic views (they only add noise there).
    suppress_roslyn = true,
    -- Notify (once, as WARN) on setup problems like an unbuilt server.
    notify_errors = true,
  },
}

local state = {
  running = false,
}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "legacy-razor" })
end

--- Warn about modified razor buffers: the compiler reads from disk, so
--- unsaved edits are invisible to it.
local function warn_unsaved()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].modified
      and vim.bo[buf].filetype == "razor"
    then
      notify("Unsaved razor buffers exist; the check reads from disk.", vim.log.levels.WARN)
      return
    end
  end
end

--- Compile-check the views of the app containing the current buffer.
---@param root_arg string|nil explicit app root; nil = detect from current buffer/cwd
---@param on_done fun(code: integer, items: table[])|nil test/integration hook
function M.check(root_arg, on_done)
  if state.running then
    notify("A check is already running.", vim.log.levels.WARN)
    return
  end

  local start = root_arg
    or vim.api.nvim_buf_get_name(0)
  if start == "" then
    start = assert(vim.uv.cwd())
  end
  local root = project.find_root(vim.fs.normalize(start))
  if not root then
    notify(
      "No System.Web app root found (looked for Global.asax / Views/web.config above "
        .. start
        .. ")",
      vim.log.levels.ERROR
    )
    return
  end

  local exe = compiler.find_exe(M.config.aspnet_compiler)
  if not exe then
    notify("aspnet_compiler.exe not found under %SystemRoot%\\Microsoft.NET.", vim.log.levels.ERROR)
    return
  end

  warn_unsaved()
  notify("Compiling views in " .. vim.fs.basename(root) .. "… (first run can be slow)")
  state.running = true
  local t0 = vim.uv.hrtime()

  compiler.run(root, exe, function(code, items, raw)
    state.running = false
    local secs = (vim.uv.hrtime() - t0) / 1e9
    local elapsed = string.format("%.1fs", secs)

    vim.fn.setqflist({}, "r", {
      title = "legacy-razor: " .. vim.fs.basename(root),
      items = items,
    })

    if #items > 0 then
      notify(string.format("%d view error(s) in %s", #items, elapsed), vim.log.levels.ERROR)
      if M.config.open_quickfix then
        vim.cmd.copen()
      end
    elseif code ~= 0 then
      -- Compiler failed without parseable errors (e.g. bin/ missing because
      -- the project was never built). Surface its raw output.
      notify("aspnet_compiler failed:\n" .. vim.trim(raw), vim.log.levels.ERROR)
    else
      notify("Views compiled clean in " .. elapsed)
    end

    if on_done then
      on_done(code, items)
    end
  end)
end

---@param opts LegacyRazorConfig|nil
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  if M.config.check_on_save then
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = vim.api.nvim_create_augroup("LegacyRazorCheckOnSave", { clear = true }),
      pattern = project.view_globs,
      callback = function(ev)
        M.check(ev.file)
      end,
    })
  end

  if M.config.lsp.enabled then
    require("legacy-razor.lsp").setup(M.config.lsp)
  end
end

return M
