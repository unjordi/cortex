#!/usr/bin/env bash
# Remove the macOS Claude Code quota app, agent, fetch script, AND the shared Claude-Code brain.
#
#   ./uninstall.sh            # remove everything (app + brain; keeps limits.env)
#   ./uninstall.sh --purge    # also remove ~/.config/cortex and the cache
#   ./uninstall.sh --no-brain # remove only the app; leave the Claude-Code brain installed

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BRAIN_UNINSTALLER="$ROOT/../brain/uninstall-brain.sh"

LABEL="io.github.unjordi.cortex"
FETCH_DEST="$HOME/.local/bin/cortex-fetch"
PLIST_DEST="$HOME/Library/LaunchAgents/$LABEL.plist"
APP_DEST="$HOME/Applications/Cortex Widget.app"
CONFIG_DIR="$HOME/.config/cortex"
CACHE_DIR="$HOME/Library/Caches/cortex"

PURGE=0
SKIP_BRAIN=0
for arg in "$@"; do
  case "$arg" in
    --purge)    PURGE=1 ;;
    --no-brain) SKIP_BRAIN=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [[ "$SKIP_BRAIN" -eq 0 ]]; then
  if [[ -f "$BRAIN_UNINSTALLER" ]]; then
    echo "==> Removing the Claude-Code brain (global hooks, delegation-cost governance, norms)"
    bash "$BRAIN_UNINSTALLER"
  else
    echo "==> (brain uninstaller not found at $BRAIN_UNINSTALLER — skipping)"
  fi
fi

echo "==> Stopping app"
osascript -e 'tell application "Cortex Widget" to quit' 2>/dev/null || true
pkill -f "Cortex Widget.app/Contents/MacOS/Cortex" 2>/dev/null || true

echo "==> Unloading launchd agents (fetch + autoarranque del widget)"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$LABEL.widget" 2>/dev/null || true

echo "==> Removing files"
rm -f "$PLIST_DEST" "$FETCH_DEST" "$HOME/Library/LaunchAgents/$LABEL.widget.plist"
rm -rf "$APP_DEST"

if [[ "$PURGE" -eq 1 ]]; then
  echo "==> Purging config + cache"
  rm -rf "$CONFIG_DIR" "$CACHE_DIR"
else
  echo "    keeping config: $CONFIG_DIR/limits.env"
fi

# Barre la era INTERMEDIA 'claude-brain' (rename claude-brain → cortex, #312) por si quedó atrás:
# AMBOS LaunchAgents (daemon + widget), fetch, app, cache/config. Idempotente/fail-safe. SOLO el
# fetch de la era vieja; los helpers compartidos de ~/.local/bin NO se tocan.
echo "==> Barriendo restos de la era 'claude-brain' (si los hay)"
BRAIN_LABEL="io.github.unjordi.claude-brain"
osascript -e 'tell application "Claude Brain Widget" to quit' 2>/dev/null || true
pkill -f "Claude Brain Widget.app/Contents/MacOS/" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$BRAIN_LABEL" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$BRAIN_LABEL.widget" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$BRAIN_LABEL.plist" "$HOME/Library/LaunchAgents/$BRAIN_LABEL.widget.plist" "$HOME/.local/bin/claude-brain-fetch" 2>/dev/null || true
rm -rf "$HOME/Applications/Claude Brain Widget.app" 2>/dev/null || true
if [[ "$PURGE" -eq 1 ]]; then
  rm -rf "$HOME/Library/Caches/claude-brain" "$HOME/.config/claude-brain" 2>/dev/null || true
fi

echo "Done."
