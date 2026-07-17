# legacy-razor.nvim

Full language support - **hover, completion, document-highlight, and live
diagnostics** - for **classic ASP.NET MVC (System.Web) Razor views** in Neovim,
served through the editor's built-in LSP client.

```
@model BalanceHistoryViewModel
...
@Model.TodayBalance      -- K -> "Currency BalanceHistoryViewModel.TodayBalance { get; set; }"
@Model.                  -- completion -> AccountHistoryItems, TodayBalance, FromDate, ...
```

## Why

Modern Razor tooling (the Roslyn language server's co-hosted Razor engine, rzls,
VS Code's C# extension) only understands **ASP.NET Core** Razor. Views based on
`System.Web.Mvc.WebViewPage<T>` - every MVC 5 / .NET Framework app - get nothing
from any LSP-based editor. Only full Visual Studio ever supported them, via
in-process "contained language" machinery that can't be extracted.

This plugin rebuilds that machinery as a standalone LSP server:

1. **Generate** the view's C# with the real `System.Web.Razor` v3 pipeline
   (`MvcWebPageRazorHost`, so `@model`/`@Html`/`web.config` imports all resolve),
   in **design-time mode** so every code region is emitted verbatim.
2. **Host** it as a Roslyn `Document` compiled against the app's `bin/`.
3. **Map** positions both ways through Razor's design-time line mappings, which
   record the exact source and generated columns of each code region - so a
   cursor in the `.cshtml` becomes a position in the generated C#, and Roslyn's
   answers map back to `.cshtml`.
4. **Serve** it over LSP (hover / completion / documentHighlight / diagnostics)
   so Neovim's native client and your completion engine consume it directly.

## Requirements

- Windows (the plugin is inert elsewhere, safe in shared dotfiles)
- .NET SDK (to build the server) + .NET Framework 4.x (runtime, preinstalled)
- The web app must have been **built** (`bin/` populated) so views resolve types

## Install (lazy.nvim)

```lua
{
  dir = "~/projects/legacy-razor",
  enabled = vim.fn.has("win32") == 1,
  ft = "razor",
  cmd = "LegacyRazorCheck",
  build = "dotnet build -c Release server/LegacyRazor.Server.csproj",
  opts = {},
}
```

`build` compiles the LSP server on install/update. To build by hand:

```
dotnet build -c Release server/LegacyRazor.Server.csproj
```

## What you get

Open any `.cshtml` in a classic app and the `legacy-razor` LSP client attaches:

- **Hover** (`K`) - real C# quick-info on `@Model.X`, `@Html` helpers, locals.
- **Completion** - model members after `@Model.`, into your completion engine.
- **Document highlight** - occurrences of the symbol under the cursor.
- **Diagnostics** - live, as you type (a typo'd `@Model` member is CS1061).

Plus `:LegacyRazorCheck` - a whole-app `aspnet_compiler` sweep into quickfix,
for checking every view at once.

## Options (defaults)

```lua
{
  lsp = {
    enabled = true,
    server_exe = nil,          -- explicit path; nil = auto-detect in the plugin
    document_highlight = true, -- occurrence highlighting on CursorHold
    suppress_roslyn = true,    -- detach Roslyn/OmniSharp from classic views
    notify_errors = true,      -- warn once if the server isn't built
  },
  -- whole-app aspnet_compiler sweep (:LegacyRazorCheck)
  aspnet_compiler = nil,       -- explicit path; nil = auto-detect
  open_quickfix = true,
  check_on_save = false,
}
```

`suppress_roslyn` matters if you run roslyn.nvim: it also attaches to `.cshtml`
(as `razor`) but can't model classic views, so it only emits "No information
available" hover and bogus "unnecessary using" diagnostics. This detaches it
from classic System.Web views only - your `.cs` and ASP.NET Core `.razor` keep
their Roslyn client.

## Architecture

```
Neovim (vim.lsp client)                        lua/legacy-razor/
  │  LSP over stdio (one server per app root)    ├─ project    app-root + view detection
  ▼                                              ├─ lsp        attach + Roslyn takeover
LegacyRazor.Server (net472)  server/             ├─ server     locate the built exe
  ├─ RoslynHost   design-time Razor gen +        ├─ compiler   aspnet_compiler -> quickfix
  │  ViewSession  Roslyn workspace, region map,  └─ init       setup + :LegacyRazorCheck
  │               hover/complete/highlight/diagnostics
  ├─ References   .NET Framework + facades + app bin/
  ├─ WebConfig    Views/web.config imports + base type
  ├─ RazorGen     CodeDOM -> C# text
  ├─ Protocol     the 0-based position DTOs
  └─ LspServer    JSON-RPC framing + handlers  (Program launches it)
```

## Development

Two test suites, driven by a Makefile:

```
make test          # both suites
make test-server   # xUnit over the C# engine (dotnet test)
make test-lua      # plenary-busted over the Lua glue (headless Neovim)
make fmt           # stylua
```

The engine tests are self-contained: they use a framework type as the model
(`@model System.String`) so no fixture assembly needs compiling. `make` and
`stylua` install via scoop; the underlying commands also run standalone.

## Limitations

- Hovering the bare `Model` keyword (not a member) may be empty; members work.
- Classic Razor only; ASP.NET Core Razor is already served by rzls/Roslyn.
- UTF-16 column edge cases in non-ASCII lines are approximated.
