#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-move-window.sh - Mueve/redimensiona la ventana de una app, POR SSH.
# ==================================================================================================
# Via System Events: `set position of window 1` / `set size of window 1`. Requiere permiso de
# Accesibilidad (igual que send-click/send-keys/get-window-coordinates).
#
# USO (por SSH):
#   mac-ssh-move-window.sh -App "Kate" -X 100 -Y 100
#   mac-ssh-move-window.sh -App "Kate" -X 0 -Y 0 -W 1200 -H 800
#
# EXIT: 0 si disparo el move/resize; 1 sin sesion de consola / falto -App.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mac-ssh-env.sh
source "$SCRIPT_DIR/lib-mac-ssh-env.sh"

App=""; X=""; Y=""; W=""; H=""
while [ $# -gt 0 ]; do
    case "$1" in
        -App) App="$2"; shift 2 ;;
        -X) X="$2"; shift 2 ;;
        -Y) Y="$2"; shift 2 ;;
        -W) W="$2"; shift 2 ;;
        -H) H="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ -z "$App" ] && { echo "Falta -App" >&2; exit 2; }
{ [ -z "$X" ] || [ -z "$Y" ]; } && { echo "Falta -X -Y" >&2; exit 2; }

cu="$(mac_console_user)"
[ -z "$cu" ] && { echo "SIN sesion de consola activa" >&2; exit 1; }

sizecmd=""
[ -n "$W" ] && [ -n "$H" ] && sizecmd="set size of window 1 to {$W, $H}"

mac_dispatch osascript -e "
tell application \"System Events\"
    tell process \"$App\"
        set position of window 1 to {$X, $Y}
        $sizecmd
    end tell
end tell" 2>&1

echo "OK movida '$App' -> $X,$Y${W:+ (${W}x${H})}"
exit 0
