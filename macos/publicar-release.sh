#!/usr/bin/env bash
# publicar-release.sh — compila en esta Mac el widget de macOS del commit de origin/main y lo publica en el
# release rolling `macos-latest` (el mismo que baja macos/install.sh). Reemplaza al runner macOS de GitHub,
# que se queda sin capacidad arm64 y cancela el build.
#
# Uso:  bash macos/publicar-release.sh [--sha <commit>] [--forzar] [--dry-run]
#   --sha <commit>   compila ese commit (default: origin/main tras un fetch)
#   --forzar         publica aunque `macos-latest` ya traiga ese build-sha
#   --dry-run        compila y empaqueta, pero no toca el release
# Requisitos: swift (Command Line Tools), rsvg-convert (brew install librsvg), gh con sesión, git.

set -euo pipefail

REPO="unjordi/cortex"
TAG="macos-latest"
SHA=""; FORZAR=0; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --sha) SHA="${2:?falta el commit}"; shift 2 ;;
    --forzar) FORZAR=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *) echo "[publicar-release] argumento desconocido: $1" >&2; exit 2 ;;
  esac
done

[ "$(uname -s)" = Darwin ] || { echo "[publicar-release] solo corre en macOS" >&2; exit 1; }
for c in git swift rsvg-convert gh ditto; do
  command -v "$c" >/dev/null 2>&1 || { echo "[publicar-release] falta $c" >&2; exit 1; }
done

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
git -C "$RAIZ" fetch -q origin
[ -n "$SHA" ] || SHA="$(git -C "$RAIZ" rev-parse origin/main)"
SHA="$(git -C "$RAIZ" rev-parse "$SHA^{commit}")"

publicado="$(gh release view "$TAG" --repo "$REPO" --json body -q .body 2>/dev/null | grep -oE 'build-sha: [0-9a-f]+' | head -1 | awk '{print $2}' || true)"
if [ "$publicado" = "$SHA" ] && [ "$FORZAR" -eq 0 ]; then
  echo "[publicar-release] $TAG ya trae $SHA; nada que hacer (--forzar para republicar)"
  exit 0
fi

TMP="$(mktemp -d)"
WT="$TMP/cortex"
limpiar() { git -C "$RAIZ" worktree remove --force "$WT" >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap limpiar EXIT

echo "[publicar-release] compilando ${SHA:0:8} (publicado: ${publicado:0:8}${publicado:+ }${publicado:-ninguno})"
git -C "$RAIZ" worktree add -q --detach "$WT" "$SHA"
APP="$(cd "$WT" && bash macos/make-app.sh)"
[ -d "$APP" ] || { echo "[publicar-release] make-app.sh no generó el .app" >&2; exit 1; }
ZIP="$TMP/CortexWidget.app.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "[publicar-release] $(du -h "$ZIP" | cut -f1) · $(lipo -archs "$APP"/Contents/MacOS/* 2>/dev/null | head -1)"

if [ "$DRY" -eq 1 ]; then
  echo "[publicar-release] (plan) borraría y recrearía $TAG con $ZIP apuntando a $SHA"
  exit 0
fi

gh release delete "$TAG" --repo "$REPO" --cleanup-tag --yes >/dev/null 2>&1 || true
gh release create "$TAG" "$ZIP" --repo "$REPO" --target "$SHA" \
  --title "Widget de macOS (rolling)" \
  --notes "Cortex Widget.app para macOS (ad-hoc signed; instala sin Xcode/Swift).
build-sha: $SHA
El instalador lo baja, lo descomprime en ~/Applications y le quita el quarantine." >/dev/null

ahora="$(gh release view "$TAG" --repo "$REPO" --json body -q .body | grep -oE 'build-sha: [0-9a-f]+' | awk '{print $2}')"
[ "$ahora" = "$SHA" ] || { echo "[publicar-release] el release quedó con build-sha '$ahora', no $SHA" >&2; exit 1; }
echo "[publicar-release] publicado $TAG @ ${SHA:0:8}"
