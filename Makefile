DEPS    := .deps
PLENARY := $(DEPS)/plenary.nvim

BUSTED := nvim --headless --noplugin -u tests/minimal_init.lua \
	-c "PlenaryBustedDirectory tests/ {minimal_init='tests/minimal_init.lua', sequential=true}"

.PHONY: test deps fmt fmt-check clean

## Run the spec suite under plenary-busted (one headless Neovim).
test:
	$(BUSTED)

## Clone test dependencies into .deps/ (idempotent). Not required if plenary is
## already installed via your plugin manager -- tests/minimal_init.lua falls back
## to a lazy.nvim install.
deps: $(PLENARY)

$(PLENARY):
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(PLENARY)

## Format Lua in place (stylua, ./stylua.toml).
fmt:
	stylua lua/ plugin/ tests/

## Check formatting without writing; non-zero exit on any diff (CI-friendly).
fmt-check:
	stylua --check lua/ plugin/ tests/

## Remove test artifacts.
clean:
	rm -rf .tests $(DEPS)
