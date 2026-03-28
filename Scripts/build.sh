#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
fi

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT/.build/DerivedData}"

xcodebuild \
  -project "$ROOT/TileMe.xcodeproj" \
  -scheme TileMe \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build
