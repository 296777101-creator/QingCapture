#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/swift-env.sh
APP="build/Artifacts.noindex/轻截.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -sdk "$QING_SDK" -target "$QING_ARCH-apple-macos14.0" -swift-version 5 -O -module-name QingCapture -debug-prefix-map "$PWD"=QingCapture Sources/QingCaptureCore/*.swift Sources/QingCaptureApp/*.swift -o "$APP/Contents/MacOS/QingCapture"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"; fi
codesign --force --sign - --identifier local.qingcapture.app -r='designated => identifier "local.qingcapture.app"' "$APP"
codesign --verify --strict "$APP"
printf 'Built: %s\n' "$PWD/$APP"
