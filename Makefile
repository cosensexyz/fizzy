.PHONY: build run test clean xcode install uninstall pkg

PREFIX ?= /usr/local
BINDIR  = $(PREFIX)/bin
LABEL   = xyz.cosense.fizzy
PLIST   = scripts/$(LABEL).plist
AGENT_DIR = $(HOME)/Library/LaunchAgents
APP_DIR   = /Applications
APP_NAME  = Fizzy.app
APP_PATH  = $(APP_DIR)/$(APP_NAME)
APP_BIN   = $(APP_PATH)/Contents/MacOS/Fizzy

build:
	swift build

run:
	swift run Fizzy

test:
	swift test

clean:
	swift package clean
	rm -rf .build
	rm -f *.o *.d *.swiftdeps *.swiftdeps~

xcode:
	open Package.swift

install: build-release
	@# --- App bundle ---
	mkdir -p $(APP_PATH)/Contents/MacOS
	mkdir -p $(APP_PATH)/Contents/Resources
	cp scripts/Info.plist $(APP_PATH)/Contents/Info.plist
	install -m 755 $$(swift build -c release --show-bin-path)/Fizzy $(APP_BIN)
	@# --- CLI tools ---
	install -d $(BINDIR)
	ln -sf $(APP_BIN) $(BINDIR)/fizzy
	install -m 755 scripts/notify-fizzy.sh $(BINDIR)/notify-fizzy
	@# --- LaunchAgent ---
	install -d $(AGENT_DIR)
	sed 's|/usr/local/bin/fizzy|$(APP_BIN)|' $(PLIST) > $(AGENT_DIR)/$(LABEL).plist
	-launchctl bootout gui/$$(id -u)/$(LABEL) 2>/dev/null
	launchctl bootstrap gui/$$(id -u) $(AGENT_DIR)/$(LABEL).plist

uninstall:
	-launchctl bootout gui/$$(id -u)/$(LABEL) 2>/dev/null
	rm -rf $(APP_PATH)
	rm -f $(BINDIR)/fizzy $(BINDIR)/notify-fizzy
	rm -f $(AGENT_DIR)/$(LABEL).plist

build-release:
	swift build -c release

VERSION = $(shell git describe --tags --always --dirty 2>/dev/null || echo "0.0.0-dev")
PKG_ID  = $(LABEL)
PKG_ROOT = .build/pkg-root
PKG_OUT  = .build/Fizzy-$(VERSION).pkg

PKG_SCRIPTS = .build/pkg-scripts
PKG_APP     = $(PKG_ROOT)$(APP_PATH)

pkg: build-release
	rm -rf $(PKG_ROOT) $(PKG_SCRIPTS)
	mkdir -p $(PKG_APP)/Contents/MacOS
	mkdir -p $(PKG_APP)/Contents/Resources
	mkdir -p $(PKG_ROOT)/usr/local/bin
	mkdir -p $(PKG_ROOT)/Library/LaunchAgents
	mkdir -p $(PKG_SCRIPTS)
	cp scripts/Info.plist $(PKG_APP)/Contents/Info.plist
	install -m 755 $$(swift build -c release --show-bin-path)/Fizzy $(PKG_APP)/Contents/MacOS/Fizzy
	ln -sf $(APP_BIN) $(PKG_ROOT)/usr/local/bin/fizzy
	cp scripts/notify-fizzy.sh $(PKG_ROOT)/usr/local/bin/notify-fizzy
	chmod 755 $(PKG_ROOT)/usr/local/bin/notify-fizzy
	sed 's|/usr/local/bin/fizzy|$(APP_BIN)|' $(PLIST) \
		> $(PKG_ROOT)/Library/LaunchAgents/$(LABEL).plist
	cp scripts/postinstall $(PKG_SCRIPTS)/postinstall
	chmod 755 $(PKG_SCRIPTS)/postinstall
	pkgbuild \
		--root $(PKG_ROOT) \
		--scripts $(PKG_SCRIPTS) \
		--identifier $(PKG_ID) \
		--version $(VERSION) \
		--install-location / \
		$(PKG_OUT)
	@echo "\n✓ Package built: $(PKG_OUT)"
