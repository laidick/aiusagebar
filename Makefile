# AI Usage Bar (macOS) — wraps vendor/ai-usagebar (Rust backend + Swift menu bar app)
VENDOR   := vendor/ai-usagebar
BIN_DIR  := $(HOME)/.cargo/bin
CFG_DIR  := $(HOME)/.config/ai-usagebar
APP      := $(VENDOR)/macos/ai-usagebar-menubar

.PHONY: all submodule build build-rust build-swift test install config run stop status login-claude login-codex

all: build

submodule:
	git submodule update --init --recursive

build: build-rust build-swift

build-rust: submodule
	cd $(VENDOR) && cargo build --release

build-swift: submodule
	cd $(VENDOR)/macos && ./build.sh

test:
	cd $(VENDOR) && cargo test --release
	cd $(VENDOR)/macos && ./run-tests.sh

# Install backend binaries where the menu bar app looks first (~/.cargo/bin)
install: build
	mkdir -p $(BIN_DIR)
	cp $(VENDOR)/target/release/ai-usagebar $(VENDOR)/target/release/ai-usagebar-tui $(BIN_DIR)/
	cp $(APP) bin/ai-usagebar-menubar

config:
	mkdir -p $(CFG_DIR)
	@if [ -f $(CFG_DIR)/config.toml ]; then echo "exists: $(CFG_DIR)/config.toml (not overwritten)"; else cp config/config.toml $(CFG_DIR)/config.toml && chmod 600 $(CFG_DIR)/config.toml && echo "installed $(CFG_DIR)/config.toml"; fi

run: stop
	nohup bin/ai-usagebar-menubar >/dev/null 2>&1 &
	@echo "menu bar app started"

stop:
	-pkill -x ai-usagebar-menubar 2>/dev/null || true

status:
	$(BIN_DIR)/ai-usagebar usage

# Browser OAuth logins via the official CLIs (the app's Vendors pane does the same)
login-claude:
	claude auth login --claudeai
login-codex:
	codex login
