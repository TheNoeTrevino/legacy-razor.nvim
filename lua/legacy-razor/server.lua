-- Locate (and, on request, download) the LegacyRazor.Server binary.
--
-- The server ships separately from this plugin, from
-- github.com/TheNoeTrevino/legacy-razor-ls. Resolution order, first hit wins:
--   1. an explicit config override (lsp.server_exe)
--   2. a mason-installed legacy-razor-ls
--   3. a version-pinned download in stdpath('data') (see :LegacyRazorUpdate)
--   4. a sibling Release build of the server repo (for contributors)
-- With none of these, locate() returns an error listing every way to get one.
local M = {}

-- The server release this plugin build targets. Bump in lockstep with the
-- legacy-razor-ls tags; :LegacyRazorUpdate fetches exactly this.
M.required_server = "0.1.0"

local EXE = "LegacyRazor.Server.exe"
local REPO = "TheNoeTrevino/legacy-razor-ls"

local function exists(path)
  return path ~= nil and vim.uv.fs_stat(path) ~= nil
end

--- Release asset name for a server version (a zip of the whole net472 output).
--- @param version string
--- @return string
function M.asset_name(version)
  return ("legacy-razor-server-v%s-win-x64.zip"):format(version)
end

--- Download URL of the release asset, or its checksum when a suffix is given.
--- @param version string
--- @param suffix string|nil "" for the zip, ".sha256" for the checksum
--- @return string
function M.asset_url(version, suffix)
  return ("https://github.com/%s/releases/download/v%s/%s%s"):format(
    REPO,
    version,
    M.asset_name(version),
    suffix or ""
  )
end

--- Where a downloaded server of a given version is cached on disk.
--- @param version string
--- @return string
function M.cache_exe(version)
  return vim.fs.joinpath(vim.fn.stdpath("data"), "legacy-razor", version, EXE)
end

--- A mason-installed server, if mason is present and the package is installed.
--- @return string|nil
local function mason_exe()
  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    return nil
  end
  local got, pkg = pcall(registry.get_package, "legacy-razor-ls")
  if not got or not pkg:is_installed() then
    return nil
  end
  local exe = vim.fs.joinpath(pkg:get_install_path(), EXE)
  return exists(exe) and exe or nil
end

--- A Release build of the server repo checked out beside this plugin -- for
--- contributors who work on both. Looks for ../legacy-razor-ls and ../legacy-razor.
--- @return string|nil
local function sibling_exe()
  local this = debug.getinfo(1, "S").source:sub(2)
  local plugin_root = vim.fn.fnamemodify(this, ":h:h:h")
  local parent = vim.fn.fnamemodify(plugin_root, ":h")
  for _, name in ipairs({ "legacy-razor-ls", "legacy-razor" }) do
    local exe = vim.fs.joinpath(parent, name, "server", "bin", "Release", "net472", EXE)
    if exists(exe) then
      return exe
    end
  end
  return nil
end

--- @param override string|nil explicit path from config
--- @return string|nil exe, string|nil err
function M.locate(override)
  if override and override ~= "" then
    if exists(override) then
      return override, nil
    end
    return nil, "configured server_exe not found: " .. override
  end

  local cached = M.cache_exe(M.required_server)
  local exe = mason_exe() or (exists(cached) and cached or nil) or sibling_exe()
  if exe then
    return exe, nil
  end

  return nil,
    (
      "LegacyRazor.Server (v%s) not found. Get it any of these ways:\n"
      .. "  :LegacyRazorUpdate             download the prebuilt server\n"
      .. "  :MasonInstall legacy-razor-ls  install it through mason\n"
      .. "  lsp.server_exe = '/path/to/%s'   point at your own build\n"
      .. "  or clone github.com/%s beside this plugin and run:\n"
      .. "    dotnet build -c Release server/LegacyRazor.Server.csproj"
    ):format(M.required_server, EXE, REPO)
end

--- Ask a candidate binary its version (`--version`); nil if it won't run.
--- @param exe string
--- @return string|nil
function M.probe_version(exe)
  local ok, res = pcall(function()
    return vim.system({ exe, "--version" }, { text = true }):wait()
  end)
  if not ok or res.code ~= 0 then
    return nil
  end
  return vim.trim(res.stdout or "")
end

local function sha256(path)
  local res = vim
    .system({
      "powershell",
      "-NoProfile",
      "-Command",
      ("(Get-FileHash -Algorithm SHA256 -LiteralPath '%s').Hash"):format(path),
    }, { text = true })
    :wait()
  return res.code == 0 and vim.trim(res.stdout or "") or nil
end

local function unzip(zip, dir)
  local res = vim
    .system({
      "powershell",
      "-NoProfile",
      "-Command",
      ("Expand-Archive -LiteralPath '%s' -DestinationPath '%s' -Force"):format(zip, dir),
    }, { text = true })
    :wait()
  return res.code == 0, res.stderr
end

--- Download, verify, and unpack the pinned server release into the data-dir
--- cache. Windows only (curl.exe + PowerShell ship with the OS). Blocks for the
--- duration of the download; call from :LegacyRazorUpdate, not on a hot path.
--- @param on_done fun(ok: boolean, message: string)|nil
function M.download(on_done)
  local version = M.required_server
  local done = on_done or function() end
  local target = M.cache_exe(version)
  local dir = vim.fs.dirname(target)
  vim.fn.mkdir(dir, "p")
  local zip = vim.fs.joinpath(dir, M.asset_name(version))

  local dl = vim.system({ "curl", "-fSL", "-o", zip, M.asset_url(version) }, { text = true }):wait()
  if dl.code ~= 0 then
    return done(false, "download failed: " .. vim.trim(dl.stderr or ""))
  end

  -- Checksum is best-effort: verify when the .sha256 asset is present.
  local sum = vim
    .system({ "curl", "-fSL", M.asset_url(version, ".sha256") }, { text = true })
    :wait()
  if sum.code == 0 then
    local want = (sum.stdout or ""):match("%x%x+")
    local got = sha256(zip)
    if want and got and want:lower() ~= got:lower() then
      return done(false, ("checksum mismatch: expected %s, got %s"):format(want, got))
    end
  end

  local ok, err = unzip(zip, dir)
  if not ok then
    return done(false, "failed to extract server: " .. vim.trim(err or ""))
  end
  os.remove(zip)

  if not exists(target) then
    return done(false, "server binary missing after extract: " .. target)
  end
  local reported = M.probe_version(target)
  if reported and reported ~= version then
    return done(
      false,
      ("version mismatch: downloaded v%s but the binary reports %s"):format(version, reported)
    )
  end
  return done(true, "installed LegacyRazor.Server v" .. version)
end

return M
