#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/swift-env.sh
xcrun swiftc -sdk "$QING_SDK" -target "$QING_ARCH-apple-macos14.0" -swift-version 5 Sources/QingCaptureCore/*.swift Tests/QingCaptureCoreTests/*.swift Tests/main.swift -o build/CoreTests
build/CoreTests
python3 Tests/test_install_archives.py
