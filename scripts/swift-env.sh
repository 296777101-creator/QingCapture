#!/bin/bash
# Source from the project root. Select a compatible installed SDK without changing Xcode settings.
QING_ARCH="${QINGCAPTURE_ARCH:-$(uname -m)}"
case "$QING_ARCH" in arm64|x86_64) ;; *) printf 'Unsupported architecture: %s\n' "$QING_ARCH" >&2; exit 1;; esac
mkdir -p build
if [ -n "${QINGCAPTURE_SDK_PATH:-}" ]; then
    QING_SDK="$QINGCAPTURE_SDK_PATH"
else
    QING_DEVELOPER="$(xcode-select -p)"
    QING_PREFERRED="$(xcrun --show-sdk-path)"
    if [ -d "$QING_DEVELOPER/SDKs/MacOSX.sdk" ]; then QING_PREFERRED="$QING_DEVELOPER/SDKs/MacOSX.sdk"; fi
    QING_SDK=""
    for QING_CANDIDATE in "$QING_PREFERRED" /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk; do
        [ -d "$QING_CANDIDATE" ] || continue
        if printf 'import AppKit\n' | xcrun swiftc -sdk "$QING_CANDIDATE" -target "$QING_ARCH-apple-macos14.0" -swift-version 5 -typecheck - > build/sdk-probe.log 2>&1; then
            QING_SDK="$QING_CANDIDATE"; break
        fi
    done
fi
if [ -z "$QING_SDK" ] || [ ! -d "$QING_SDK" ]; then
    printf 'No compatible macOS SDK found. Select a matching Xcode toolchain or set QINGCAPTURE_SDK_PATH.\n' >&2
    exit 1
fi
