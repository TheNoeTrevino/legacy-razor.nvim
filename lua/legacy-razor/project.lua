-- Locate the physical root of a classic ASP.NET (System.Web) application.
--
-- aspnet_compiler needs the app's *physical root* (-p), i.e. the directory
-- IIS would point at. For MVC 5 apps that's the directory containing
-- Global.asax and the Views/ folder. We walk up from the current file so the
-- right app is found even in solutions with several web projects.
local M = {}

local uv = vim.uv

-- Classic Razor view files: autocmd globs + a filename predicate, so the set
-- of supported extensions lives in exactly one place.
M.view_globs = { "*.cshtml", "*.vbhtml" }

--- @param name string buffer/file name
--- @return boolean
function M.is_view(name)
  return name ~= "" and (name:match("%.cshtml$") or name:match("%.vbhtml$")) ~= nil
end

---@param dir string
---@return boolean
local function is_app_root(dir)
  if uv.fs_stat(vim.fs.joinpath(dir, "Global.asax")) then
    return true
  end
  -- Fallback marker: an MVC Views folder with its razor web.config.
  return uv.fs_stat(vim.fs.joinpath(dir, "Views", "web.config")) ~= nil
end

--- Walk upward from `start` (file or directory) to the app root.
---@param start string
---@return string|nil physical root, nil if not inside a System.Web app
function M.find_root(start)
  local dir = vim.fn.isdirectory(start) == 1 and start or vim.fs.dirname(start)
  dir = vim.fs.normalize(dir)
  while dir do
    if is_app_root(dir) then
      return dir
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      return nil
    end
    dir = parent
  end
  return nil
end

return M
