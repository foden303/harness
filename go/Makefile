# Harness Go build
#
# Usage:
#   make build          — Build for current platform
#   make build-all      — Cross-compile for darwin-arm64, darwin-amd64, linux-amd64
#   make install        — Build and install the platform binary into ../bin
#   make test           — Run all tests
#   make clean          — Remove build artifacts
#
# NOTE: ../bin/harness is a committed POSIX shim that dispatches to
# ../bin/harness-$(GOOS)-$(GOARCH). Never overwrite it with a native binary —
# doing so drops Git Bash / MSYS / Cygwin support (tests/test-windows-worktree-support.sh
# fails) and trips the binary/source drift gate.

VERSION := $(shell cat ../VERSION 2>/dev/null || echo "dev")
GOOS    := $(shell go env GOOS)
GOARCH  := $(shell go env GOARCH)
# Pinned to go.mod's go directive so install output is byte-identical to the
# drift gate's rebuild, regardless of the locally installed toolchain.
GOTOOLCHAIN := go$(shell sed -n 's/^go //p' go.mod | head -1 | tr -d '[:space:]')
LDFLAGS := -ldflags="-s -w -X main.version=$(VERSION)"
BINARY  := harness
OUTDIR  := ../bin
PLATFORM_BINARY := $(OUTDIR)/harness-$(GOOS)-$(GOARCH)

.PHONY: build build-all install test clean

build:
	go build $(LDFLAGS) -o $(BINARY) ./cmd/harness/

build-all:
	bash scripts/build-all.sh

# Byte-identical to what scripts/ci/check-binary-source-drift.sh rebuilds:
# -trimpath -buildvcs=false, pinned toolchain via go.mod.
install:
	mkdir -p $(OUTDIR)
	GOTOOLCHAIN=$(GOTOOLCHAIN) CGO_ENABLED=0 go build -trimpath -buildvcs=false $(LDFLAGS) -o $(PLATFORM_BINARY) ./cmd/harness/
	@echo "Installed $(PLATFORM_BINARY) ($(VERSION)) — ../bin/harness shim dispatches to it"

test:
	go test ./...

clean:
	rm -f $(BINARY)
	rm -f $(OUTDIR)/harness-darwin-arm64
	rm -f $(OUTDIR)/harness-darwin-amd64
	rm -f $(OUTDIR)/harness-linux-amd64
	rm -f $(OUTDIR)/harness-windows-amd64.exe
