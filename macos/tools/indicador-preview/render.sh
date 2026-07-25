#!/usr/bin/env bash
# Regenera screenshots/indicador-barra.png a partir del PillImage.swift ACTUAL del widget.
# Uso: bash macos/tools/indicador-preview/render.sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
PILL="$DIR/../../Sources/ClaudeBrain/PillImage.swift"
OUT="$DIR/../../../screenshots/indicador-barra.png"
TMP="$(mktemp -d)"
swiftc -O -o "$TMP/preview" "$DIR/stubs.swift" "$PILL" "$DIR/main.swift" -framework AppKit
"$TMP/preview" "$OUT"
/bin/rm -rf "$TMP"
