-- Minimal init for the plenary-busted spec suite.
--
-- Puts the plugin and plenary.nvim on the runtimepath. plenary is expected
-- under `.deps/` (run `make deps`), but we fall back to a lazy.nvim install so
-- the suite can be run ad-hoc without cloning. plenary bundles luassert, so no
-- luarocks/C-toolchain is needed (which matters on Windows).

local root = vim.fn.getcwd()

local function first_dir(paths)
  for _, p in ipairs(paths) do
    if p ~= "" and vim.fn.isdirectory(vim.fn.expand(p)) == 1 then
      return vim.fn.expand(p)
    end
  end
  return nil
end

local plenary = first_dir({
  root .. "/.deps/plenary.nvim",
  vim.fn.stdpath("data") .. "/lazy/plenary.nvim",
  vim.fn.stdpath("data") .. "/site/pack/*/start/plenary.nvim",
})

assert(plenary, "plenary.nvim not found -- run `make deps`")

vim.opt.runtimepath:append(root)
vim.opt.runtimepath:append(plenary)

vim.cmd("runtime plugin/plenary.vim")

-- Keep the command line quiet during tests.
vim.notify = function() end
