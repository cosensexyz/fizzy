.PHONY: build run test clean xcode install uninstall pkg

PREFIX ?= /usr/local
BINDIR  = $(PREFIX)/bin
LABEL   = xyz.cosense.fizzy
PLIST   = scripts/$(LABEL).plist
AGENT_DIR = $(HOME)/Library/LaunchAgents

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
	install -d $(BINDIR)
	install -m 755 $$(swift build -c release --show-bin-path)/Fizzy $(BINDIR)/fizzy
	install -m 755 scripts/notify-fizzy.sh $(BINDIR)/notify-fizzy
	install -d $(AGENT_DIR)
	install -m 644 $(PLIST) $(AGENT_DIR)/$(LABEL).plist
	launchctl load $(AGENT_DIR)/$(LABEL).plist

uninstall:
	-launchctl unload $(AGENT_DIR)/$(LABEL).plist 2>/dev/null
	rm -f $(BINDIR)/fizzy $(BINDIR)/notify-fizzy
	rm -f $(AGENT_DIR)/$(LABEL).plist

build-release:
	swift build -c release

VERSION = $(shell git describe --tags --always --dirty 2>/dev/null || echo "0.0.0-dev")
PKG_ID  = $(LABEL)
PKG_ROOT = .build/pkg-root
PKG_OUT  = .build/Fizzy-$(VERSION).pkg

PKG_SCRIPTS = .build/pkg-scripts

pkg: build-release
	rm -rf $(PKG_ROOT) $(PKG_SCRIPTS)
	mkdir -p $(PKG_ROOT)/usr/local/bin
	mkdir -p $(PKG_ROOT)/Library/LaunchAgents
	mkdir -p $(PKG_SCRIPTS)
	cp $$(swift build -c release --show-bin-path)/Fizzy $(PKG_ROOT)/usr/local/bin/fizzy
	cp scripts/notify-fizzy.sh $(PKG_ROOT)/usr/local/bin/notify-fizzy
	chmod 755 $(PKG_ROOT)/usr/local/bin/fizzy $(PKG_ROOT)/usr/local/bin/notify-fizzy
	cp $(PLIST) $(PKG_ROOT)/Library/LaunchAgents/$(LABEL).plist
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
