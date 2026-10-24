#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" != "--skip-build" ]; then bash scripts/build.sh; fi
APP="build/Artifacts.noindex/轻截.app"
VERSION="$(python3 -c 'import plistlib; print(plistlib.load(open("Resources/Info.plist","rb"))["CFBundleShortVersionString"])')"
ARCH="${QINGCAPTURE_ARCH:-$(uname -m)}"
NAME="QingCapture-${VERSION}-macOS-${ARCH}.zip"
mkdir -p build/releases
codesign --verify --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "build/releases/$NAME"
unzip -tq "build/releases/$NAME" >/dev/null
(cd build/releases && shasum -a 256 "$NAME" > "$NAME.sha256")
printf 'Packaged: %s\n' "$PWD/build/releases/$NAME"
