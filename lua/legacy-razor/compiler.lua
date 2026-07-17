-- Run aspnet_compiler.exe and parse its output into quickfix items.
--
-- aspnet_compiler is the precompiler that ships with the .NET Framework
-- itself (no SDK/VS install needed). It runs the *same* System.Web.Razor v3
-- pipeline IIS uses at runtime, honoring Views/web.config (pageBaseType,
-- namespaces), so errors carry full semantics: a bad @Model member is a real
-- CS1061 pointing at the .cshtml file and line.
--
-- Without a target dir it performs in-place precompilation into the
-- "Temporary ASP.NET Files" cache: source is never modified, and warm re-runs
-- only recompile changed view directories (seconds instead of minutes).
local M = {}

local uv = vim.uv

--- Find aspnet_compiler.exe. 64-bit first, then 32-bit.
---@param override string|nil explicit path from user config
---@return string|nil
function M.find_exe(override)
  if override then
    return uv.fs_stat(override) and override or nil
  end
  local windir = vim.env.SystemRoot or "C:/Windows"
  local candidates = {
    vim.fs.joinpath(windir, "Microsoft.NET/Framework64/v4.0.30319/aspnet_compiler.exe"),
    vim.fs.joinpath(windir, "Microsoft.NET/Framework/v4.0.30319/aspnet_compiler.exe"),
  }
  for _, path in ipairs(candidates) do
    if uv.fs_stat(path) then
      return path
    end
  end
  return nil
end

--- Parse compiler output into quickfix items.
--
-- Error lines come in two shapes:
--   C:\app\Views\Foo\Bar.cshtml(15): error CS1061: 'X' does not contain ...
--   /Views/Foo/Bar.cshtml(12): error ASPPARSE: ...       (virtual path)
---@param lines string[]
---@param root string physical app root, used to resolve virtual paths
---@return table[] quickfix items
function M.parse(lines, root)
  local items = {}
  local seen = {}
  for _, line in ipairs(lines) do
    local file, lnum, kind, code, msg = line:match("^(.-)%((%d+)%): (%a+) (%w+): (.+)$")
    if file then
      if vim.startswith(file, "/") then
        file = vim.fs.joinpath(root, file)
      end
      local key = file .. lnum .. msg
      -- Batch compilation can report the same error more than once.
      if not seen[key] then
        seen[key] = true
        table.insert(items, {
          filename = file,
          lnum = tonumber(lnum),
          type = kind:lower() == "warning" and "W" or "E",
          text = code .. ": " .. msg,
        })
      end
    end
  end
  return items
end

--- Compile the app's views asynchronously.
---@param root string physical app root
---@param exe string path to aspnet_compiler.exe
---@param on_done fun(code: integer, items: table[], raw: string)
function M.run(root, exe, on_done)
  -- aspnet_compiler is a native Windows tool; give it backslashes.
  local win_root = root:gsub("/", "\\")
  vim.system({ exe, "-p", win_root, "-v", "/" }, { text = true }, function(out)
    local raw = (out.stdout or "") .. "\n" .. (out.stderr or "")
    local items = M.parse(vim.split(raw, "\r?\n"), root)
    vim.schedule(function()
      on_done(out.code, items, raw)
    end)
  end)
end

return M
