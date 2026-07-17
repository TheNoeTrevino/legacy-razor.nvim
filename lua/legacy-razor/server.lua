-- Locate the built LSP server executable.
local M = {}

--- @param override string|nil explicit path from config
--- @return string|nil exe, string|nil err
function M.locate(override)
  if override and override ~= "" then
    if vim.uv.fs_stat(override) then
      return override, nil
    end
    return nil, "configured server_exe not found: " .. override
  end
  local this = debug.getinfo(1, "S").source:sub(2)
  local plugin_root = vim.fn.fnamemodify(this, ":h:h:h")
  local exe = plugin_root .. "/server/bin/Release/net472/LegacyRazor.Server.exe"
  if vim.uv.fs_stat(exe) then
    return exe, nil
  end
  return nil,
    "server not built. Run:  dotnet build -c Release "
      .. plugin_root
      .. "/server/LegacyRazor.Server.csproj"
end

return M
