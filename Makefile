.PHONY: check deps format-check lint test

PLENARY_DIR := .deps/plenary.nvim
PLENARY_REPO := https://github.com/nvim-lua/plenary.nvim

check: format-check lint test

format-check:
	stylua --check .

lint:
	luacheck lua plugin tests

deps:
	@set -e; \
	if [ ! -d "$(PLENARY_DIR)/.git" ]; then \
		mkdir -p .deps; \
		tmp="$(PLENARY_DIR).tmp"; \
		rm -rf "$$tmp"; \
		git clone --depth 1 "$(PLENARY_REPO)" "$$tmp"; \
		rm -rf "$(PLENARY_DIR)"; \
		mv "$$tmp" "$(PLENARY_DIR)"; \
	fi

test: deps
	@set -e; \
	xdg_home=$$(mktemp -d); \
	trap 'rm -rf "$$xdg_home"' EXIT; \
	for spec in tests/spec.lua tests/*_spec.lua; do \
		XDG_CONFIG_HOME="$$xdg_home/config" \
		XDG_DATA_HOME="$$xdg_home/data" \
		XDG_STATE_HOME="$$xdg_home/state" \
		XDG_CACHE_HOME="$$xdg_home/cache" \
		nvim --headless -u tests/minimal_init.lua "+PlenaryBustedFile $$spec" +qa; \
	done
