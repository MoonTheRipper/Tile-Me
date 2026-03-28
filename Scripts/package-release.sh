#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
fi

APP_NAME="Tile Me"
VERSION="${VERSION:-$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' "$ROOT/TileMe.xcodeproj/project.pbxproj" | head -n 1)}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT/.build/DerivedData}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT/.build/ReleaseArtifacts}"
PACKAGE_STAGING_ROOT="${PACKAGE_STAGING_ROOT:-$ROOT/.build/PackageStaging}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME.app"
ZIP_PATH="$ARTIFACTS_DIR/Tile-Me-v$VERSION.zip"
DMG_PATH="$ARTIFACTS_DIR/Tile-Me-v$VERSION.dmg"

mkdir -p "$ARTIFACTS_DIR"
mkdir -p "$PACKAGE_STAGING_ROOT"
PACKAGE_STAGING_DIR="$(mktemp -d "$PACKAGE_STAGING_ROOT/package.XXXXXX")"
trap 'rm -rf "$PACKAGE_STAGING_DIR"' EXIT

xcodebuild \
  -project "$ROOT/TileMe.xcodeproj" \
  -scheme TileMe \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Release app not found at $APP_PATH" >&2
  exit 1
fi

ditto "$APP_PATH" "$PACKAGE_STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$PACKAGE_STAGING_DIR/Applications"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

hdiutil_succeeded=true
if ! hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$PACKAGE_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"; then
  hdiutil_succeeded=false
  echo "Warning: DMG creation failed. The zip archive is still available at $ZIP_PATH" >&2
fi

echo "Created:"
echo "  $ZIP_PATH"
if [[ "$hdiutil_succeeded" == true ]]; then
  echo "  $DMG_PATH"
fi
