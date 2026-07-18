# legacy-razor.nvim

Neovim integration for [**legacy-razor-ls**](https://github.com/thenoetrevino/legacy-razor-ls) -
a language server that brings **hover, completion, document-highlight, and live
diagnostics** to **classic ASP.NET MVC (System.Web) Razor views**, which no modern
tooling understands. Plus a whole-app compile check into the quickfix list.

```
@model BalanceHistoryViewModel
...
@Model.TodayBalance      -- K -> "Currency BalanceHistoryViewModel.TodayBalance { get; set; }"
@Model.                  -- completion -> AccountHistoryItems, TodayBalance, FromDate, ...
```

The language server does the real work - it hosts the *real* `System.Web.Razor` v3
pipeline and Roslyn (see the [server repo](https://github.com/thenoetrevino/legacy-razor-ls)
for how and why). This plugin is the thin Neovim client: it launches the server,
routes `.cshtml` buffers to it, drives occurrence highlighting, gets Roslyn out of
the way, and adds `:LegacyRazorCheck`.

## Requirements

- Windows (the plugin is inert elsewhere, safe in shared dotfiles)
- .NET Framework 4.x (runtime, preinstalled on Windows)
- The web app must have been **built** (`bin/` populated) so views resolve types
- The server binary - installed one of three ways (see below)

## Install (lazy.nvim)

```lua
{
  "thenoetrevino/legacy-razor.nvim",
  enabled = vim.fn.has("win32") == 1,
  ft = "razor",
  cmd = { "LegacyRazorCheck", "LegacyRazorUpdate" },
  opts = {},
}
```

Then get the language server with **any** of:

- **`:LegacyRazorUpdate`** - downloads the prebuilt server (matched to this plugin's
  pinned version) into `stdpath("data")`. No .NET SDK required.
- **`:MasonInstall legacy-razor-ls`** - if you use
  [mason.nvim](https://github.com/williamboman/mason.nvim).
- **Your own build** - clone
  [legacy-razor-ls](https://github.com/thenoetrevino/legacy-razor-ls),
  `dotnet build -c Release server/LegacyRazor.Server.csproj`, and set
  `lsp.server_exe` to the resulting `LegacyRazor.Server.exe`. (Checked out *beside*
  this plugin, it's picked up automatically.)

The plugin resolves the binary in that order - override → mason → download → sibling
build - and, if none is found, tells you exactly how to get one.

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
    server_exe = nil,          -- explicit path; nil = auto-resolve (mason/download/sibling)
    document_highlight = true, -- occurrence highlighting on CursorHold
    suppress_roslyn = true,    -- detach Roslyn/OmniSharp from classic views
    notify_errors = true,      -- warn once if the server isn't installed
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
Neovim (vim.lsp client)                 lua/legacy-razor/
  │  LSP over stdio                       ├─ project    app-root + view detection
  │  (one server per app root)            ├─ lsp        attach + Roslyn takeover
  ▼                                       ├─ server     resolve/download the server binary
legacy-razor-ls (separate repo)          ├─ compiler   aspnet_compiler -> quickfix
  the LegacyRazor.Server.exe process      └─ init       setup + :LegacyRazorCheck / :LegacyRazorUpdate
```

## Development

```
make test        # plenary-busted specs (headless Neovim)
make fmt         # stylua
make fmt-check   # stylua --check (CI)
```

`make` and `stylua` install via scoop; the underlying commands also run standalone.

## Limitations

- Hovering the bare `Model` keyword (not a member) may be empty; members work.
- Classic Razor only; ASP.NET Core Razor is already served by rzls/Roslyn.
- Windows only (classic ASP.NET is .NET Framework).
