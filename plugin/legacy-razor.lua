-- Command registration. Gated to Windows: aspnet_compiler ships with the
-- .NET Framework, which only exists there. On other platforms the plugin is
-- inert so it can live in a shared dotfiles setup safely.
if vim.g.loaded_legacy_razor then
  return
end
vim.g.loaded_legacy_razor = 1

if vim.fn.has("win32") ~= 1 then
  return
end

vim.api.nvim_create_user_command("LegacyRazorCheck", function(cmd)
  require("legacy-razor").check(cmd.args ~= "" and cmd.args or nil)
end, {
  nargs = "?",
  complete = "dir",
  desc = "Compile-check classic ASP.NET MVC Razor views (errors -> quickfix)",
})

vim.api.nvim_create_user_command("LegacyRazorUpdate", function()
  require("legacy-razor").update()
end, {
  desc = "Download the prebuilt legacy-razor language server (from GitHub Releases)",
})
