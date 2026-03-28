#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/Scripts/build.sh"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT/.build/DerivedData}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/Tile Me.app"

open "$APP_PATH"
