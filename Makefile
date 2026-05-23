.PHONY: build run test clean xcode install uninstall pkg

PREFIX ?= /usr/local
BINDIR  = $(PREFIX)/bin

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
	install -m 755 hook/notify-fizzy.sh $(BINDIR)/notify-fizzy

uninstall:
	rm -f $(BINDIR)/fizzy $(BINDIR)/notify-fizzy

build-release:
	swift build -c release

VERSION = $(shell git describe --tags --always --dirty 2>/dev/null || echo "0.0.0-dev")
PKG_ID  = com.fizzy.pkg
PKG_ROOT = .build/pkg-root
PKG_OUT  = .build/Fizzy-$(VERSION).pkg

pkg: build-release
	rm -rf $(PKG_ROOT)
	mkdir -p $(PKG_ROOT)/usr/local/bin
	cp $$(swift build -c release --show-bin-path)/Fizzy $(PKG_ROOT)/usr/local/bin/fizzy
	cp hook/notify-fizzy.sh $(PKG_ROOT)/usr/local/bin/notify-fizzy
	chmod 755 $(PKG_ROOT)/usr/local/bin/fizzy $(PKG_ROOT)/usr/local/bin/notify-fizzy
	pkgbuild \
		--root $(PKG_ROOT) \
		--identifier $(PKG_ID) \
		--version $(VERSION) \
		--install-location / \
		$(PKG_OUT)
	@echo "\n✓ Package built: $(PKG_OUT)"
