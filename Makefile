# AI Usage Bar (macOS) — our own SwiftPM menu bar app on top of the vendored Rust backend.
VENDOR    := vendor/ai-usagebar
BIN_DIR   := $(HOME)/.cargo/bin
CFG_DIR   := $(HOME)/.config/ai-usagebar
APP_NAME  := AI Usage Bar
APP_DIR   := build/$(APP_NAME).app
EXEC      := AIUsageBar

# swift-testing needs the Command Line Tools frameworks explicitly (no Xcode here).
CLT_FW    := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
TEST_FLAGS := -Xswiftc -F$(CLT_FW) -Xlinker -F$(CLT_FW) -Xlinker -rpath -Xlinker $(CLT_FW)

.PHONY: all submodule build build-rust build-app bundle test test-app test-rust install config run stop dump status login-claude login-codex login-gemini clean

all: build

submodule:
	git submodule update --init --recursive

build: build-rust build-app

build-rust: submodule
	cd $(VENDOR) && cargo build --release

build-app:
	swift build -c release

bundle: build-app
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	cp .build/release/$(EXEC) "$(APP_DIR)/Contents/MacOS/$(EXEC)"
	cp Resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
	printf 'APPL????' > "$(APP_DIR)/Contents/PkgInfo"
	codesign --force --sign - "$(APP_DIR)" 2>/dev/null || true
	@echo "bundled $(APP_DIR)"

test: test-rust test-app

test-rust:
	cd $(VENDOR) && cargo test --release

test-app:
	swift test $(TEST_FLAGS)

# Install the Rust backend where the app looks first, then bundle the app.
install: build-rust bundle
	mkdir -p $(BIN_DIR)
	cp $(VENDOR)/target/release/ai-usagebar $(VENDOR)/target/release/ai-usagebar-tui $(BIN_DIR)/

config:
	mkdir -p $(CFG_DIR)
	@if [ -f $(CFG_DIR)/config.toml ]; then echo "exists: $(CFG_DIR)/config.toml (not overwritten)"; else cp config/config.toml $(CFG_DIR)/config.toml && chmod 600 $(CFG_DIR)/config.toml && echo "installed $(CFG_DIR)/config.toml"; fi

run: stop bundle
	open "$(APP_DIR)"
	@echo "menu bar app started"

stop:
	-pkill -x $(EXEC) 2>/dev/null || true

# One backend fetch, printed as a text lane table (no UI).
dump: build-app
	.build/release/$(EXEC) --dump

status:
	$(BIN_DIR)/ai-usagebar usage

clean:
	rm -rf .build build

# Browser OAuth logins via the official CLIs (the popover's Log in buttons do the same)
login-claude:
	claude auth login --claudeai
login-codex:
	codex login
login-gemini:
	agy
