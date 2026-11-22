#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Build AppLatch on macOS with Xcode installed. See README.md."
    exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
    echo "Open a compatible full Xcode installation and select it under Preferences > Locations > Command Line Tools."
    exit 1
fi

xcodebuild -project AppLatch.xcodeproj \
    -scheme AppLatch \
    -configuration Release \
    -derivedDataPath build \
    build

echo "Built AppLatch.app. Copy it from the opened folder into Applications."
open build/Build/Products/Release
