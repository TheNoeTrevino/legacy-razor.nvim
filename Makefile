DEPS    := .deps
PLENARY := $(DEPS)/plenary.nvim

BUSTED := nvim --headless --noplugin -u tests/minimal_init.lua \
	-c "PlenaryBustedDirectory tests/ {minimal_init='tests/minimal_init.lua', sequential=true}"

.PHONY: test test-lua test-server deps fmt fmt-check clean

## Run both suites (Lua glue + C# engine).
test: test-lua test-server

## Run the Lua spec suite under plenary-busted (one headless Neovim).
test-lua:
	$(BUSTED)

## Run the C# engine suite under xUnit.
test-server:
	dotnet test server.tests/LegacyRazor.Server.Tests.csproj

## Clone test dependencies into .deps/ (idempotent). Not required if plenary is
## already installed via your plugin manager -- tests/minimal_init.lua falls back
## to a lazy.nvim install.
deps: $(PLENARY)

$(PLENARY):
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(PLENARY)

## Format all Lua in place with stylua (uses ./stylua.toml).
fmt:
	stylua lua/ plugin/ tests/

## Check formatting without writing; non-zero exit on any diff (CI-friendly).
fmt-check:
	stylua --check lua/ plugin/ tests/

## Remove build + test artifacts.
clean:
	rm -rf .tests $(DEPS) server/bin server/obj server.tests/bin server.tests/obj
